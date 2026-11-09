"""Authenticated, server-generated weekly learning plans."""
# ruff: noqa: E501 -- SQL statements are kept intact for readability.

from datetime import UTC, date, datetime
from typing import Annotated, Literal
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api.learning import _journey
from app.core.auth import CurrentUser, get_current_user
from app.core.responses import ApiResponse, AppError
from app.db.session import get_db_session
from app.planning.rules import ALGORITHM_VERSION, LessonCandidate, PlanInput, generate_week

router = APIRouter(prefix="/api/v1/learning-plan", tags=["learning-plan"])


class PlanPreferences(BaseModel):
    model_config = ConfigDict(extra="forbid")
    learning_goal: Literal["conversation", "travel", "work", "exams", "real_english"]
    initial_proficiency: Literal["beginner", "intermediate", "advanced"]
    daily_goal_minutes: int = Field(ge=1, le=180)
    preferred_topics: list[str] = Field(default_factory=list, max_length=8)

    @field_validator("preferred_topics")
    @classmethod
    def validate_topics(cls, value: list[str]) -> list[str]:
        cleaned = [topic.strip().lower() for topic in value]
        if any(not topic or len(topic) > 40 for topic in cleaned) or len(set(cleaned)) != len(
            cleaned
        ):
            raise ValueError("Topics must be unique and 1-40 characters")
        return cleaned


class PlanTask(BaseModel):
    id: UUID
    kind: str
    title: str
    scheduled_on: date
    original_date: date
    duration_minutes: int
    target_count: int | None
    topic: str | None
    lesson_id: UUID | None
    status: str
    lesson_state: str | None = None


class LearningPlan(BaseModel):
    id: UUID
    starts_on: date
    algorithm_version: int
    preferences: PlanPreferences
    tasks: list[PlanTask]
    completed_count: int
    total_count: int
    weekly_minutes: int


def _preferences(db: Session, user_id: UUID) -> PlanPreferences:
    row = (
        db.execute(
            text("""
        SELECT learning_goal, initial_proficiency, daily_goal_minutes, preferred_topics
        FROM public.user_preferences WHERE user_id = :uid AND onboarding_completed_at IS NOT NULL
    """),
            {"uid": user_id},
        )
        .mappings()
        .one_or_none()
    )
    if not row or not row["learning_goal"] or not row["initial_proficiency"]:
        raise AppError(409, "onboarding_required", "Complete onboarding before generating a plan")
    return PlanPreferences.model_validate(dict(row))


def _lock(db: Session, user_id: UUID) -> None:
    db.execute(text("SELECT pg_advisory_xact_lock(hashtext(:key))"), {"key": f"plan:{user_id}"})


def _generate(db: Session, user_id: UUID, today: date) -> UUID:
    preferences = _preferences(db, user_id)
    rows = (
        db.execute(
            text("""
        SELECT l.id, l.title, COALESCE(p.status IN ('completed', 'mastered'), false) AS completed
        FROM public.courses c JOIN public.learning_units u ON u.course_id = c.id AND u.is_published AND u.archived_at IS NULL
        JOIN public.lessons l ON l.unit_id = u.id AND l.is_published AND l.archived_at IS NULL
        LEFT JOIN public.learning_progress p ON p.lesson_id = l.id AND p.user_id = :uid
        WHERE c.is_published AND c.archived_at IS NULL ORDER BY c.level, c.id, u.position, l.position
    """),
            {"uid": user_id},
        )
        .mappings()
        .all()
    )
    accuracy = db.execute(
        text("""
        SELECT SUM(correct_count)::float / NULLIF(SUM(question_count), 0)
        FROM (SELECT correct_count, question_count FROM public.lesson_attempts
              WHERE user_id = :uid ORDER BY created_at DESC LIMIT 10) recent
    """),
        {"uid": user_id},
    ).scalar_one()
    due = db.execute(
        text(
            "SELECT count(*) FROM public.saved_vocabulary WHERE user_id = :uid AND (next_review_at IS NULL OR next_review_at <= now())"
        ),
        {"uid": user_id},
    ).scalar_one()
    tasks = generate_week(
        PlanInput(
            today,
            preferences.initial_proficiency,
            preferences.learning_goal,
            preferences.daily_goal_minutes,
            tuple(preferences.preferred_topics),
            accuracy,
            tuple(LessonCandidate(row["id"], row["title"], row["completed"]) for row in rows),
            due,
        )
    )
    db.execute(
        text(
            "UPDATE public.learning_plans SET status = 'paused', updated_at = now() WHERE user_id = :uid AND status = 'active'"
        ),
        {"uid": user_id},
    )
    plan_id = uuid4()
    db.execute(
        text("""
        INSERT INTO public.learning_plans(id, user_id, title, goal, status, starts_on, algorithm_version)
        VALUES (:id, :uid, 'Weekly learning plan', :goal, 'active', :today, :version)
    """),
        {
            "id": plan_id,
            "uid": user_id,
            "goal": preferences.learning_goal,
            "today": today,
            "version": ALGORITHM_VERSION,
        },
    )
    for position, task in enumerate(tasks):
        db.execute(
            text("""
            INSERT INTO public.learning_plan_tasks
              (plan_id, user_id, lesson_id, kind, title, scheduled_on, original_date,
               duration_minutes, target_count, topic, position)
            VALUES (:plan, :uid, :lesson, :kind, :title, :day, :day, :minutes, :count, :topic, :position)
        """),
            {
                "plan": plan_id,
                "uid": user_id,
                "lesson": task.lesson_id,
                "kind": task.kind,
                "title": task.title,
                "day": task.day,
                "minutes": task.minutes,
                "count": task.target_count,
                "topic": task.topic,
                "position": position,
            },
        )
    return plan_id


