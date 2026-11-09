"""Authenticated profile and onboarding preferences."""
# ruff: noqa: E501 -- Keep SQL statements and validation rules intact.

from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser, get_current_user
from app.core.responses import ApiResponse, AppError
from app.db.session import get_db_session

router = APIRouter(prefix="/api/v1/me", tags=["me"])


class Preferences(BaseModel):
    learning_goal: Literal["conversation", "travel", "work", "exams", "real_english"] | None = None
    initial_proficiency: Literal["beginner", "intermediate", "advanced"] | None = None
    daily_goal_minutes: int = Field(default=10, ge=1, le=180)
    onboarding_completed_at: datetime | None = None
    current_cefr: Literal["A1", "A2", "B1", "B2", "C1", "C2"] | None = None
    preferred_accent: Literal["en-US", "en-GB", "en-AU"] = "en-US"
    interface_language: Literal["en", "vi"] = "en"


class Profile(BaseModel):
    id: UUID
    display_name: str
    username: str | None = None
    bio: str | None = None
    avatar_url: str | None = None
    preferences: Preferences | None = None


class OnboardingInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    learning_goal: Literal["conversation", "travel", "work", "exams"]
    initial_proficiency: Literal["beginner", "intermediate", "advanced"]
    daily_goal_minutes: int = Field(ge=1, le=180)


class ProfileInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    display_name: str | None = Field(default=None, min_length=1, max_length=50)
    username: str | None = Field(default=None, min_length=3, max_length=30)
    bio: str | None = Field(default=None, max_length=160)
    avatar_url: str | None = None

    @field_validator("display_name", "bio", mode="before")
    @classmethod
    def trim_text(cls, value: str | None) -> str | None:
        return value.strip() if isinstance(value, str) else value

    @field_validator("username")
    @classmethod
    def normalize_username(cls, value: str | None) -> str | None:
        if value is None:
            return None
        import re

        cleaned = value.strip().lower()
        if not re.fullmatch(r"[a-z0-9_]{3,30}", cleaned):
            raise ValueError("Username must contain 3-30 lowercase letters, numbers or underscores")
        return cleaned

    @field_validator("bio")
    @classmethod
    def normalize_bio(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if len(cleaned) > 160:
            raise ValueError("Bio must contain at most 160 characters")
        return cleaned or None


class PreferencesInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    learning_goal: Literal["conversation", "travel", "work", "exams", "real_english"] | None = None
    current_cefr: Literal["A1", "A2", "B1", "B2", "C1", "C2"] | None = None
    daily_goal_minutes: int | None = Field(default=None, ge=1, le=180)
    preferred_accent: Literal["en-US", "en-GB", "en-AU"] | None = None
    interface_language: Literal["en", "vi"] | None = None

    @model_validator(mode="after")
    def reject_null_required_fields(self) -> "PreferencesInput":
        for field in ("learning_goal", "daily_goal_minutes", "preferred_accent", "interface_language"):
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"{field} cannot be null")
        return self


def load_profile(db: Session, user_id: UUID) -> Profile:
    row = db.execute(
        text("""
            SELECT p.id, p.display_name, p.username, p.bio, p.avatar_url,
                   up.learning_goal, up.initial_proficiency, up.daily_goal_minutes,
                   up.onboarding_completed_at, up.current_cefr, up.preferred_accent,
                   up.interface_language
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
            current_cefr=row["current_cefr"],
            preferred_accent=row["preferred_accent"],
            interface_language=row["interface_language"],
        )
    return Profile(id=row["id"], display_name=row["display_name"], username=row["username"],
                   bio=row["bio"], avatar_url=row["avatar_url"], preferences=preferences)


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
    changes = payload.model_dump(exclude_unset=True)
    if "display_name" in changes:
        name = (changes["display_name"] or "").strip()
        if not name:
            raise AppError(422, "invalid_display_name", "Display name cannot be blank")
        changes["display_name"] = name
    if "avatar_url" in changes and changes["avatar_url"] is not None:
        path = changes["avatar_url"]
        if not isinstance(path, str) or not path.startswith(f"{user.id}/") or not path.endswith(".jpg") or len(path) > 150:
            raise AppError(422, "invalid_avatar", "Avatar must be an owned JPEG storage path")
    if changes:
        try:
            with db.begin():
                assignments = ", ".join(f"{field} = :{field}" for field in changes)
                result = db.execute(
                    text(f"UPDATE public.profiles SET {assignments}, updated_at = now() WHERE id = :user_id"),
                    {**changes, "user_id": user.id},
                )
                if result.rowcount != 1:
                    raise AppError(404, "profile_not_found", "Profile is not available yet")
        except IntegrityError as exc:
            if getattr(getattr(exc.orig, "diag", None), "constraint_name", None) == "profiles_username_ci_unique":
                raise AppError(409, "username_taken", "Username is already taken") from exc
            raise
    return ApiResponse(data=load_profile(db, user.id))


@router.patch("/preferences", response_model=ApiResponse[Profile])
def update_preferences(
    payload: PreferencesInput,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[Profile]:
    changes = payload.model_dump(exclude_unset=True)
    if changes:
        if "current_cefr" in changes and changes["current_cefr"]:
            level = changes["current_cefr"]
            changes["initial_proficiency"] = "beginner" if level in {"A1", "A2"} else "intermediate" if level in {"B1", "B2"} else "advanced"
        with db.begin():
            assignments = ", ".join(f"{field} = :{field}" for field in changes)
            result = db.execute(
                text(f"UPDATE public.user_preferences SET {assignments}, updated_at = now() WHERE user_id = :user_id"),
                {**changes, "user_id": user.id},
            )
            if result.rowcount != 1:
                raise AppError(409, "onboarding_required", "Complete onboarding before editing preferences")
    return ApiResponse(data=load_profile(db, user.id))
