"""Run against an isolated migrated PostgreSQL database when configured."""

import os
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text

from app.core import auth
from app.core.config import Settings
from app.main import create_app

ISSUER = "https://test.supabase.co/auth/v1"


@pytest.mark.skipif(
    not os.getenv("ENGLIFY_TEST_DATABASE_URL"),
    reason="Set ENGLIFY_TEST_DATABASE_URL to a disposable migrated PostgreSQL database",
)
def test_authenticated_profile_onboarding_and_isolation(monkeypatch) -> None:
    database_url = os.environ["ENGLIFY_TEST_DATABASE_URL"]
    engine = create_engine(database_url)
    alice, bob = uuid4(), uuid4()
    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    monkeypatch.setitem(
        auth._jwks_clients,
        ISSUER,
        SimpleNamespace(
            get_signing_key_from_jwt=lambda _token: SimpleNamespace(key=private.public_key())
        ),
    )

    def headers(user_id):
        now = datetime.now(UTC)
        access_token = jwt.encode(
            {
                "iss": ISSUER, "aud": "authenticated", "sub": str(user_id),
                "role": "authenticated", "iat": now, "exp": now + timedelta(minutes=10),
            },
            private,
            algorithm="RS256",
            headers={"kid": "test-key"},
        )
        return {"Authorization": f"Bearer {access_token}"}

    try:
        with engine.begin() as connection:
            for user_id, name in ((alice, "Alice"), (bob, "Bob")):
                connection.execute(
                    text("INSERT INTO auth.users(id, raw_user_meta_data) "
                         "VALUES (:id, jsonb_build_object('display_name', CAST(:name AS text)))"),
                    {"id": user_id, "name": name},
                )
        settings = Settings(
            _env_file=None, environment="test", database_url=database_url,
            supabase_url="https://test.supabase.co",
        )
        with TestClient(create_app(settings)) as client:
            assert client.get("/api/v1/me").status_code == 401
            assert client.put(
                "/api/v1/me/onboarding",
                json={
                    "learning_goal": "travel", "initial_proficiency": "beginner",
                    "daily_goal_minutes": 10,
                },
            ).status_code == 401
            a = client.get("/api/v1/me", headers=headers(alice))
            b = client.get("/api/v1/me", headers=headers(bob))
            assert a.status_code == b.status_code == 200
            assert a.json()["data"]["display_name"] == "Alice"
            assert b.json()["data"]["display_name"] == "Bob"
            assert a.json()["data"]["preferences"] is None
            saved = client.put(
                "/api/v1/me/onboarding",
                headers=headers(alice),
                json={
                    "learning_goal": "conversation",
                    "initial_proficiency": "beginner",
                    "daily_goal_minutes": 15,
                },
            )
            assert saved.status_code == 200
            assert saved.json()["data"]["preferences"]["onboarding_completed_at"]
            bob_profile = client.get("/api/v1/me", headers=headers(bob)).json()["data"]
            alice_profile = client.get("/api/v1/me", headers=headers(alice)).json()["data"]
            assert bob_profile["preferences"] is None
            assert alice_profile["preferences"]["learning_goal"] == "conversation"
            changed = client.patch(
                "/api/v1/me/profile", headers=headers(alice), json={"display_name": "Alicia"}
            )
            assert changed.status_code == 200
            assert changed.json()["data"]["display_name"] == "Alicia"
            detailed = client.patch(
                "/api/v1/me/profile", headers=headers(alice),
                json={"username": "Alice_01", "bio": "Hello\nworld"},
            )
            assert detailed.status_code == 200
            assert detailed.json()["data"]["username"] == "alice_01"
            assert detailed.json()["data"]["bio"] == "Hello\nworld"
            assert client.patch(
                "/api/v1/me/profile", headers=headers(bob),
                json={"username": "ALICE_01"},
            ).status_code == 409
            assert client.patch(
                "/api/v1/me/profile", headers=headers(alice),
                json={"avatar_url": f"{bob}/wrong.jpg"},
            ).status_code == 422
            assert client.patch(
                "/api/v1/me/profile", json={"bio": "Unauthenticated"},
            ).status_code == 401
            preferences = client.patch(
                "/api/v1/me/preferences", headers=headers(alice),
                json={"learning_goal": "real_english", "current_cefr": "B2",
                      "daily_goal_minutes": 20, "preferred_accent": "en-GB",
                      "interface_language": "vi"},
            )
            assert preferences.status_code == 200
            assert (
                preferences.json()["data"]["preferences"]["initial_proficiency"]
                == "intermediate"
            )
            assert client.patch(
                "/api/v1/me/preferences", headers=headers(alice),
                json={"total_xp": 999},
            ).status_code == 422
            bob_profile = client.get("/api/v1/me", headers=headers(bob)).json()["data"]
            assert bob_profile["display_name"] == "Bob"
            cross_user = client.put(
                "/api/v1/me/onboarding", headers=headers(alice),
                json={
                    "learning_goal": "travel", "initial_proficiency": "advanced",
                    "daily_goal_minutes": 10, "user_id": str(bob),
                },
            )
            assert cross_user.status_code == 422
            assert client.patch(
                "/api/v1/me/profile", headers=headers(alice),
                json={"display_name": "Mallory", "id": str(bob)},
            ).status_code == 422
            assert client.put(
                "/api/v1/me/onboarding", headers=headers(alice),
                json={
                    "learning_goal": "travel", "initial_proficiency": "advanced",
                    "daily_goal_minutes": 0,
                },
            ).status_code == 422
    finally:
        with engine.begin() as connection:
            connection.execute(text("DELETE FROM auth.users WHERE id IN (:alice, :bob)"),
                               {"alice": alice, "bob": bob})
        engine.dispose()
