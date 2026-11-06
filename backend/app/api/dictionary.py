"""Authenticated English–Vietnamese dictionary and personal flashcard source."""

from datetime import datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.core.auth import CurrentUser, get_current_user
from app.core.responses import ApiResponse, AppError
from app.db.models import DictionaryEntry, SavedVocabulary
from app.db.session import get_db_session

router = APIRouter(prefix="/api/v1", tags=["dictionary"])


class DictionaryWord(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    term: str
    definition: str
    translation: str | None
    ipa: str | None
    part_of_speech: str | None
    example: str | None
    audio_url: str | None
    source_name: str
    license_id: str


class SavedWord(BaseModel):
    id: UUID
    word: DictionaryWord
    created_at: datetime
    next_review_at: datetime | None


def _saved_word(saved: SavedVocabulary, word: DictionaryEntry) -> SavedWord:
    return SavedWord(
        id=saved.id,
        word=DictionaryWord.model_validate(word),
        created_at=saved.created_at,
        next_review_at=saved.next_review_at,
    )


@router.get("/dictionary", response_model=ApiResponse[list[DictionaryWord]])
def search_dictionary(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
    q: Annotated[str, Query(max_length=80)] = "",
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
) -> ApiResponse[list[DictionaryWord]]:
    # The authenticated identity is required even though catalog rows are shared.
    _ = user.id
    term = q.strip().casefold()
    statement = select(DictionaryEntry).where(DictionaryEntry.language == "en")
    if term:
        escaped = term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        statement = statement.where(
            DictionaryEntry.normalized_term.like(f"{escaped}%", escape="\\")
            | DictionaryEntry.translation.ilike(f"%{escaped}%", escape="\\")
        )
    rows = db.scalars(statement.order_by(DictionaryEntry.normalized_term).limit(limit)).all()
    return ApiResponse(data=[DictionaryWord.model_validate(row) for row in rows])


@router.get("/dictionary/{entry_id}", response_model=ApiResponse[DictionaryWord])
def get_dictionary_word(
    entry_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[DictionaryWord]:
    _ = user.id
    word = db.get(DictionaryEntry, entry_id)
    if word is None or word.language != "en":
        raise AppError(404, "word_not_found", "Word not found")
    return ApiResponse(data=DictionaryWord.model_validate(word))


@router.get("/me/vocabulary", response_model=ApiResponse[list[SavedWord]])
def list_saved_words(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[list[SavedWord]]:
    rows = db.execute(
        select(SavedVocabulary, DictionaryEntry)
        .join(DictionaryEntry, DictionaryEntry.id == SavedVocabulary.entry_id)
        .where(SavedVocabulary.user_id == user.id)
        .order_by(SavedVocabulary.created_at.desc())
        .limit(200)
    ).all()
    return ApiResponse(data=[_saved_word(saved, word) for saved, word in rows])


@router.post("/me/vocabulary/{entry_id}", response_model=ApiResponse[SavedWord])
def save_word(
    entry_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[SavedWord]:
    with db.begin():
        word = db.get(DictionaryEntry, entry_id)
        if word is None or word.language != "en":
            raise AppError(404, "word_not_found", "Word not found")
        db.execute(
            insert(SavedVocabulary)
            .values(user_id=user.id, entry_id=entry_id, note="")
            .on_conflict_do_nothing(index_elements=["user_id", "entry_id"])
        )
        saved = db.scalar(
            select(SavedVocabulary).where(
                SavedVocabulary.user_id == user.id,
                SavedVocabulary.entry_id == entry_id,
            )
        )
        assert saved is not None
        result = _saved_word(saved, word)
    return ApiResponse(data=result)


@router.delete("/me/vocabulary/{entry_id}", response_model=ApiResponse[dict[str, bool]])
def remove_saved_word(
    entry_id: UUID,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db_session)],
) -> ApiResponse[dict[str, bool]]:
    with db.begin():
        saved = db.scalar(
            select(SavedVocabulary).where(
                SavedVocabulary.user_id == user.id,
                SavedVocabulary.entry_id == entry_id,
            )
        )
        if saved is not None:
            db.delete(saved)
    return ApiResponse(data={"removed": saved is not None})
