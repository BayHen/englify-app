"""Authenticated, read-only gamification state and server-validated reward claims."""
# ruff: noqa: E501 -- SQL statements are kept intact for readability.

from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser, get_current_user
from app.core.responses import ApiResponse, AppError
from app.db.session import get_db_session
from app.gamification.service import level_snapshot, period_bounds

router = APIRouter(prefix="/api/v1/gamification", tags=["gamification"])


class QuestProgress(BaseModel):
    id: UUID
    title: str
    description: str
    period: Literal["daily", "weekly"]
    progress: int
    target: int
    reward_xp: int
    completed: bool


class BadgeState(BaseModel):
    id: UUID
    title: str
    description: str
    unlocked: bool
    unlocked_at: datetime | None


class RewardState(BaseModel):
    id: UUID
    title: str
    description: str
    xp_cost: int
    required_level: int
    claimed: bool
    eligible: bool


class LearningStatistics(BaseModel):
    completed_lessons: int
    mastered_lessons: int
    quiz_attempts: int
    correct_answers: int


class GamificationOverview(BaseModel):
    total_xp: int
    level: int
    xp_into_level: int
    xp_for_next_level: int
    available_xp: int
    quests: list[QuestProgress]
    badges: list[BadgeState]
    rewards: list[RewardState]
    statistics: LearningStatistics


class RewardClaimResult(BaseModel):
    claim_id: UUID
    reward_id: UUID
    claimed_at: datetime
    newly_claimed: bool
    available_xp: int


class RewardNotification(BaseModel):
    id: UUID
    kind: Literal["xp", "level", "badge", "quest", "reward"]
    title: str
    message: str
    created_at: datetime
    read_at: datetime | None


