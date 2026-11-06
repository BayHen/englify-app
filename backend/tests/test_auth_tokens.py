"""JWT acceptance rules independent of a live Supabase project."""

from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient

from app.core import auth
from app.core.config import Settings
from app.core.responses import AppError
from app.main import create_app

ISSUER = "https://test.supabase.co/auth/v1"


@pytest.fixture
def signing_key(monkeypatch):
    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    fake_client = SimpleNamespace(
        get_signing_key_from_jwt=lambda _token: SimpleNamespace(key=private.public_key())
    )
    monkeypatch.setitem(auth._jwks_clients, ISSUER, fake_client)
    return private


def token(private, **overrides) -> str:
    now = datetime.now(UTC)
    claims = {
        "iss": ISSUER,
        "aud": "authenticated",
        "sub": str(uuid4()),
        "role": "authenticated",
        "iat": now,
        "exp": now + timedelta(minutes=10),
    }
    claims.update(overrides)
    return jwt.encode(claims, private, algorithm="RS256", headers={"kid": "test-key"})


def test_private_endpoint_rejects_missing_and_invalid_tokens(signing_key) -> None:
    settings = Settings(_env_file=None, environment="test", supabase_url="https://test.supabase.co")
    with TestClient(create_app(settings)) as client:
        missing = client.get("/api/v1/me")
        assert missing.status_code == 401
        assert missing.json()["error"]["code"] == "authentication_required"
        cases = [
            token(signing_key, exp=datetime.now(UTC) - timedelta(minutes=1)),
            token(signing_key, iss="https://evil.example/auth/v1"),
            token(signing_key, aud="other"),
            token(signing_key, role="service_role"),
            token(signing_key, sub="not-a-uuid"),
            token(signing_key) + "broken",
        ]
        for value in cases:
            response = client.get("/api/v1/me", headers={"Authorization": f"Bearer {value}"})
            assert response.status_code == 401
            assert response.json()["error"]["code"] == "invalid_token"


def test_valid_token_requires_database_and_never_uses_unverified_subject(signing_key) -> None:
    settings = Settings(_env_file=None, environment="test", supabase_url="https://test.supabase.co")
    current = auth.verify_access_token(token(signing_key), settings)
    assert current.id
    with TestClient(create_app(settings)) as client:
        response = client.get(
            "/api/v1/me", headers={"Authorization": f"Bearer {token(signing_key)}"}
        )
        assert response.status_code == 503
        assert response.json()["error"]["code"] == "database_not_configured"


def test_auth_configuration_is_required(signing_key) -> None:
    with pytest.raises(AppError) as error:
        auth.verify_access_token(token(signing_key), Settings(_env_file=None, environment="test"))
    assert error.value.status_code == 503


def test_legacy_hs256_uses_auth_server_and_checks_identity(monkeypatch) -> None:
    secret = "test-only-legacy-secret-long-enough-for-hs256"
    now = datetime.now(UTC)
    user_id = str(uuid4())
    legacy = jwt.encode(
        {
            "iss": ISSUER,
            "aud": "authenticated",
            "sub": user_id,
            "role": "authenticated",
            "iat": now,
            "exp": now + timedelta(minutes=10),
        },
        secret,
        algorithm="HS256",
    )
    settings = Settings(
        _env_file=None,
        environment="test",
        supabase_url="https://test.supabase.co",
        supabase_publishable_key="sb_publishable_test_only",
    )

    def fake_get(self, url, **kwargs):
        assert url == f"{ISSUER}/user"
        assert kwargs["headers"]["Authorization"] == f"Bearer {legacy}"
        return httpx.Response(200, json={"id": user_id}, request=httpx.Request("GET", url))

    monkeypatch.setattr(httpx.Client, "get", fake_get)
    assert str(auth.verify_access_token(legacy, settings).id) == user_id

    def other_user(self, url, **kwargs):
        return httpx.Response(200, json={"id": str(uuid4())}, request=httpx.Request("GET", url))

    monkeypatch.setattr(httpx.Client, "get", other_user)
    with pytest.raises(AppError) as error:
        auth.verify_access_token(legacy, settings)
    assert error.value.status_code == 401
