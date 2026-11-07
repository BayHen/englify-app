"""XP, quest, badge and level decisions made inside the caller's transaction."""
# ruff: noqa: E501 -- SQL statements are kept intact for readability.

from datetime import UTC, date, datetime, time, timedelta
from typing import Any
from uuid import NAMESPACE_URL, UUID, uuid5

from sqlalchemy import text
from sqlalchemy.orm import Session


def level_for_xp(total_xp: int, step: int) -> int:
    return max(0, total_xp) // step + 1


def period_bounds(period: str, now: datetime) -> tuple[date, datetime, datetime]:
    utc = now.astimezone(UTC)
    day = utc.date()
    start_day = day if period == "daily" else day - timedelta(days=day.weekday())
    start = datetime.combine(start_day, time.min, UTC)
    end = start + timedelta(days=1 if period == "daily" else 7)
    return start_day, start, end


def config(db: Session) -> tuple[int, int]:
    row = db.execute(
        text(
            "SELECT level_xp_step, lesson_multiplier_percent FROM public.gamification_config WHERE id = 1"
        )
    ).one()
    return row.level_xp_step, row.lesson_multiplier_percent


def level_snapshot(db: Session, user_id: UUID) -> tuple[int, int, int]:
    step, _ = config(db)
    row = db.execute(
        text("SELECT total_xp, level FROM public.user_levels WHERE user_id = :user_id"),
        {"user_id": user_id},
    ).one_or_none()
    if row is None:
        total = db.execute(
            text("SELECT coalesce(sum(amount), 0) FROM public.xp_events WHERE user_id = :user_id"),
            {"user_id": user_id},
        ).scalar_one()
        total = max(0, int(total))
        return total, level_for_xp(total, step), step
    return row.total_xp, row.level, step


def _notify(
    db: Session, user_id: UUID, kind: str, source_id: UUID, title: str, message: str
) -> None:
    db.execute(
        text("""
        INSERT INTO public.reward_notifications(user_id, kind, source_id, title, message)
        VALUES (:user_id, :kind, :source_id, :title, :message)
        ON CONFLICT (user_id, kind, source_id) DO NOTHING
    """),
        {
            "user_id": user_id,
            "kind": kind,
            "source_id": source_id,
            "title": title,
            "message": message,
        },
    )


