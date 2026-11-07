"""Allowlisted administration of learning content. All writes are audited."""
# ruff: noqa: E501 -- Explicit SQL makes the allowed tables and columns reviewable.

import json
import re
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser, get_current_user
from app.core.responses import ApiResponse, AppError
from app.db.session import get_db_session

router = APIRouter(prefix="/api/v1/admin", tags=["admin"])

# A fixed allowlist prevents resource names and column names from entering SQL unchecked.
# Value types are validated below; "answer" and "options" are stored in private child tables.
FIELDS: dict[str, dict[str, str]] = {
    "vocabulary": {
        "term": "text",
        "definition": "text",
        "translation": "text",
        "ipa": "optional",
        "part_of_speech": "optional",
        "example": "optional",
        "audio_url": "optional",
        "source_name": "text",
        "license_id": "text",
    },
    "courses": {"slug": "slug", "title": "text", "description": "optional", "level": "positive"},
    "units": {"course_id": "uuid", "slug": "slug", "title": "text", "position": "positive"},
    "lessons": {
        "course_id": "uuid",
        "unit_id": "uuid",
        "slug": "slug",
        "title": "text",
        "objective": "text",
        "position": "positive",
        "xp_reward": "xp",
        "content": "object",
    },
    "lesson-items": {
        "lesson_id": "uuid",
        "position": "positive",
        "kind": "item_kind",
        "body": "object",
    },
    "quiz-questions": {
        "lesson_id": "uuid",
        "position": "positive",
        "kind": "question_kind",
        "prompt": "text",
        "explanation": "optional",
        "payload": "object",
        "answer": "json",
    },
    "quiz-options": {
        "question_id": "uuid",
        "position": "positive",
        "answer_text": "text",
        "is_correct": "boolean",
    },
    "real-english": {
        "slug": "slug",
        "kind": "expression_kind",
        "expression": "text",
        "meaning_vi": "text",
        "context_explanation": "text",
        "example_en": "text",
        "example_vi": "text",
        "dialogue": "array",
        "formality": "formality",
        "region_note": "text",
        "source_name": "text",
        "license_id": "text",
        "provenance_note": "text",
    },
    "badges": {
        "code": "slug",
        "title": "text",
        "description": "optional",
        "metric": "badge_metric",
        "target": "positive",
    },
}
TABLES = {
    "vocabulary": "dictionary_entries",
    "courses": "courses",
    "units": "learning_units",
    "lessons": "lessons",
    "lesson-items": "lesson_items",
    "quiz-questions": "quiz_questions",
    "quiz-options": "quiz_options",
    "real-english": "real_english_expressions",
    "badges": "badges",
}
PUBLISHABLE = set(TABLES) - {"quiz-options"}
CHOICES = {
    "item_kind": {"reading", "tip"},
    "question_kind": {"multiple_choice", "fill_blank", "matching", "listening", "grammar"},
    "expression_kind": {
        "slang",
        "idiom",
        "phrasal_verb",
        "casual_expression",
        "everyday_conversation",
        "movie_style_dialogue",
    },
    "formality": {"informal", "neutral", "formal"},
    "badge_metric": {"completed_lessons", "total_xp"},
}
OPTIONAL = {"optional", "object", "array", "json", "xp"}


class EditorInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    data: dict[str, Any] = Field(default_factory=dict)