def _read(db: Session, user_id: UUID, plan_id: UUID) -> LearningPlan:
    plan = (
        db.execute(
            text(
                "SELECT id, starts_on, algorithm_version FROM public.learning_plans WHERE id = :id AND user_id = :uid"
            ),
            {"id": plan_id, "uid": user_id},
        )
        .mappings()
        .one()
    )
    rows = (
        db.execute(
            text("""
        SELECT t.id, t.kind, t.title, t.scheduled_on, t.original_date, t.duration_minutes,
               t.target_count, t.topic, t.lesson_id,
               CASE WHEN p.status IN ('completed', 'mastered') THEN 'completed' ELSE t.status END AS status,
               p.status AS lesson_state
        FROM public.learning_plan_tasks t
        LEFT JOIN public.learning_progress p ON p.lesson_id = t.lesson_id AND p.user_id = :uid
        WHERE t.plan_id = :id AND t.user_id = :uid ORDER BY t.scheduled_on, t.position
    """),
            {"id": plan_id, "uid": user_id},
        )
        .mappings()
        .all()
    )
    tasks = [PlanTask.model_validate(dict(row)) for row in rows]
    states = {
        lesson.id: lesson.state
        for course in _journey(db, user_id)
        for unit in course.units
        for lesson in unit.lessons
    }
    for task in tasks:
        if task.lesson_id is not None:
            task.lesson_state = states.get(task.lesson_id, "locked")
    return LearningPlan(
        id=plan["id"],
        starts_on=plan["starts_on"],
        algorithm_version=plan["algorithm_version"],
        preferences=_preferences(db, user_id),
        tasks=tasks,
        completed_count=sum(task.status == "completed" for task in tasks),
        total_count=len(tasks),
        weekly_minutes=sum(task.duration_minutes for task in tasks),
    )


def _active(db: Session, user_id: UUID) -> UUID | None:
    return db.execute(
        text("SELECT id FROM public.learning_plans WHERE user_id = :uid AND status = 'active' AND starts_on IS NOT NULL"),
        {"uid": user_id},
    ).scalar_one_or_none()


