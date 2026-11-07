"""Pure weekly scheduling rules; all dates are UTC calendar dates."""

from dataclasses import dataclass
from datetime import date, timedelta
from uuid import UUID

ALGORITHM_VERSION = 1


@dataclass(frozen=True)
class LessonCandidate:
    id: UUID
    title: str
    completed: bool = False


@dataclass(frozen=True)
class PlanInput:
    start: date
    proficiency: str
    goal: str
    daily_minutes: int
    topics: tuple[str, ...]
    quiz_accuracy: float | None
    lessons: tuple[LessonCandidate, ...]
    due_reviews: int


@dataclass(frozen=True)
class PlannedTask:
    day: date
    kind: str
    title: str
    minutes: int
    target_count: int | None = None
    lesson_id: UUID | None = None
    topic: str | None = None


def generate_week(inputs: PlanInput) -> tuple[PlannedTask, ...]:
    """Schedule seven bounded days; never include completed lessons."""
    if not 1 <= inputs.daily_minutes <= 180:
        raise ValueError("daily_minutes must be between 1 and 180")
    if inputs.quiz_accuracy is not None and not 0 <= inputs.quiz_accuracy <= 1:
        raise ValueError("quiz_accuracy must be between 0 and 1")
    lessons = [lesson for lesson in inputs.lessons if not lesson.completed]
    struggling = inputs.quiz_accuracy is not None and inputs.quiz_accuracy < 0.6
    tasks: list[PlannedTask] = []
    lesson_index = 0
    practice = (
        ("writing", "speaking") if inputs.goal in {"work", "exams"} else ("speaking", "writing")
    )
    # A primary activity is reserved before optional work, so short goals
    # still include speaking, writing, vocabulary and review across the week.
    sequence = (
        ("review", practice[0], "lesson", practice[1], "review", "vocabulary", "lesson")
        if struggling
        else ("lesson", practice[0], "lesson", practice[1], "lesson", "vocabulary", "review")
    )
    for offset in range(7):
        day = inputs.start + timedelta(days=offset)
        topic = inputs.topics[offset % len(inputs.topics)] if inputs.topics else None
        budget = inputs.daily_minutes
        primary = sequence[offset]
        if primary == "lesson" and lesson_index < len(lessons) and budget >= 5:
            lesson = lessons[lesson_index]
            minutes = min(15 if inputs.proficiency == "beginner" else 20, budget)
            tasks.append(
                PlannedTask(day, "lesson", lesson.title, minutes, lesson_id=lesson.id, topic=topic)
            )
            budget -= minutes
            lesson_index += 1
        elif primary == "lesson":
            primary = "vocabulary"
        if primary == "review" and budget >= 5:
            minutes = min(10, budget)
            tasks.append(
                PlannedTask(
                    day,
                    "review",
                    "Review vocabulary and quiz mistakes",
                    minutes,
                    min(max(inputs.due_reviews, 3), 10),
                    topic=topic,
                )
            )
            budget -= minutes
        if primary in practice and budget >= 5:
            minutes = min(10, budget)
            tasks.append(
                PlannedTask(
                    day,
                    primary,
                    "Writing practice" if primary == "writing" else "Speaking practice",
                    minutes,
                    topic=topic,
                )
            )
            budget -= minutes
        if budget >= 5:
            minutes = min(5, budget)
            count = max(1, min(10, minutes // 2 + (1 if inputs.proficiency == "advanced" else 0)))
            tasks.append(
                PlannedTask(day, "vocabulary", "Learn new words", minutes, count, topic=topic)
            )
            budget -= minutes
        if (inputs.due_reviews > 0 or struggling) and budget >= 5 and primary != "review":
            minutes = min(5, budget)
            tasks.append(
                PlannedTask(
                    day,
                    "review",
                    "Review vocabulary and quiz mistakes",
                    minutes,
                    min(max(inputs.due_reviews, 3), 10),
                    topic=topic,
                )
            )
        if not any(task.day == day for task in tasks):
            # Very short study goals still get a concrete, achievable task.
            kind = primary if primary != "lesson" else "vocabulary"
            title = {
                "review": "Review one word",
                "vocabulary": "Learn one word",
                "speaking": "Say one sentence",
                "writing": "Write one sentence",
            }[kind]
            tasks.append(
                PlannedTask(
                    day,
                    kind,
                    title,
                    budget,
                    1 if kind in {"vocabulary", "review"} else None,
                    topic=topic,
                )
            )
    return tuple(tasks)


def reschedule_missed(
    tasks: tuple[PlannedTask, ...], today: date, daily_minutes: int
) -> tuple[PlannedTask, ...]:
    """Move overdue pending tasks forward, preserving order and every task."""
    existing = {today + timedelta(days=i): 0 for i in range(28)}
    for task in tasks:
        if task.day >= today and task.day in existing:
            existing[task.day] += task.minutes
    moved = []
    for task in tasks:
        if task.day >= today:
            moved.append(task)
            continue
        day = today
        while existing.get(day, 0) + task.minutes > daily_minutes:
            day += timedelta(days=1)
        existing[day] = existing.get(day, 0) + task.minutes
        moved.append(
            PlannedTask(
                day,
                task.kind,
                task.title,
                task.minutes,
                task.target_count,
                task.lesson_id,
                task.topic,
            )
        )
    return tuple(moved)
