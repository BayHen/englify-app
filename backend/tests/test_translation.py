"""Free translation must be exact or explicitly unavailable."""

import asyncio
from uuid import uuid4

import httpx
from fastapi.testclient import TestClient

from app.core.auth import CurrentUser, get_current_user
from app.core.config import Settings
from app.main import create_app
from app.translation.service import LibreTranslateProvider, TranslationService


def test_phrasebook_directions_and_no_fabrication():
    service = TranslationService()
    en_vi = asyncio.run(service.translate("hello!", "en", "vi"))
    vi_en = asyncio.run(service.translate("xin chào", "vi", "en"))
    unknown = asyncio.run(service.translate("The weather changes quickly today.", "en", "vi"))
    assert en_vi and en_vi.text == "Xin chào." and en_vi.method == "phrasebook"
    assert vi_en and vi_en.text == "Hello."
    assert unknown is None


def test_libre_requires_verified_pair_and_advertised_target(monkeypatch):
    calls = []

    async def fake_get(self, url):
        calls.append(url)
        return httpx.Response(
            200, json=[{"code": "en", "targets": ["fr"]}], request=httpx.Request("GET", url)
        )

    monkeypatch.setattr(httpx.AsyncClient, "get", fake_get)
    provider = LibreTranslateProvider("http://localhost:5000", {("en", "vi")})
    assert asyncio.run(provider.translate("A new sentence", "en", "vi")) is None
    assert len(calls) == 1
    assert asyncio.run(provider.translate("Xin chào", "vi", "en")) is None
    assert len(calls) == 1


def test_libre_timeout_returns_unavailable(monkeypatch):
    async def timeout(self, url):
        raise httpx.ReadTimeout("timed out")

    monkeypatch.setattr(httpx.AsyncClient, "get", timeout)
    provider = LibreTranslateProvider("http://localhost:5000", {("en", "vi")})
    assert asyncio.run(provider.translate("A new sentence", "en", "vi")) is None


def test_libre_uses_advertised_verified_pair(monkeypatch):
    async def fake_get(self, url):
        return httpx.Response(
            200,
            json=[{"code": "en", "targets": ["vi"]}],
            request=httpx.Request("GET", url),
        )

    async def fake_post(self, url, **kwargs):
        assert kwargs["json"]["source"] == "en"
        assert kwargs["json"]["target"] == "vi"
        return httpx.Response(
            200,
            json={"translatedText": "Một câu mới."},
            request=httpx.Request("POST", url),
        )

    monkeypatch.setattr(httpx.AsyncClient, "get", fake_get)
    monkeypatch.setattr(httpx.AsyncClient, "post", fake_post)
    provider = LibreTranslateProvider("http://localhost:5000", {("en", "vi")})
    result = asyncio.run(provider.translate("A new sentence.", "en", "vi"))
    assert result and result.method == "libretranslate" and result.text == "Một câu mới."


def test_api_typed_result_and_auth():
    app = create_app(Settings(environment="test"))
    with TestClient(app) as client:
        assert (
            client.post(
                "/api/v1/translate", json={"source": "en", "target": "vi", "text": "Hello."}
            ).status_code
            == 401
        )
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(id=uuid4())
        found = client.post(
            "/api/v1/translate", json={"source": "en", "target": "vi", "text": "Hello."}
        )
        assert found.status_code == 200
        assert found.json()["data"]["scope"] == "exact_phrase"
        missing = client.post(
            "/api/v1/translate",
            json={"source": "en", "target": "vi", "text": "An unknown sentence."},
        )
        assert missing.json()["data"]["status"] == "unavailable"
        assert missing.json()["data"]["translated_text"] is None
