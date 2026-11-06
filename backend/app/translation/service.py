"""Exact local phrase lookup and optional self-hosted full-text translation."""

from dataclasses import dataclass
from typing import Literal, Protocol

import httpx

Language = Literal["en", "vi"]
Method = Literal["phrasebook", "libretranslate"]

# Project-authored phrases. Exact matches only; these are not general translation.
PHRASES: tuple[tuple[str, str], ...] = (
    ("Hello.", "Xin chào."),
    ("Thank you.", "Cảm ơn bạn."),
    ("How are you?", "Bạn khỏe không?"),
    ("Good morning.", "Chào buổi sáng."),
    ("Where is the train station?", "Ga tàu ở đâu?"),
    ("I am learning English.", "Tôi đang học tiếng Anh."),
)


@dataclass(frozen=True)
class Translation:
    text: str
    method: Method


class TranslationProvider(Protocol):
    async def translate(
        self, text: str, source: Language, target: Language
    ) -> Translation | None: ...


def normalize_phrase(text: str) -> str:
    return text.strip().casefold().rstrip(".!? ")


class LocalTranslationProvider:
    async def translate(self, text: str, source: Language, target: Language) -> Translation | None:
        if source == target:
            return None
        index = 0 if source == "en" else 1
        for pair in PHRASES:
            if normalize_phrase(pair[index]) == normalize_phrase(text):
                return Translation(pair[1 - index], "phrasebook")
        return None


class LibreTranslateProvider:
    def __init__(
        self, url: str, verified_pairs: set[tuple[Language, Language]], timeout: float = 5.0
    ):
        self.url = url.rstrip("/")
        self.verified_pairs = verified_pairs
        self.timeout = timeout

    async def translate(self, text: str, source: Language, target: Language) -> Translation | None:
        if (source, target) not in self.verified_pairs:
            return None
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                languages = (await client.get(f"{self.url}/languages")).raise_for_status().json()
                if not isinstance(languages, list) or not any(
                    isinstance(item, dict)
                    and item.get("code") == source
                    and isinstance(item.get("targets"), list)
                    and target in item["targets"]
                    for item in languages
                ):
                    return None
                response = (
                    (
                        await client.post(
                            f"{self.url}/translate",
                            json={"q": text, "source": source, "target": target, "format": "text"},
                        )
                    )
                    .raise_for_status()
                    .json()
                )
            translated = response.get("translatedText") if isinstance(response, dict) else None
            if not isinstance(translated, str) or not translated.strip():
                return None
            return Translation(translated.strip(), "libretranslate")
        except (httpx.HTTPError, ValueError, TypeError):
            return None


class TranslationService:
    def __init__(self, remote: LibreTranslateProvider | None = None):
        self.local = LocalTranslationProvider()
        self.remote = remote

    async def translate(self, text: str, source: Language, target: Language) -> Translation | None:
        local = await self.local.translate(text, source, target)
        if local is not None:
            return local
        if self.remote is not None:
            return await self.remote.translate(text, source, target)
        return None