def _admin(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> CurrentUser:
    with db.begin():
        found = db.execute(
            text("SELECT 1 FROM public.admin_members WHERE user_id=:uid"), {"uid": user.id}
        ).scalar_one_or_none()
    if not found:
        raise AppError(403, "admin_required", "Administrator access required")
    return user


def _spec(resource: str) -> tuple[str, dict[str, str]]:
    if resource not in TABLES:
        raise AppError(404, "unknown_resource", "Unknown content resource")
    return TABLES[resource], FIELDS[resource]


def _clean(resource: str, raw: dict[str, Any], create: bool) -> dict[str, Any]:
    _, spec = _spec(resource)
    if not raw or set(raw) - set(spec):
        raise AppError(422, "invalid_content", "Unknown or empty content fields")
    if create:
        missing = {name for name, kind in spec.items() if kind not in OPTIONAL and name not in raw}
        if missing:
            raise AppError(422, "missing_fields", "Required content fields are missing")
    clean: dict[str, Any] = {}
    for name, value in raw.items():
        kind = spec[name]
        if kind == "optional" and value is None:
            clean[name] = None
        elif kind in {"text", "optional", "slug"} or kind in CHOICES:
            if (
                not isinstance(value, str)
                or len(value.strip()) > 5000
                or (kind != "optional" and not value.strip())
            ):
                raise AppError(422, "invalid_content", f"Invalid {name}")
            value = value.strip()
            if kind == "slug" and not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", value):
                raise AppError(422, "invalid_content", f"Invalid {name}")
            if kind in CHOICES and value not in CHOICES[kind]:
                raise AppError(422, "invalid_content", f"Invalid {name}")
            clean[name] = value
        elif kind == "uuid":
            try:
                clean[name] = UUID(str(value))
            except (ValueError, TypeError) as exc:
                raise AppError(422, "invalid_content", f"Invalid {name}") from exc
        elif kind in {"positive", "xp"}:
            if type(value) is not int or not (0 if kind == "xp" else 1) <= value <= (
                1000 if kind == "xp" else 1000000
            ):
                raise AppError(422, "invalid_content", f"Invalid {name}")
            clean[name] = value
        elif kind == "boolean":
            if type(value) is not bool:
                raise AppError(422, "invalid_content", f"Invalid {name}")
            clean[name] = value
        elif kind in {"object", "array", "json"}:
            expected = (dict, list) if kind == "json" else dict if kind == "object" else list
            if not isinstance(value, expected) or len(json.dumps(value)) > 20000:
                raise AppError(422, "invalid_content", f"Invalid {name}")
            clean[name] = value
    if resource == "vocabulary" and "term" in clean:
        clean["normalized_term"] = clean["term"].casefold()
    return clean


def _db_fields(resource: str, data: dict[str, Any]) -> dict[str, Any]:
    result = {k: v for k, v in data.items() if k not in {"answer", "metric", "target"}}
    for key in ("content", "body", "payload", "dialogue"):
        if key in result:
            result[key] = json.dumps(result[key])
    return result


def _row(db: Session, resource: str, record_id: UUID) -> dict[str, Any]:
    table, _ = _spec(resource)
    row = (
        db.execute(text(f"SELECT * FROM public.{table} WHERE id=:id"), {"id": record_id})
        .mappings()
        .one_or_none()
    )
    if row is None:
        raise AppError(404, "content_not_found", "Content item not found")
    result = dict(row)
    if resource == "quiz-questions":
        result["answer"] = db.execute(
            text("SELECT answer FROM public.quiz_answer_keys WHERE question_id=:id"),
            {"id": record_id},
        ).scalar_one_or_none()
    if resource == "badges":
        rule = (
            db.execute(
                text("SELECT metric,target FROM public.badge_rules WHERE badge_id=:id"),
                {"id": record_id},
            )
            .mappings()
            .one_or_none()
        )
        result.update(dict(rule) if rule else {"metric": None, "target": None})
    return result


def _audit(
    db: Session,
    actor: UUID,
    action: str,
    resource: str,
    record_id: UUID,
    before: dict | None,
    after: dict | None,
) -> None:
    db.execute(
        text(
            "INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data) VALUES (:actor,:action,:resource,:id,CAST(:before AS jsonb),CAST(:after AS jsonb))"
        ),
        {
            "actor": actor,
            "action": action,
            "resource": resource,
            "id": record_id,
            "before": json.dumps(before, default=str) if before else None,
            "after": json.dumps(after, default=str) if after else None,
        },
    )


def _write(db: Session, resource: str, record_id: UUID, data: dict[str, Any], create: bool) -> None:
    table, _ = _spec(resource)
    if resource == "quiz-options":
        parent_id = data.get("question_id")
        if parent_id is None and not create:
            parent_id = db.execute(
                text("SELECT question_id FROM public.quiz_options WHERE id=:id"), {"id": record_id}
            ).scalar_one_or_none()
        if (
            parent_id
            and db.execute(
                text("SELECT is_published FROM public.quiz_questions WHERE id=:id"),
                {"id": parent_id},
            ).scalar_one_or_none()
        ):
            raise AppError(
                409, "question_published", "Move the question to draft before editing options"
            )
    fields = _db_fields(resource, data)
    if create:
        if resource == "vocabulary":
            fields["language"] = "en"
        fields["id"] = record_id
        names = ",".join(fields)
        values = ",".join(
            f"CAST(:{name} AS jsonb)"
            if name in {"content", "body", "payload", "dialogue"}
            else f":{name}"
            for name in fields
        )
        db.execute(text(f"INSERT INTO public.{table} ({names}) VALUES ({values})"), fields)
    elif fields:
        fields["id"] = record_id
        assignments = ",".join(
            f"{name}=CAST(:{name} AS jsonb)"
            if name in {"content", "body", "payload", "dialogue"}
            else f"{name}=:{name}"
            for name in fields
            if name != "id"
        )
        db.execute(
            text(
                f"UPDATE public.{table} SET {assignments},updated_at=now() WHERE id=:id"
                if resource
                in {"vocabulary", "courses", "lessons", "quiz-questions", "real-english", "badges"}
                else f"UPDATE public.{table} SET {assignments} WHERE id=:id"
            ),
            fields,
        )
    if resource == "quiz-questions" and "answer" in data:
        db.execute(
            text(
                "INSERT INTO public.quiz_answer_keys(question_id,answer) VALUES (:id,CAST(:answer AS jsonb)) ON CONFLICT(question_id) DO UPDATE SET answer=EXCLUDED.answer"
            ),
            {"id": record_id, "answer": json.dumps(data["answer"])},
        )
        db.execute(
            text("UPDATE public.quiz_questions SET updated_at=now() WHERE id=:id"),
            {"id": record_id},
        )
    if resource == "quiz-options":
        db.execute(
            text(
                "UPDATE public.quiz_questions SET updated_at=now() WHERE id=(SELECT question_id FROM public.quiz_options WHERE id=:id)"
            ),
            {"id": record_id},
        )
    if resource == "badges" and ("metric" in data or "target" in data):
        current = (
            db.execute(
                text("SELECT metric,target FROM public.badge_rules WHERE badge_id=:id"),
                {"id": record_id},
            )
            .mappings()
            .one_or_none()
        )
        metric = data.get("metric", current["metric"] if current else None)
        target = data.get("target", current["target"] if current else None)
        if metric is None or target is None:
            raise AppError(422, "invalid_badge_rule", "Badge rule needs metric and target")
        db.execute(
            text(
                "INSERT INTO public.badge_rules(badge_id,metric,target) VALUES (:id,:metric,:target) ON CONFLICT(badge_id) DO UPDATE SET metric=EXCLUDED.metric,target=EXCLUDED.target"
            ),
            {"id": record_id, "metric": metric, "target": target},
        )
    if resource == "lessons":
        matches = db.execute(
            text(
                "SELECT 1 FROM public.lessons l JOIN public.learning_units u ON u.id=l.unit_id WHERE l.id=:id AND l.course_id=u.course_id"
            ),
            {"id": record_id},
        ).scalar_one_or_none()
        if not matches:
            raise AppError(422, "invalid_parent", "Lesson unit must belong to the selected course")


@router.get("/me", response_model=ApiResponse[dict[str, str]])
def admin_me(user: Annotated[CurrentUser, Depends(_admin)]) -> ApiResponse[dict[str, str]]:
    return ApiResponse(data={"user_id": str(user.id), "role": "admin"})


@router.get("/schema", response_model=ApiResponse[dict[str, dict[str, str]]])
def schema(user: Annotated[CurrentUser, Depends(_admin)]) -> ApiResponse[dict[str, dict[str, str]]]:
    _ = user.id
    return ApiResponse(data=FIELDS)


@router.get("/overview", response_model=ApiResponse[dict[str, int]])
def overview(
    user: Annotated[CurrentUser, Depends(_admin)], db: Annotated[Session, Depends(get_db_session)]
) -> ApiResponse[dict[str, int]]:
    _ = user.id
    counts = {}
    for resource in PUBLISHABLE:
        table = TABLES[resource]
        counts[resource] = db.execute(
            text(f"SELECT count(*) FROM public.{table} WHERE is_published AND archived_at IS NULL")
        ).scalar_one()
    return ApiResponse(data=counts)


@router.get("/publishing", response_model=ApiResponse[dict[str, int]])
def publishing(
    user: Annotated[CurrentUser, Depends(_admin)], db: Annotated[Session, Depends(get_db_session)]
) -> ApiResponse[dict[str, int]]:
    _ = user.id
    return ApiResponse(
        data={
            resource: db.execute(
                text(
                    f"SELECT count(*) FROM public.{TABLES[resource]} WHERE NOT is_published AND archived_at IS NULL"
                )
            ).scalar_one()
            for resource in PUBLISHABLE
        }
    )


@router.get("/analytics", response_model=ApiResponse[dict[str, int]])
def analytics(
    user: Annotated[CurrentUser, Depends(_admin)], db: Annotated[Session, Depends(get_db_session)]
) -> ApiResponse[dict[str, int]]:
    _ = user.id
    result = {
        name: db.execute(text(f"SELECT count(*) FROM public.{table}")).scalar_one()
        for name, table in {
            "learners": "profiles",
            "lesson_attempts": "lesson_attempts",
            "saved_words": "saved_vocabulary",
            "writing_submissions": "writing_submissions",
        }.items()
    }
    result["completed_lessons"] = db.execute(
        text(
            "SELECT count(*) FROM public.learning_progress WHERE status IN ('completed','mastered')"
        )
    ).scalar_one()
    return ApiResponse(data=result)


@router.get("/audit", response_model=ApiResponse[list[dict[str, Any]]])
def audit(
    user: Annotated[CurrentUser, Depends(_admin)],
    db: Annotated[Session, Depends(get_db_session)],
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
) -> ApiResponse[list[dict[str, Any]]]:
    _ = user.id
    rows = (
        db.execute(
            text(
                "SELECT id,actor_id,action,resource,record_id,created_at FROM public.admin_audit_logs ORDER BY created_at DESC,id DESC LIMIT :limit"
            ),
            {"limit": limit},
        )
        .mappings()
        .all()
    )
    return ApiResponse(data=[dict(row) for row in rows])


@router.get("/catalog/{resource}", response_model=ApiResponse[dict[str, Any]])
def list_content(
    resource: str,
    user: Annotated[CurrentUser, Depends(_admin)],
    db: Annotated[Session, Depends(get_db_session)],
    q: Annotated[str, Query(max_length=80)] = "",
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=50)] = 15,
) -> ApiResponse[dict[str, Any]]:
    _ = user.id
    table, spec = _spec(resource)
    search = next(
        (
            name
            for name in (
                "title",
                "term",
                "expression",
                "prompt",
                "answer_text",
                "kind",
                "slug",
                "code",
            )
            if name in spec
        ),
        "id",
    )
    params = {"q": f"%{q.strip()}%", "limit": page_size, "offset": (page - 1) * page_size}
    archive = "" if resource == "quiz-options" else "archived_at IS NULL AND "
    where = f"{archive}{search} ILIKE :q"
    order = "id DESC" if resource in {"quiz-options", "lesson-items"} else "created_at DESC,id DESC"
    rows = (
        db.execute(
            text(
                f"SELECT * FROM public.{table} WHERE {where} ORDER BY {order} LIMIT :limit OFFSET :offset"
            ),
            params,
        )
        .mappings()
        .all()
    )
    total = db.execute(
        text(f"SELECT count(*) FROM public.{table} WHERE {where}"), params
    ).scalar_one()
    return ApiResponse(
        data={
            "items": [dict(row) for row in rows],
            "total": total,
            "page": page,
            "page_size": page_size,
        }
    )