@router.get("", response_model=ApiResponse[LearningPlan])
def get_plan(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[LearningPlan]:
    today = datetime.now(UTC).date()
    with db.begin():
        _lock(db, user.id)
        plan_id = _active(db, user.id) or _generate(db, user.id, today)
        result = _read(db, user.id, plan_id)
    return ApiResponse(data=result)


@router.post("/regenerate", response_model=ApiResponse[LearningPlan])
def regenerate(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[LearningPlan]:
    with db.begin():
        _lock(db, user.id)
        result = _read(db, user.id, _generate(db, user.id, datetime.now(UTC).date()))
    return ApiResponse(data=result)


@router.put("/preferences", response_model=ApiResponse[LearningPlan])
def update_preferences(
    payload: PlanPreferences,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[LearningPlan]:
    with db.begin():
        _lock(db, user.id)
        _preferences(db, user.id)
        db.execute(
            text("""
            UPDATE public.user_preferences SET learning_goal = :goal, initial_proficiency = :level,
              daily_goal_minutes = :minutes, preferred_topics = :topics, updated_at = now()
            WHERE user_id = :uid
        """),
            {
                "goal": payload.learning_goal,
                "level": payload.initial_proficiency,
                "minutes": payload.daily_goal_minutes,
                "topics": payload.preferred_topics,
                "uid": user.id,
            },
        )
        result = _read(db, user.id, _generate(db, user.id, datetime.now(UTC).date()))
    return ApiResponse(data=result)


@router.post("/reschedule", response_model=ApiResponse[LearningPlan])
def reschedule(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[LearningPlan]:
    today = datetime.now(UTC).date()
    with db.begin():
        _lock(db, user.id)
        plan_id = _active(db, user.id)
        if plan_id is None:
            plan_id = _generate(db, user.id, today)
        limit = _preferences(db, user.id).daily_goal_minutes
        rows = (
            db.execute(
                text("""
            SELECT t.id, t.scheduled_on, t.duration_minutes,
                   COALESCE(p.status IN ('completed', 'mastered'), false) AS lesson_done
            FROM public.learning_plan_tasks t
            LEFT JOIN public.learning_progress p ON p.lesson_id = t.lesson_id AND p.user_id = :uid
            WHERE t.plan_id = :plan AND t.user_id = :uid AND t.status = 'pending'
            ORDER BY t.scheduled_on, t.position FOR UPDATE OF t
        """),
                {"plan": plan_id, "uid": user.id},
            )
            .mappings()
            .all()
        )
        scheduled = db.execute(
            text("""
            SELECT t.scheduled_on, COALESCE(SUM(t.duration_minutes), 0)
            FROM public.learning_plan_tasks t
            LEFT JOIN public.learning_progress p ON p.lesson_id = t.lesson_id AND p.user_id = :uid
            WHERE t.plan_id = :plan AND t.user_id = :uid AND t.scheduled_on >= :today
              AND t.status = 'pending' AND (p.status IS NULL OR p.status NOT IN ('completed', 'mastered'))
            GROUP BY t.scheduled_on
        """),
            {"plan": plan_id, "uid": user.id, "today": today},
        ).all()
        used = dict(scheduled)
        from datetime import timedelta

        for row in rows:
            if row["scheduled_on"] >= today or row["lesson_done"]:
                continue
            day = today
            while used.get(day, 0) + row["duration_minutes"] > limit:
                day += timedelta(days=1)
            used[day] = used.get(day, 0) + row["duration_minutes"]
            db.execute(
                text(
                    "UPDATE public.learning_plan_tasks SET scheduled_on = :day, updated_at = now() WHERE id = :id AND user_id = :uid"
                ),
                {"day": day, "id": row["id"], "uid": user.id},
            )
        result = _read(db, user.id, plan_id)
    return ApiResponse(data=result)


@router.post("/tasks/{task_id}/complete", response_model=ApiResponse[LearningPlan])
def complete_task(
    task_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[LearningPlan]:
    with db.begin():
        _lock(db, user.id)
        plan_id = _active(db, user.id)
        if plan_id is None:
            raise AppError(404, "plan_not_found", "Generate a plan first")
        row = (
            db.execute(
                text(
                    "SELECT kind FROM public.learning_plan_tasks WHERE id = :id AND user_id = :uid AND plan_id = :plan"
                ),
                {"id": task_id, "uid": user.id, "plan": plan_id},
            )
            .mappings()
            .one_or_none()
        )
        if row is None:
            raise AppError(404, "task_not_found", "Task not found")
        if row["kind"] == "lesson":
            raise AppError(
                409, "lesson_requires_quiz", "Complete the lesson quiz to finish this task"
            )
        db.execute(
            text(
                "UPDATE public.learning_plan_tasks SET status = 'completed', completed_at = COALESCE(completed_at, now()), updated_at = now() WHERE id = :id AND user_id = :uid"
            ),
            {"id": task_id, "uid": user.id},
        )
        result = _read(db, user.id, plan_id)
    return ApiResponse(data=result)
