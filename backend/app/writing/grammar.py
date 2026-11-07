"""Optional private LanguageTool HTTP provider with bounded failure behavior."""

from dataclasses import dataclass
from typing import Protocol

import httpx


@dataclass(frozen=True)
class GrammarMatch:
    message: str
    offset: int
    length: int
    replacements: tuple[str, ...]


class GrammarProvider(Protocol):
    async def check(self, text: str) -> list[GrammarMatch]: ...


class LanguageToolProvider:
    def __init__(self, origin: str) -> None:
        self.origin = origin.rstrip("/")

    async def check(self, text: str) -> list[GrammarMatch]:
        async with httpx.AsyncClient(timeout=4.0) as client:
            response = await client.post(
                f"{self.origin}/v2/check", data={"language": "en-US", "text": text}
            )
            response.raise_for_status()
            payload = response.json()
        if not isinstance(payload, dict) or not isinstance(payload.get("matches"), list):
            raise ValueError("Invalid LanguageTool response")
        result = []
        for item in payload["matches"][:20]:
            result.append(
                GrammarMatch(
                    message=str(item["message"])[:300],
                    offset=int(item["offset"]),
                    length=int(item["length"]),
                    replacements=tuple(
                        str(rep["value"])[:100] for rep in item.get("replacements", [])[:3]
                    ),
                )
            )
        return result
