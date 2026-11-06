"""Authenticated translation API; unavailable is a valid, explicit result."""

from typing import Annotated, Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field, model_validator

from app.core.auth import CurrentUser, get_current_user
from app.core.config import Settings
from app.core.responses import ApiResponse
from app.db.session import get_settings
from app.translation.service import PHRASES, Language, LibreTranslateProvider, TranslationService

router = APIRouter(prefix="/api/v1", tags=["translation"])


class TranslateRequest(BaseModel):
    source: Language
    target: Language
    text: str = Field(min_length=1, max_length=500)

    @model_validator(mode="after")
    def validate_pair(self) -> "TranslateRequest":
        if self.source == self.target or not self.text.strip():
            raise ValueError("Choose two different languages and enter text")
        return self


class TranslateResult(BaseModel):
    status: Literal["translated", "unavailable"]
    source: Language
    target: Language
    source_text: str
    translated_text: str | None
    method: Literal["phrasebook", "libretranslate"] | None
    scope: Literal["exact_phrase", "full_text"] | None
    message: str


@router.post("/translate", response_model=ApiResponse[TranslateResult])
async def translate(
    request: TranslateRequest,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> ApiResponse[TranslateResult]:
    _ = user.id
    verified: set[tuple[Language, Language]] = set()
    for pair in settings.libretranslate_verified_pairs.split(","):
        parts = pair.strip().split(":")
        if (
            len(parts) == 2
            and parts[0] in {"en", "vi"}
            and parts[1] in {"en", "vi"}
            and parts[0] != parts[1]
        ):
            verified.add((parts[0], parts[1]))  # type: ignore[arg-type]
    remote = (
        LibreTranslateProvider(settings.libretranslate_url, verified)
        if settings.libretranslate_url
        else None
    )
    result = await TranslationService(remote).translate(
        request.text.strip(), request.source, request.target
    )
    return ApiResponse(
        data=TranslateResult(
            status="translated" if result else "unavailable",
            source=request.source,
            target=request.target,
            source_text=request.text.strip(),
            translated_text=result.text if result else None,
            method=result.method if result else None,
            scope=("exact_phrase" if result.method == "phrasebook" else "full_text")
            if result
            else None,
            message=(
                "Exact match in the curated phrasebook; not full-text translation"
                if result and result.method == "phrasebook"
                else "Self-hosted LibreTranslate output; review before using"
                if result
                else "No exact phrase match or verified translation provider is available"
            ),
        )
    )


@router.get("/translation/phrases", response_model=ApiResponse[list[dict[str, str]]])
def list_phrases(
    user: Annotated[CurrentUser, Depends(get_current_user)],
) -> ApiResponse[list[dict[str, str]]]:
    _ = user.id
    return ApiResponse(data=[{"en": en, "vi": vi} for en, vi in PHRASES])