@router.get("/catalog/{resource}/{record_id}", response_model=ApiResponse[dict[str, Any]])
def get_content(
    resource: str,
    record_id: UUID,
    user: Annotated[CurrentUser, Depends(_admin)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[dict[str, Any]]:
    _ = user.id
    return ApiResponse(data=_row(db, resource, record_id))


@router.post("/catalog/{resource}", response_model=ApiResponse[dict[str, Any]], status_code=201)
def create_content(
    resource: str,
    payload: EditorInput,
    user: Annotated[CurrentUser, Depends(_admin)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[dict[str, Any]]:
    from uuid import uuid4

    data = _clean(resource, payload.data, True)
    record_id = uuid4()
    try:
        with db.begin():
            _write(db, resource, record_id, data, True)
            after = _row(db, resource, record_id)
            _audit(db, user.id, "create", resource, record_id, None, after)
    except IntegrityError as exc:
        raise AppError(
            409, "content_conflict", "Content conflicts with an existing record or parent"
        ) from exc
    return ApiResponse(data=after)


@router.patch("/catalog/{resource}/{record_id}", response_model=ApiResponse[dict[str, Any]])
def update_content(
    resource: str,
    record_id: UUID,
    payload: EditorInput,
    user: Annotated[CurrentUser, Depends(_admin)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[dict[str, Any]]:
    data = _clean(resource, payload.data, False)
    try:
        with db.begin():
            before = _row(db, resource, record_id)
            if (
                resource == "quiz-questions"
                and db.execute(
                    text(
                        "SELECT 1 FROM public.lesson_attempts WHERE lesson_id=(SELECT lesson_id FROM public.quiz_questions WHERE id=:id) LIMIT 1"
                    ),
                    {"id": record_id},
                ).scalar_one_or_none()
            ):
                raise AppError(409, "content_in_use", "Quiz content with attempts cannot be edited")
            _write(db, resource, record_id, data, False)
            after = _row(db, resource, record_id)
            _audit(db, user.id, "update", resource, record_id, before, after)
    except IntegrityError as exc:
        raise AppError(
            409, "content_conflict", "Content conflicts with an existing record or parent"
        ) from exc
    return ApiResponse(data=after)


@router.delete("/catalog/{resource}/{record_id}", response_model=ApiResponse[dict[str, bool]])
def archive_content(
    resource: str,
    record_id: UUID,
    user: Annotated[CurrentUser, Depends(_admin)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[dict[str, bool]]:
    table, _ = _spec(resource)
    if resource == "quiz-options":
        raise AppError(
            409, "archive_unsupported", "Quiz options cannot be archived; edit the question instead"
        )
    with db.begin():
        before = _row(db, resource, record_id)
        db.execute(
            text(f"UPDATE public.{table} SET is_published=false,archived_at=now() WHERE id=:id"),
            {"id": record_id},
        )
        _audit(db, user.id, "delete", resource, record_id, before, None)
    return ApiResponse(data={"archived": True})


@router.post("/catalog/{resource}/{record_id}/publish", response_model=ApiResponse[dict[str, Any]])
def publish_content(
    resource: str,
    record_id: UUID,
    user: Annotated[CurrentUser, Depends(_admin)],
    db: Annotated[Session, Depends(get_db_session)],
    published: bool = True,
) -> ApiResponse[dict[str, Any]]:
    table, _ = _spec(resource)
    if resource not in PUBLISHABLE:
        raise AppError(422, "not_publishable", "This resource follows its parent question")
    with db.begin():
        before = _row(db, resource, record_id)
        if before.get("archived_at"):
            raise AppError(409, "content_archived", "Archived content cannot be published")
        if published and resource == "quiz-questions":
            if before["kind"] == "multiple_choice":
                count, correct = db.execute(
                    text(
                        "SELECT count(*),count(*) FILTER (WHERE is_correct) FROM public.quiz_options WHERE question_id=:id"
                    ),
                    {"id": record_id},
                ).one()
                if count < 2 or correct != 1:
                    raise AppError(
                        422,
                        "quiz_not_ready",
                        "Multiple choice needs at least two options and one correct answer",
                    )
            else:
                answer = before.get("answer")
                valid = (
                    isinstance(answer, dict)
                    if before["kind"] == "matching"
                    else isinstance(answer, list) and bool(answer)
                )
                if not valid:
                    raise AppError(422, "quiz_not_ready", "Quiz answer key has the wrong shape")
        db.execute(
            text(f"UPDATE public.{table} SET is_published=:published WHERE id=:id"),
            {"id": record_id, "published": published},
        )
        after = _row(db, resource, record_id)
        _audit(
            db, user.id, "publish" if published else "unpublish", resource, record_id, before, after
        )
    return ApiResponse(data=after)
