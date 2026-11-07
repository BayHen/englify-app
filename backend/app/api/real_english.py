"""Original expressions, private saves, and server-graded context quizzes."""
# ruff: noqa: E501 -- SQL statements are kept intact for review.

from datetime import datetime
from typing import Annotated
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser, get_current_user
from app.core.responses import ApiResponse, AppError
from app.db.session import get_db_session

router = APIRouter(prefix="/api/v1/real-english", tags=["real-english"])


class DialogueLine(BaseModel):
    speaker: str
    line: str


class Expression(BaseModel):
    id: UUID
    slug: str
    kind: str
    expression: str
    meaning_vi: str
    context_explanation: str
    example_en: str
    example_vi: str
    dialogue: list[DialogueLine]
    formality: str
    region_note: str
    source_name: str
    license_id: str
    provenance_note: str
    saved: bool


class QuizOption(BaseModel):
    id: str
    text: str


class ContextQuiz(BaseModel):
    id: UUID
    expression_id: UUID
    prompt: str
    options: list[QuizOption]


class QuizSubmission(BaseModel):
    model_config = ConfigDict(extra="forbid")
    request_id: UUID
    selected_option: str = Field(min_length=1, max_length=80)


class QuizResult(BaseModel):
    attempt_id: UUID
    question_id: UUID
    is_correct: bool
    correct_option: str
    explanation: str
    created_at: datetime


KINDS = {
    "slang",
    "idiom",
    "phrasal_verb",
    "casual_expression",
    "everyday_conversation",
    "movie_style_dialogue",
}


def _row(db: Session, user_id: UUID, expression_id: UUID) -> Expression:
    row = (
        db.execute(
            text("""
        SELECT e.id, e.slug, e.kind, e.expression, e.meaning_vi, e.context_explanation,
               e.example_en, e.example_vi, e.dialogue, e.formality, e.region_note,
               e.source_name, e.license_id, e.provenance_note,
               EXISTS(SELECT 1 FROM public.saved_expressions s WHERE s.expression_id = e.id AND s.user_id = :uid) AS saved
        FROM public.real_english_expressions e WHERE e.id = :id AND e.is_published AND e.archived_at IS NULL
    """),
            {"uid": user_id, "id": expression_id},
        )
        .mappings()
        .one_or_none()
    )
    if row is None:
        raise AppError(404, "expression_not_found", "Expression not found")
    return Expression.model_validate(dict(row))


@router.get("", response_model=ApiResponse[list[Expression]])
def search_expressions(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
    q: Annotated[str, Query(max_length=80)] = "",
    kind: str | None = None,
    saved_only: bool = False,
    limit: Annotated[int, Query(ge=1, le=50)] = 30,
) -> ApiResponse[list[Expression]]:
    if kind and kind not in KINDS:
        raise AppError(422, "invalid_kind", "Unknown expression type")
    escaped = q.strip().replace("!", "!!").replace("%", "!%").replace("_", "!_")
    rows = (
        db.execute(
            text("""
        SELECT e.id, e.slug, e.kind, e.expression, e.meaning_vi, e.context_explanation,
               e.example_en, e.example_vi, e.dialogue, e.formality, e.region_note,
               e.source_name, e.license_id, e.provenance_note,
               (s.id IS NOT NULL) AS saved
        FROM public.real_english_expressions e
        LEFT JOIN public.saved_expressions s ON s.expression_id = e.id AND s.user_id = :uid
        WHERE e.is_published AND e.archived_at IS NULL AND (CAST(:kind AS text) IS NULL OR e.kind = CAST(:kind AS text))
          AND (NOT :saved_only OR s.id IS NOT NULL)
          AND (CAST(:q AS text) = '' OR e.expression ILIKE '%' || CAST(:q AS text) || '%' ESCAPE '!'
                    OR e.meaning_vi ILIKE '%' || CAST(:q AS text) || '%' ESCAPE '!')
        ORDER BY e.expression, e.id LIMIT :limit
    """),
            {"uid": user.id, "kind": kind, "saved_only": saved_only, "q": escaped, "limit": limit},
        )
        .mappings()
        .all()
    )
    return ApiResponse(data=[Expression.model_validate(dict(row)) for row in rows])


