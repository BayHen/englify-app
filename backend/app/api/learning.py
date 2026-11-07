"""Server-authoritative journey, lessons and idempotent quiz submission."""
# ruff: noqa: E501 -- SQL statements are kept intact for readability.

import json
from datetime import datetime
from typing import Annotated, Any, Literal
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser, get_current_user
from app.core.responses import ApiResponse, AppError
from app.db.session import get_db_session
from app.gamification.service import award_lesson_completion, level_snapshot
from app.learning.grading import is_correct, passes

router = APIRouter(prefix="/api/v1", tags=["learning"])


class JourneyLesson(BaseModel):
    id: UUID
    title: str
    objective: str
    position: int
    state: Literal["locked", "available", "in_progress", "completed", "mastered"]


class JourneyUnit(BaseModel):
    id: UUID
    title: str
    position: int
    lessons: list[JourneyLesson]


class JourneyCourse(BaseModel):
    id: UUID
    title: str
    units: list[JourneyUnit]


class LessonItem(BaseModel):
    kind: Literal["reading", "tip"]
    body: dict[str, Any]


class Question(BaseModel):
    id: UUID
    kind: Literal["multiple_choice", "fill_blank", "matching", "listening", "grammar"]
    prompt: str
    payload: dict[str, Any]
    options: list[dict[str, str]]


class LessonDetail(BaseModel):
    id: UUID
    title: str
    objective: str
    state: str
    items: list[LessonItem]
    questions: list[Question]


class SubmitRequest(BaseModel):
    request_id: UUID
    answers: dict[UUID, str | dict[str, str]] = Field(min_length=1, max_length=30)


class QuizResult(BaseModel):
    attempt_id: UUID
    correct_count: int
    question_count: int
    passed: bool
    state: str
    earned_xp: int
    rewards: list[dict[str, Any]] = Field(default_factory=list)
    created_at: datetime


class JourneySummary(BaseModel):
    xp_total: int
    level: int
    xp_into_level: int
    xp_for_next_level: int
    completed_lessons: int
    total_lessons: int


def _journey_rows(db: Session, user_id: UUID):
    return (
        db.execute(
            text("""
        SELECT c.id AS course_id, c.title AS course_title,
               u.id AS unit_id, u.title AS unit_title, u.position AS unit_position,
               l.id AS lesson_id, l.title AS lesson_title, l.objective,
               l.position AS lesson_position, p.status
        FROM public.courses c
        JOIN public.learning_units u ON u.course_id = c.id
        JOIN public.lessons l ON l.unit_id = u.id AND l.is_published
        LEFT JOIN public.learning_progress p ON p.lesson_id = l.id AND p.user_id = :user_id
        WHERE c.is_published
        ORDER BY c.level, c.id, u.position, l.position
    """),
            {"user_id": user_id},
        )
        .mappings()
        .all()
    )


def _journey(db: Session, user_id: UUID) -> list[JourneyCourse]:
    courses: list[JourneyCourse] = []
    course_map: dict[UUID, JourneyCourse] = {}
    unit_map: dict[UUID, JourneyUnit] = {}
    previous_done: dict[UUID, bool] = {}
    for row in _journey_rows(db, user_id):
        course = course_map.get(row["course_id"])
        if course is None:
            course = JourneyCourse(id=row["course_id"], title=row["course_title"], units=[])
            courses.append(course)
            course_map[course.id] = course
            previous_done[course.id] = True
        unit = unit_map.get(row["unit_id"])
        if unit is None:
            unit = JourneyUnit(
                id=row["unit_id"],
                title=row["unit_title"],
                position=row["unit_position"],
                lessons=[],
            )
            course.units.append(unit)
            unit_map[unit.id] = unit
        status = row["status"]
        unlocked = previous_done[course.id]
        state = (
            status
            if status in {"in_progress", "completed", "mastered"}
            else "available"
            if unlocked
            else "locked"
        )
        unit.lessons.append(
            JourneyLesson(
                id=row["lesson_id"],
                title=row["lesson_title"],
                objective=row["objective"],
                position=row["lesson_position"],
                state=state,
            )
        )
        previous_done[course.id] = status in {"completed", "mastered"}
    return courses


def _allowed(db: Session, user_id: UUID, lesson_id: UUID) -> JourneyLesson:
    for course in _journey(db, user_id):
        for unit in course.units:
            for lesson in unit.lessons:
                if lesson.id == lesson_id:
                    if lesson.state == "locked":
                        raise AppError(403, "lesson_locked", "Complete the previous lesson first")
                    return lesson
    raise AppError(404, "lesson_not_found", "Published lesson not found")