@router.get("", response_model=ApiResponse[GamificationOverview])
def get_gamification(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[GamificationOverview]:
    total, level, step = level_snapshot(db, user.id)
    spent = db.execute(
        text("SELECT coalesce(sum(xp_cost), 0) FROM public.reward_claims WHERE user_id = :id"),
        {"id": user.id},
    ).scalar_one()
    available = max(0, total - int(spent))
    now = db.execute(text("SELECT transaction_timestamp()")).scalar_one()
    quests = []
    for row in db.execute(
        text(
            "SELECT id, title, description, period, target_lessons, reward_xp FROM public.quests WHERE is_active ORDER BY period, id"
        )
    ).mappings():
        period_start, start, end = period_bounds(row["period"], now)
        progress = db.execute(
            text(
                "SELECT count(*) FROM public.learning_progress WHERE user_id = :user_id AND completed_at >= :start AND completed_at < :end"
            ),
            {"user_id": user.id, "start": start, "end": end},
        ).scalar_one()
        claimed = db.execute(
            text(
                "SELECT EXISTS(SELECT 1 FROM public.quest_claims WHERE user_id = :user_id AND quest_id = :quest_id AND period_start = :period_start)"
            ),
            {"user_id": user.id, "quest_id": row["id"], "period_start": period_start},
        ).scalar_one()
        quests.append(
            QuestProgress(
                id=row["id"],
                title=row["title"],
                description=row["description"],
                period=row["period"],
                progress=min(progress, row["target_lessons"]),
                target=row["target_lessons"],
                reward_xp=row["reward_xp"],
                completed=claimed,
            )
        )
    badges = [
        BadgeState(
            id=r["id"],
            title=r["title"],
            description=r["description"],
            unlocked=r["awarded_at"] is not None,
            unlocked_at=r["awarded_at"],
        )
        for r in db.execute(
            text("""
        SELECT b.id, b.title, b.description, ub.awarded_at FROM public.badges b
        JOIN public.badge_rules br ON br.badge_id = b.id
        LEFT JOIN public.user_badges ub ON ub.badge_id = b.id AND ub.user_id = :user_id
        WHERE b.is_published AND b.archived_at IS NULL
        ORDER BY br.target, b.title
    """),
            {"user_id": user.id},
        ).mappings()
    ]
    rewards = [
        RewardState(
            id=r["id"],
            title=r["title"],
            description=r["description"],
            xp_cost=r["xp_cost"],
            required_level=r["required_level"],
            claimed=r["claim_id"] is not None,
            eligible=r["claim_id"] is None
            and level >= r["required_level"]
            and available >= r["xp_cost"],
        )
        for r in db.execute(
            text("""
        SELECT r.id, r.title, r.description, r.xp_cost, r.required_level, rc.id AS claim_id
        FROM public.reward_items r LEFT JOIN public.reward_claims rc
          ON rc.reward_id = r.id AND rc.user_id = :user_id
        WHERE r.is_active ORDER BY r.xp_cost, r.title
    """),
            {"user_id": user.id},
        ).mappings()
    ]
    stats = db.execute(
        text("""
        SELECT
          (SELECT count(*) FROM public.learning_progress WHERE user_id = :id AND status IN ('completed', 'mastered')) AS completed,
          (SELECT count(*) FROM public.learning_progress WHERE user_id = :id AND status = 'mastered') AS mastered,
          (SELECT count(*) FROM public.lesson_attempts WHERE user_id = :id) AS attempts,
          (SELECT coalesce(sum(correct_count), 0) FROM public.lesson_attempts WHERE user_id = :id) AS correct
    """),
        {"id": user.id},
    ).one()
    return ApiResponse(
        data=GamificationOverview(
            total_xp=total,
            level=level,
            xp_into_level=total % step,
            xp_for_next_level=step,
            available_xp=available,
            quests=quests,
            badges=badges,
            rewards=rewards,
            statistics=LearningStatistics(
                completed_lessons=stats.completed,
                mastered_lessons=stats.mastered,
                quiz_attempts=stats.attempts,
                correct_answers=stats.correct,
            ),
        )
    )


@router.post("/rewards/{reward_id}/claim", response_model=ApiResponse[RewardClaimResult])
def claim_reward(
    reward_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[RewardClaimResult]:
    with db.begin():
        db.execute(text("SELECT pg_advisory_xact_lock(hashtext(:key))"), {"key": str(user.id)})
        reward = (
            db.execute(
                text(
                    "SELECT id, title, xp_cost, required_level FROM public.reward_items WHERE id = :id AND is_active"
                ),
                {"id": reward_id},
            )
            .mappings()
            .one_or_none()
        )
        if reward is None:
            raise AppError(404, "reward_not_found", "Reward is unavailable")
        total, level, _ = level_snapshot(db, user.id)
        spent = int(
            db.execute(
                text(
                    "SELECT coalesce(sum(xp_cost), 0) FROM public.reward_claims WHERE user_id = :id"
                ),
                {"id": user.id},
            ).scalar_one()
        )
        previous = (
            db.execute(
                text(
                    "SELECT id, claimed_at FROM public.reward_claims WHERE user_id = :user_id AND reward_id = :reward_id"
                ),
                {"user_id": user.id, "reward_id": reward_id},
            )
            .mappings()
            .one_or_none()
        )
        if previous:
            return ApiResponse(
                data=RewardClaimResult(
                    claim_id=previous["id"],
                    reward_id=reward_id,
                    claimed_at=previous["claimed_at"],
                    newly_claimed=False,
                    available_xp=max(0, total - spent),
                )
            )
        if level < reward["required_level"]:
            raise AppError(403, "level_required", "Reach the required level to claim this reward")
        if total - spent < reward["xp_cost"]:
            raise AppError(403, "insufficient_xp", "Not enough available XP")
        claim = (
            db.execute(
                text("""
            INSERT INTO public.reward_claims(user_id, reward_id, xp_cost)
            VALUES (:user_id, :reward_id, :xp_cost) RETURNING id, claimed_at
        """),
                {"user_id": user.id, "reward_id": reward_id, "xp_cost": reward["xp_cost"]},
            )
            .mappings()
            .one()
        )
        db.execute(
            text("""
            INSERT INTO public.reward_notifications(user_id, kind, source_id, title, message)
            VALUES (:user_id, 'reward', :source_id, :title, 'Reward claimed!')
            ON CONFLICT (user_id, kind, source_id) DO NOTHING
        """),
            {"user_id": user.id, "source_id": claim["id"], "title": reward["title"]},
        )
        return ApiResponse(
            data=RewardClaimResult(
                claim_id=claim["id"],
                reward_id=reward_id,
                claimed_at=claim["claimed_at"],
                newly_claimed=True,
                available_xp=total - spent - reward["xp_cost"],
            )
        )


@router.get("/notifications", response_model=ApiResponse[list[RewardNotification]])
def list_notifications(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[list[RewardNotification]]:
    rows = (
        db.execute(
            text("""
        SELECT id, kind, title, message, created_at, read_at FROM public.reward_notifications
        WHERE user_id = :user_id ORDER BY created_at DESC, id DESC LIMIT 50
    """),
            {"user_id": user.id},
        )
        .mappings()
        .all()
    )
    return ApiResponse(data=[RewardNotification.model_validate(row) for row in rows])


@router.post("/notifications/{notification_id}/read", response_model=ApiResponse[dict[str, bool]])
def mark_notification_read(
    notification_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[dict[str, bool]]:
    with db.begin():
        result = db.execute(
            text("""
            UPDATE public.reward_notifications SET read_at = coalesce(read_at, now())
            WHERE id = :id AND user_id = :user_id
        """),
            {"id": notification_id, "user_id": user.id},
        )
    return ApiResponse(data={"read": result.rowcount == 1})