def award_lesson_completion(
    db: Session, user_id: UUID, lesson_id: UUID, attempt_id: UUID, first_completion: bool
) -> tuple[int, list[dict[str, Any]]]:
    """Called after progress is written, while the same user transaction lock is held."""
    if not first_completion:
        return 0, []
    step, multiplier = config(db)
    before_total, before_level, _ = level_snapshot(db, user_id)
    rewards: list[dict[str, Any]] = []
    base_xp = db.execute(
        text("SELECT xp_reward FROM public.lessons WHERE id = :lesson_id"), {"lesson_id": lesson_id}
    ).scalar_one()
    lesson_xp = base_xp * multiplier // 100
    earned_xp = 0
    if lesson_xp:
        earned_xp = (
            db.execute(
                text("""
            INSERT INTO public.xp_events(user_id, source_type, source_id, amount)
            VALUES (:user_id, 'lesson', :lesson_id, :amount)
            ON CONFLICT (user_id, source_type, source_id) DO NOTHING
            RETURNING amount
        """),
                {"user_id": user_id, "lesson_id": lesson_id, "amount": lesson_xp},
            ).scalar_one_or_none()
            or 0
        )
    if earned_xp:
        rewards.append(
            {
                "kind": "xp",
                "title": "Lesson XP",
                "message": f"You earned {earned_xp} XP.",
                "amount": earned_xp,
            }
        )
        _notify(db, user_id, "xp", attempt_id, "Lesson XP", f"You earned {earned_xp} XP.")

    now = db.execute(text("SELECT transaction_timestamp()")).scalar_one()
    quests = (
        db.execute(
            text(
                "SELECT id, title, period, target_lessons, reward_xp FROM public.quests WHERE is_active ORDER BY period, id"
            )
        )
        .mappings()
        .all()
    )
    for quest in quests:
        period_start, start, end = period_bounds(quest["period"], now)
        count = db.execute(
            text("""
            SELECT count(*) FROM public.learning_progress
            WHERE user_id = :user_id AND completed_at >= :start AND completed_at < :end
        """),
            {"user_id": user_id, "start": start, "end": end},
        ).scalar_one()
        if count < quest["target_lessons"]:
            continue
        claim_id = db.execute(
            text("""
            INSERT INTO public.quest_claims(user_id, quest_id, period_start, awarded_xp)
            VALUES (:user_id, :quest_id, :period_start, :xp)
            ON CONFLICT (user_id, quest_id, period_start) DO NOTHING
            RETURNING id
        """),
            {
                "user_id": user_id,
                "quest_id": quest["id"],
                "period_start": period_start,
                "xp": quest["reward_xp"],
            },
        ).scalar_one_or_none()
        if claim_id is None:
            continue
        if quest["reward_xp"]:
            db.execute(
                text("""
                INSERT INTO public.xp_events(user_id, source_type, source_id, amount)
                VALUES (:user_id, 'quest', :source_id, :amount)
                ON CONFLICT (user_id, source_type, source_id) DO NOTHING
            """),
                {"user_id": user_id, "source_id": claim_id, "amount": quest["reward_xp"]},
            )
        rewards.append(
            {
                "kind": "quest",
                "title": quest["title"],
                "message": "Quest completed!",
                "amount": quest["reward_xp"],
            }
        )
        _notify(db, user_id, "quest", claim_id, quest["title"], "Quest completed!")

    total = max(
        0,
        int(
            db.execute(
                text(
                    "SELECT coalesce(sum(amount), 0) FROM public.xp_events WHERE user_id = :user_id"
                ),
                {"user_id": user_id},
            ).scalar_one()
        ),
    )
    new_level = level_for_xp(total, step)
    db.execute(
        text("""
        INSERT INTO public.user_levels(user_id, total_xp, level)
        VALUES (:user_id, :total, :level)
        ON CONFLICT (user_id) DO UPDATE SET total_xp = excluded.total_xp,
          level = excluded.level, updated_at = now()
    """),
        {"user_id": user_id, "total": total, "level": new_level},
    )
    if new_level > before_level:
        for reached in range(before_level + 1, new_level + 1):
            source_id = uuid5(NAMESPACE_URL, f"englify-level:{user_id}:{reached}")
            rewards.append(
                {"kind": "level", "title": f"Level {reached}", "message": "Level up!", "amount": 0}
            )
            _notify(db, user_id, "level", source_id, f"Level {reached}", "Level up!")
    completed = db.execute(
        text(
            "SELECT count(*) FROM public.learning_progress WHERE user_id = :user_id AND status IN ('completed', 'mastered')"
        ),
        {"user_id": user_id},
    ).scalar_one()
    rules = (
        db.execute(
            text("""
        SELECT b.id, b.title, r.metric, r.target FROM public.badge_rules r
        JOIN public.badges b ON b.id = r.badge_id ORDER BY r.target, b.id
    """)
        )
        .mappings()
        .all()
    )
    for rule in rules:
        value = completed if rule["metric"] == "completed_lessons" else total
        if value < rule["target"]:
            continue
        badge_event_id = db.execute(
            text("""
            INSERT INTO public.user_badges(user_id, badge_id)
            VALUES (:user_id, :badge_id)
            ON CONFLICT (user_id, badge_id) DO NOTHING RETURNING id
        """),
            {"user_id": user_id, "badge_id": rule["id"]},
        ).scalar_one_or_none()
        if badge_event_id:
            rewards.append(
                {"kind": "badge", "title": rule["title"], "message": "Badge unlocked!", "amount": 0}
            )
            _notify(db, user_id, "badge", badge_event_id, rule["title"], "Badge unlocked!")
    return earned_xp, rewards
