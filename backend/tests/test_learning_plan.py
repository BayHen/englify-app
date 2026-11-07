"""Deterministic scheduling and history-preserving plan behavior."""

from datetime import date, timedelta
from uuid import uuid4

import pytest

from app.planning.rules import LessonCandidate, PlanInput, generate_week, reschedule_missed


def sample(**changes):
    values = dict(
        start=date(2026, 11, 7),
        proficiency="beginner",
        goal="conversation",
        daily_minutes=30,
        topics=("travel", "food"),
        quiz_accuracy=0.9,
        lessons=(LessonCandidate(uuid4(), "Done", True), LessonCandidate(uuid4(), "Next")),
        due_reviews=2,
    )
    values.update(changes)
    return PlanInput(**values)


def test_week_is_deterministic_bounded_and_excludes_completed_lessons():
    inputs = sample()
    first = generate_week(inputs)
    assert first == generate_week(inputs)
    assert len({task.day for task in first}) == 7
    assert all(
        sum(task.minutes for task in first if task.day == day) <= 30
        for day in {task.day for task in first}
    )
    assert [task.title for task in first if task.kind == "lesson"] == ["Next"]
    assert {task.topic for task in first} == {"travel", "food"}


def test_weak_quiz_adds_review_and_slows_new_lessons():
    lessons = tuple(LessonCandidate(uuid4(), str(i)) for i in range(7))
    strong = generate_week(sample(lessons=lessons, due_reviews=0, quiz_accuracy=0.9))
    weak = generate_week(sample(lessons=lessons, due_reviews=0, quiz_accuracy=0.4))
    assert sum(task.kind == "lesson" for task in weak) < sum(
        task.kind == "lesson" for task in strong
    )
    assert sum(task.kind == "review" for task in weak) == 7


def test_short_days_and_goal_changes_remain_possible():
    tasks = generate_week(sample(daily_minutes=1, goal="work"))
    assert len(tasks) == 7
    assert all(task.minutes == 1 for task in tasks)
    work = generate_week(sample(goal="work", due_reviews=0, lessons=()))
    conversation = generate_week(sample(goal="conversation", due_reviews=0, lessons=()))
    assert work[1].kind != conversation[1].kind


def test_ten_minute_week_includes_all_practice_types():
    tasks = generate_week(sample(daily_minutes=10, due_reviews=2))
    assert {"lesson", "vocabulary", "review", "speaking", "writing"} <= {
        task.kind for task in tasks
    }
    assert all(sum(task.minutes for task in tasks if task.day == day) <= 10
               for day in {task.day for task in tasks})


def test_reschedule_keeps_every_task_and_honors_capacity():
    tasks = generate_week(sample(daily_minutes=20, due_reviews=0))
    today = sample().start + timedelta(days=2)
    moved = reschedule_missed(tasks, today, 20)
    assert len(moved) == len(tasks)
    assert all(task.day >= today for task in moved)
    assert all(
        sum(task.minutes for task in moved if task.day == day) <= 20
        for day in {task.day for task in moved}
    )


def test_invalid_limits_rejected():
    with pytest.raises(ValueError):
        generate_week(sample(daily_minutes=0))
    with pytest.raises(ValueError):
        generate_week(sample(quiz_accuracy=1.2))