@router.get("/journey", response_model=ApiResponse[list[JourneyCourse]])
def get_journey(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[list[JourneyCourse]]:
    return ApiResponse(data=_journey(db, user.id))


@router.get("/journey/summary", response_model=ApiResponse[JourneySummary])
def get_journey_summary(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[JourneySummary]:
    courses = _journey(db, user.id)
    lessons = [lesson for course in courses for unit in course.units for lesson in unit.lessons]
    xp, level, step = level_snapshot(db, user.id)
    return ApiResponse(
        data=JourneySummary(
            xp_total=xp,
            level=level,
            xp_into_level=xp % step,
            xp_for_next_level=step,
            completed_lessons=sum(lesson.state in {"completed", "mastered"} for lesson in lessons),
            total_lessons=len(lessons),
        )
    )


@router.get("/lessons/{lesson_id}", response_model=ApiResponse[LessonDetail])
def get_lesson(
    lesson_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[LessonDetail]:
    lesson = _allowed(db, user.id, lesson_id)
    items = (
        db.execute(
            text(
                "SELECT kind, body FROM public.lesson_items WHERE lesson_id = :id ORDER BY position"
            ),
            {"id": lesson_id},
        )
        .mappings()
        .all()
    )
    rows = (
        db.execute(
            text(
                "SELECT id, kind, prompt, payload FROM public.quiz_questions WHERE lesson_id = :id ORDER BY position"
            ),
            {"id": lesson_id},
        )
        .mappings()
        .all()
    )
    questions = []
    for row in rows:
        options = (
            db.execute(
                text(
                    "SELECT id, answer_text FROM public.quiz_options WHERE question_id = :id ORDER BY position"
                ),
                {"id": row["id"]},
            )
            .mappings()
            .all()
            if row["kind"] == "multiple_choice"
            else []
        )
        questions.append(
            Question(
                id=row["id"],
                kind=row["kind"],
                prompt=row["prompt"],
                payload=row["payload"],
                options=[{"id": str(o["id"]), "text": o["answer_text"]} for o in options],
            )
        )
    return ApiResponse(
        data=LessonDetail(
            id=lesson.id,
            title=lesson.title,
            objective=lesson.objective,
            state=lesson.state,
            items=[LessonItem.model_validate(i) for i in items],
            questions=questions,
        )
    )


@router.post("/lessons/{lesson_id}/start", response_model=ApiResponse[JourneyLesson])
def start_lesson(
    lesson_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[JourneyLesson]:
    with db.begin():
        db.execute(
            text("SELECT pg_advisory_xact_lock(hashtext(:key))"), {"key": f"{user.id}:{lesson_id}"}
        )
        lesson = _allowed(db, user.id, lesson_id)
        if lesson.state == "available":
            db.execute(
                text("""
                INSERT INTO public.learning_progress(user_id, lesson_id, status)
                VALUES (:user_id, :lesson_id, 'in_progress')
                ON CONFLICT (user_id, lesson_id) DO NOTHING
            """),
                {"user_id": user.id, "lesson_id": lesson_id},
            )
            lesson.state = "in_progress"
    return ApiResponse(data=lesson)


@router.post("/lessons/{lesson_id}/submit", response_model=ApiResponse[QuizResult])
def submit_lesson(
    lesson_id: UUID,
    payload: SubmitRequest,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[QuizResult]:
    with db.begin():
        db.execute(text("SELECT pg_advisory_xact_lock(hashtext(:key))"), {"key": str(user.id)})
        old = (
            db.execute(
                text(
                    "SELECT * FROM public.lesson_attempts WHERE user_id = :user_id AND request_id = :request_id"
                ),
                {"user_id": user.id, "request_id": payload.request_id},
            )
            .mappings()
            .one_or_none()
        )
        if old:
            if old["lesson_id"] != lesson_id:
                raise AppError(409, "request_id_reused", "Submission ID belongs to another lesson")
            return ApiResponse(
                data=QuizResult(
                    attempt_id=old["id"],
                    correct_count=old["correct_count"],
                    question_count=old["question_count"],
                    passed=old["passed"],
                    state=old["result_state"],
                    earned_xp=old["earned_xp"],
                    rewards=old["reward_payload"],
                    created_at=old["created_at"],
                )
            )
        lesson = _allowed(db, user.id, lesson_id)
        questions = (
            db.execute(
                text("""
            SELECT q.id, q.kind, k.answer AS answer_key
            FROM public.quiz_questions q
            LEFT JOIN public.quiz_answer_keys k ON k.question_id = q.id
            WHERE q.lesson_id = :lesson_id ORDER BY q.position
        """),
                {"lesson_id": lesson_id},
            )
            .mappings()
            .all()
        )
        if (
            not questions
            or len(questions) != len(payload.answers)
            or {q["id"] for q in questions} != set(payload.answers)
        ):
            raise AppError(422, "incomplete_answers", "Submit one answer for every lesson question")
        results: list[tuple[UUID, Any, bool]] = []
        for question in questions:
            key = question["answer_key"]
            if question["kind"] == "multiple_choice":
                key = db.execute(
                    text(
                        "SELECT id FROM public.quiz_options WHERE question_id = :id AND is_correct"
                    ),
                    {"id": question["id"]},
                ).scalar_one_or_none()
                if key is None:
                    raise AppError(503, "lesson_not_ready", "Lesson answer key is incomplete")
                key = str(key)
            elif key is None:
                raise AppError(503, "lesson_not_ready", "Lesson answer key is incomplete")
            answer = payload.answers[question["id"]]
            results.append((question["id"], answer, is_correct(question["kind"], answer, key)))
        correct = sum(item[2] for item in results)
        passed = passes(correct, len(results))
        prior_pass = db.execute(
            text(
                "SELECT EXISTS(SELECT 1 FROM public.lesson_attempts WHERE user_id = :user_id AND lesson_id = :lesson_id AND passed)"
            ),
            {"user_id": user.id, "lesson_id": lesson_id},
        ).scalar_one()
        state = (
            "mastered"
            if lesson.state == "mastered" or (passed and correct == len(results) and prior_pass)
            else "completed"
            if passed
            else lesson.state
            if lesson.state in {"completed", "mastered"}
            else "in_progress"
        )
        attempt_id = uuid4()
        row = db.execute(
            text("""
            INSERT INTO public.lesson_attempts(id, user_id, lesson_id, request_id, correct_count, question_count, passed, result_state)
            VALUES (:id, :user_id, :lesson_id, :request_id, :correct, :total, :passed, :state)
            RETURNING created_at
        """),
            {
                "id": attempt_id,
                "user_id": user.id,
                "lesson_id": lesson_id,
                "request_id": payload.request_id,
                "correct": correct,
                "total": len(results),
                "passed": passed,
                "state": state,
            },
        ).scalar_one()
        for question_id, answer, valid in results:
            db.execute(
                text("""
                INSERT INTO public.lesson_answer_attempts(attempt_id, question_id, answer, is_correct)
                VALUES (:attempt_id, :question_id, CAST(:answer AS jsonb), :valid)
            """),
                {
                    "attempt_id": attempt_id,
                    "question_id": question_id,
                    "answer": json.dumps(answer),
                    "valid": valid,
                },
            )
        db.execute(
            text("""
            INSERT INTO public.learning_progress(user_id, lesson_id, status, completed_at)
            VALUES (:user_id, :lesson_id, :state, CASE WHEN :passed THEN now() ELSE NULL END)
            ON CONFLICT (user_id, lesson_id) DO UPDATE SET status = EXCLUDED.status,
              completed_at = COALESCE(public.learning_progress.completed_at, EXCLUDED.completed_at)
        """),
            {
                "user_id": user.id,
                "lesson_id": lesson_id,
                "state": state,
                "passed": state in {"completed", "mastered"},
            },
        )
        earned_xp, rewards = award_lesson_completion(
            db, user.id, lesson_id, attempt_id, passed and not prior_pass
        )
        db.execute(
            text("""
                UPDATE public.lesson_attempts
                SET earned_xp = :xp, reward_payload = CAST(:rewards AS jsonb)
                WHERE id = :id
            """),
            {"xp": earned_xp, "rewards": json.dumps(rewards), "id": attempt_id},
        )
    return ApiResponse(
        data=QuizResult(
            attempt_id=attempt_id,
            correct_count=correct,
            question_count=len(results),
            passed=passed,
            state=state,
            earned_xp=earned_xp,
            rewards=rewards,
            created_at=row,
        )
    )


@router.get("/lessons/{lesson_id}/attempts", response_model=ApiResponse[list[QuizResult]])
def list_attempts(
    lesson_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[list[QuizResult]]:
    _allowed(db, user.id, lesson_id)
    rows = (
        db.execute(
            text(
                "SELECT id, correct_count, question_count, passed, result_state, earned_xp, reward_payload, created_at FROM public.lesson_attempts WHERE user_id = :user_id AND lesson_id = :lesson_id ORDER BY created_at DESC LIMIT 50"
            ),
            {"user_id": user.id, "lesson_id": lesson_id},
        )
        .mappings()
        .all()
    )
    return ApiResponse(
        data=[
            QuizResult(
                attempt_id=r["id"],
                correct_count=r["correct_count"],
                question_count=r["question_count"],
                passed=r["passed"],
                state=r["result_state"],
                earned_xp=r["earned_xp"],
                rewards=r["reward_payload"],
                created_at=r["created_at"],
            )
            for r in rows
        ]
    )
