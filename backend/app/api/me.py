"""Authenticated profile and onboarding preferences."""

from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser, get_current_user
from app.core.responses import ApiResponse, AppError
from app.db.session import get_db_session

router = APIRouter(prefix="/api/v1/me", tags=["me"])


class Preferences(BaseModel):
    learning_goal: Literal["conversation", "travel", "work", "exams"] | None = None
    initial_proficiency: Literal["beginner", "intermediate", "advanced"] | None = None
    daily_goal_minutes: int = Field(default=10, ge=1, le=180)
    onboarding_completed_at: datetime | None = None


class Profile(BaseModel):
    id: UUID
    display_name: str
    preferences: Preferences | None = None


class OnboardingInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    learning_goal: Literal["conversation", "travel", "work", "exams"]
    initial_proficiency: Literal["beginner", "intermediate", "advanced"]
    daily_goal_minutes: int = Field(ge=1, le=180)


class ProfileInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    display_name: str = Field(min_length=1, max_length=80)


def load_profile(db: Session, user_id: UUID) -> Profile:
    row = db.execute(
        text("""
            SELECT p.id, p.display_name, up.learning_goal, up.initial_proficiency,
                   up.daily_goal_minutes, up.onboarding_completed_at
            FROM public.profiles AS p
            LEFT JOIN public.user_preferences AS up ON up.user_id = p.id
            WHERE p.id = :user_id
        """),
        {"user_id": user_id},
    ).mappings().one_or_none()
    if row is None:
        raise AppError(404, "profile_not_found", "Profile is not available yet")
    preferences = None
    if row["daily_goal_minutes"] is not None:
        preferences = Preferences(
            learning_goal=row["learning_goal"],
            initial_proficiency=row["initial_proficiency"],
            daily_goal_minutes=row["daily_goal_minutes"],
            onboarding_completed_at=row["onboarding_completed_at"],
        )
    return Profile(id=row["id"], display_name=row["display_name"], preferences=preferences)


@router.get("", response_model=ApiResponse[Profile])
def read_me(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[Profile]:
    return ApiResponse(data=load_profile(db, user.id))


@router.put("/onboarding", response_model=ApiResponse[Profile])
def save_onboarding(
    payload: OnboardingInput,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[Profile]:
    with db.begin():
        db.execute(
            text("""
                INSERT INTO public.user_preferences
                  (user_id, learning_goal, initial_proficiency, daily_goal_minutes,
                   onboarding_completed_at)
                VALUES (:user_id, :learning_goal, :initial_proficiency, :daily_goal_minutes, now())
                ON CONFLICT (user_id) DO UPDATE SET
                  learning_goal = EXCLUDED.learning_goal,
                  initial_proficiency = EXCLUDED.initial_proficiency,
                  daily_goal_minutes = EXCLUDED.daily_goal_minutes,
                  onboarding_completed_at = COALESCE(
                    public.user_preferences.onboarding_completed_at, now()
                  )
            """),
            {"user_id": user.id, **payload.model_dump()},
        )
    return ApiResponse(data=load_profile(db, user.id))


@router.patch("/profile", response_model=ApiResponse[Profile])
def update_profile(
    payload: ProfileInput,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[Profile]:
    name = payload.display_name.strip()
    if not name:
        raise AppError(422, "invalid_display_name", "Display name cannot be blank")
    with db.begin():
        result = db.execute(
            text("UPDATE public.profiles SET display_name = :name WHERE id = :user_id"),
            {"name": name, "user_id": user.id},
        )
        if result.rowcount != 1:
            raise AppError(404, "profile_not_found", "Profile is not available yet")
    return ApiResponse(data=load_profile(db, user.id))
