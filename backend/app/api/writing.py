"""Authenticated writing practice with separate, durable feedback."""
# ruff: noqa: E501 -- SQL kept intact for review.

import json
from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID, uuid4

import httpx
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser, get_current_user
from app.core.config import Settings
from app.core.responses import ApiResponse, AppError
from app.db.session import get_db_session, get_settings
from app.writing.grammar import LanguageToolProvider
from app.writing.rules import check

router = APIRouter(prefix="/api/v1/writing", tags=["writing"])


class Exercise(BaseModel):
    id: UUID
    kind: Literal["sentence", "fill_blank", "sentence_order", "paragraph"]
    prompt: str
    hint: str
    tokens: list[str]


class SubmissionInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    request_id: UUID
    exercise_id: UUID
    body: str = Field(min_length=1, max_length=5000)
    grammar_check: bool = False


class Feedback(BaseModel):
    rule_result: Literal["matched", "needs_revision", "self_review"]
    suggestions: list[str]
    grammar_status: Literal["not_requested", "available", "unavailable"]
    grammar_matches: list[dict]


class Submission(BaseModel):
    id: UUID
    exercise_id: UUID | None
    prompt: str
    body: str
    created_at: datetime
    feedback: Feedback | None


def _submission(db: Session, user_id: UUID, submission_id: UUID) -> Submission:
    row = (
        db.execute(
            text("""
        SELECT s.id, s.exercise_id, s.prompt, s.body, s.created_at,
               f.rule_result, f.suggestions, f.grammar_status, f.grammar_matches
        FROM public.writing_submissions s
        LEFT JOIN public.writing_feedback f ON f.submission_id = s.id
        WHERE s.id = :id AND s.user_id = :uid
    """),
            {"id": submission_id, "uid": user_id},
        )
        .mappings()
        .one_or_none()
    )
    if row is None:
        raise AppError(404, "submission_not_found", "Writing submission not found")
    feedback = None
    if row["rule_result"] is not None:
        feedback = Feedback(
            rule_result=row["rule_result"],
            suggestions=row["suggestions"],
            grammar_status=row["grammar_status"],
            grammar_matches=row["grammar_matches"],
        )
    return Submission(
        id=row["id"],
        exercise_id=row["exercise_id"],
        prompt=row["prompt"],
        body=row["body"],
        created_at=row["created_at"],
        feedback=feedback,
    )


@router.get("/exercises", response_model=ApiResponse[list[Exercise]])
def list_exercises(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[list[Exercise]]:
    _ = user.id
    rows = (
        db.execute(
            text(
                "SELECT id, kind, prompt, hint, tokens FROM public.writing_exercises WHERE is_published ORDER BY kind, id"
            )
        )
        .mappings()
        .all()
    )
    return ApiResponse(data=[Exercise.model_validate(dict(row)) for row in rows])


@router.get("/history", response_model=ApiResponse[list[Submission]])
def history(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
) -> ApiResponse[list[Submission]]:
    ids = (
        db.execute(
            text(
                "SELECT id FROM public.writing_submissions WHERE user_id = :uid AND exercise_id IS NOT NULL ORDER BY created_at DESC, id DESC LIMIT :limit"
            ),
            {"uid": user.id, "limit": limit},
        )
        .scalars()
        .all()
    )
    return ApiResponse(data=[_submission(db, user.id, item) for item in ids])


@router.get("/history/{submission_id}", response_model=ApiResponse[Submission])
def get_submission(
    submission_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[Submission]:
    return ApiResponse(data=_submission(db, user.id, submission_id))


@router.post("/submit", response_model=ApiResponse[Submission])
async def submit(
    payload: SubmissionInput,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> ApiResponse[Submission]:
    original = payload.body.strip()
    if not original:
        raise AppError(422, "empty_writing", "Write something before submitting")
    # Serialize retries before the provider call; no XP or client-supplied score exists.
    with db.begin():
        db.execute(
            text("SELECT pg_advisory_xact_lock(hashtext(:key))"),
            {"key": f"writing:{user.id}:{payload.request_id}"},
        )
        prior = (
            db.execute(
                text(
                    "SELECT id, exercise_id, body FROM public.writing_submissions WHERE user_id=:uid AND request_id=:request_id"
                ),
                {"uid": user.id, "request_id": payload.request_id},
            )
            .mappings()
            .one_or_none()
        )
        if prior:
            if prior["exercise_id"] != payload.exercise_id or prior["body"] != original:
                raise AppError(
                    409, "request_id_reused", "Submission ID belongs to another response"
                )
            return ApiResponse(data=_submission(db, user.id, prior["id"]))
        exercise = (
            db.execute(
                text("""
            SELECT e.id, e.kind, e.prompt, k.accepted_answers FROM public.writing_exercises e
            LEFT JOIN public.writing_answer_keys k ON k.exercise_id=e.id
            WHERE e.id=:id AND e.is_published
        """),
                {"id": payload.exercise_id},
            )
            .mappings()
            .one_or_none()
        )
        if exercise is None:
            raise AppError(404, "exercise_not_found", "Writing exercise not found")
        if exercise["kind"] != "paragraph" and exercise["accepted_answers"] is None:
            raise AppError(503, "exercise_not_ready", "Writing answer key is unavailable")
        rules = check(exercise["kind"], original, exercise["accepted_answers"] or [])
        grammar_status = "not_requested"
        matches: list[dict] = []
        if payload.grammar_check:
            grammar_status = "unavailable"
            if settings.languagetool_url:
                try:
                    checked = await LanguageToolProvider(settings.languagetool_url).check(original)
                    matches = [
                        dict(
                            message=m.message,
                            offset=m.offset,
                            length=m.length,
                            replacements=list(m.replacements),
                        )
                        for m in checked
                    ]
                    grammar_status = "available"
                except (httpx.HTTPError, OSError, ValueError, KeyError, TypeError, TimeoutError):
                    pass
        submission_id = uuid4()
        db.execute(
            text("""
            INSERT INTO public.writing_submissions(id,user_id,exercise_id,request_id,prompt,body)
            VALUES (:id,:uid,:exercise,:request_id,:prompt,:body)
        """),
            {
                "id": submission_id,
                "uid": user.id,
                "exercise": payload.exercise_id,
                "request_id": payload.request_id,
                "prompt": exercise["prompt"],
                "body": original,
            },
        )
        db.execute(
            text("""
            INSERT INTO public.writing_feedback(submission_id,rule_result,suggestions,grammar_status,grammar_matches)
            VALUES (:id,:result,CAST(:suggestions AS jsonb),:status,CAST(:matches AS jsonb))
        """),
            {
                "id": submission_id,
                "result": rules.result,
                "suggestions": json.dumps(rules.suggestions),
                "status": grammar_status,
                "matches": json.dumps(matches),
            },
        )
        result = _submission(db, user.id, submission_id)
    return ApiResponse(data=result)