@router.get("/{expression_id}", response_model=ApiResponse[Expression])
def get_expression(
    expression_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[Expression]:
    return ApiResponse(data=_row(db, user.id, expression_id))


@router.post("/{expression_id}/save", response_model=ApiResponse[Expression])
def save_expression(
    expression_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[Expression]:
    with db.begin():
        _row(db, user.id, expression_id)
        db.execute(
            text("""
            INSERT INTO public.saved_expressions(user_id, expression_id)
            VALUES (:uid, :id) ON CONFLICT (user_id, expression_id) DO NOTHING
        """),
            {"uid": user.id, "id": expression_id},
        )
    return ApiResponse(data=_row(db, user.id, expression_id))


@router.delete("/{expression_id}/save", response_model=ApiResponse[Expression])
def unsave_expression(
    expression_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[Expression]:
    with db.begin():
        _row(db, user.id, expression_id)
        db.execute(
            text(
                "DELETE FROM public.saved_expressions WHERE user_id = :uid AND expression_id = :id"
            ),
            {"uid": user.id, "id": expression_id},
        )
    return ApiResponse(data=_row(db, user.id, expression_id))


def _quiz(db: Session, expression_id: UUID):
    row = (
        db.execute(
            text("""
        SELECT q.id, q.expression_id, q.prompt, q.options, q.answer_id, q.explanation
        FROM public.real_english_quiz_questions q
        JOIN public.real_english_expressions e ON e.id = q.expression_id
        WHERE q.expression_id = :id AND e.is_published AND e.archived_at IS NULL
    """),
            {"id": expression_id},
        )
        .mappings()
        .one_or_none()
    )
    if row is None:
        raise AppError(404, "quiz_not_found", "Context quiz not found")
    return row


@router.get("/{expression_id}/quiz", response_model=ApiResponse[ContextQuiz])
def get_context_quiz(
    expression_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[ContextQuiz]:
    _ = user.id
    row = _quiz(db, expression_id)
    return ApiResponse(
        data=ContextQuiz(
            id=row["id"],
            expression_id=row["expression_id"],
            prompt=row["prompt"],
            options=row["options"],
        )
    )


@router.post("/{expression_id}/quiz", response_model=ApiResponse[QuizResult])
def submit_context_quiz(
    expression_id: UUID,
    payload: QuizSubmission,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[QuizResult]:
    with db.begin():
        db.execute(
            text("SELECT pg_advisory_xact_lock(hashtext(:key))"),
            {"key": f"real-english:{user.id}:{payload.request_id}"},
        )
        old = (
            db.execute(
                text("""
            SELECT a.id, a.question_id, a.selected_option, a.is_correct, a.created_at, q.expression_id,
                   q.answer_id, q.explanation
            FROM public.real_english_quiz_attempts a
            JOIN public.real_english_quiz_questions q ON q.id = a.question_id
            WHERE a.user_id = :uid AND a.request_id = :request_id
        """),
                {"uid": user.id, "request_id": payload.request_id},
            )
            .mappings()
            .one_or_none()
        )
        if old:
            if old["expression_id"] != expression_id or old["selected_option"] != payload.selected_option:
                raise AppError(
                    409, "request_id_reused", "Submission ID belongs to another quiz answer"
                )
            return ApiResponse(
                data=QuizResult(
                    attempt_id=old["id"],
                    question_id=old["question_id"],
                    is_correct=old["is_correct"],
                    correct_option=old["answer_id"],
                    explanation=old["explanation"],
                    created_at=old["created_at"],
                )
            )
        quiz = _quiz(db, expression_id)
        if payload.selected_option not in {item["id"] for item in quiz["options"]}:
            raise AppError(422, "invalid_option", "Choose an option from this quiz")
        attempt_id = uuid4()
        correct = payload.selected_option == quiz["answer_id"]
        created = db.execute(
            text("""
            INSERT INTO public.real_english_quiz_attempts
              (id, user_id, question_id, request_id, selected_option, is_correct)
            VALUES (:id, :uid, :question, :request, :answer, :correct) RETURNING created_at
        """),
            {
                "id": attempt_id,
                "uid": user.id,
                "question": quiz["id"],
                "request": payload.request_id,
                "answer": payload.selected_option,
                "correct": correct,
            },
        ).scalar_one()
    return ApiResponse(
        data=QuizResult(
            attempt_id=attempt_id,
            question_id=quiz["id"],
            is_correct=correct,
            correct_option=quiz["answer_id"],
            explanation=quiz["explanation"],
            created_at=created,
        )
    )
