"""Real English catalog, private saves, quiz grading, and RLS isolation."""
# ruff: noqa: E501 -- Full API paths are intentional in integration assertions.

import os
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.exc import ProgrammingError

from app.core import auth
from app.core.config import Settings
from app.main import create_app

ISSUER = "https://test.supabase.co/auth/v1"


@pytest.mark.skipif(
    not os.getenv("ENGLIFY_TEST_DATABASE_URL"),
    reason="Use disposable migrated and seeded PostgreSQL",
)
def test_real_english_search_save_quiz_and_isolation(monkeypatch):
    url = os.environ["ENGLIFY_TEST_DATABASE_URL"]
    engine = create_engine(url)
    alice, bob = uuid4(), uuid4()
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    monkeypatch.setitem(
        auth._jwks_clients,
        ISSUER,
        SimpleNamespace(get_signing_key_from_jwt=lambda _: SimpleNamespace(key=key.public_key())),
    )

    def headers(user_id):
        now = datetime.now(UTC)
        token = jwt.encode(
            {
                "iss": ISSUER,
                "aud": "authenticated",
                "sub": str(user_id),
                "role": "authenticated",
                "iat": now,
                "exp": now + timedelta(minutes=10),
            },
            key,
            algorithm="RS256",
            headers={"kid": "test-key"},
        )
        return {"Authorization": f"Bearer {token}"}

    try:
        with engine.begin() as connection:
            for user_id in (alice, bob):
                connection.execute(
                    text(
                        "INSERT INTO auth.users(id, raw_user_meta_data) VALUES (:id, '{}'::jsonb)"
                    ),
                    {"id": user_id},
                )
        settings = Settings(
            _env_file=None,
            environment="test",
            database_url=url,
            supabase_url="https://test.supabase.co",
        )
        with TestClient(create_app(settings)) as client:
            assert client.get("/api/v1/real-english").status_code == 401
            listed = client.get("/api/v1/real-english", headers=headers(alice))
            assert listed.status_code == 200, listed.text
            assert len(listed.json()["data"]) >= 6
            assert {item["kind"] for item in listed.json()["data"]} >= {
                "slang",
                "idiom",
                "phrasal_verb",
                "casual_expression",
                "everyday_conversation",
                "movie_style_dialogue",
            }
            search = client.get(
                "/api/v1/real-english", params={"q": "không có gì"}, headers=headers(alice)
            )
            assert any(item["slug"] == "no-biggie" for item in search.json()["data"])
            assert (
                client.get(
                    "/api/v1/real-english", params={"q": "%"}, headers=headers(alice)
                ).json()["data"]
                == []
            )
            expression_id = next(
                item["id"] for item in listed.json()["data"] if item["slug"] == "no-biggie"
            )
            saved = client.post(
                f"/api/v1/real-english/{expression_id}/save", headers=headers(alice)
            )
            assert saved.status_code == 200 and saved.json()["data"]["saved"]
            assert (
                len(
                    client.get(
                        "/api/v1/real-english",
                        params={"saved_only": "true"},
                        headers=headers(alice),
                    ).json()["data"]
                )
                == 1
            )
            assert (
                client.get(
                    "/api/v1/real-english", params={"saved_only": "true"}, headers=headers(bob)
                ).json()["data"]
                == []
            )
            question = client.get(
                f"/api/v1/real-english/{expression_id}/quiz", headers=headers(alice)
            ).json()["data"]
            assert "answer_id" not in question and len(question["options"]) == 3
            request_id = str(uuid4())
            payload = {"request_id": request_id, "selected_option": "b"}
            result = client.post(
                f"/api/v1/real-english/{expression_id}/quiz", headers=headers(alice), json=payload
            )
            assert result.status_code == 200 and not result.json()["data"]["is_correct"]
            repeat = client.post(
                f"/api/v1/real-english/{expression_id}/quiz", headers=headers(alice), json=payload
            )
            assert repeat.json()["data"]["attempt_id"] == result.json()["data"]["attempt_id"]
            changed_answer = client.post(
                f"/api/v1/real-english/{expression_id}/quiz",
                headers=headers(alice),
                json={"request_id": request_id, "selected_option": "a"},
            )
            assert changed_answer.status_code == 409
            correct = client.post(
                f"/api/v1/real-english/{expression_id}/quiz",
                headers=headers(alice),
                json={"request_id": str(uuid4()), "selected_option": "a"},
            )
            assert correct.status_code == 200 and correct.json()["data"]["is_correct"]
            invalid = client.post(
                f"/api/v1/real-english/{expression_id}/quiz",
                headers=headers(alice),
                json={"request_id": str(uuid4()), "selected_option": "not-an-option"},
            )
            assert invalid.status_code == 422
            with engine.begin() as connection:
                connection.execute(text("SET LOCAL ROLE authenticated"))
                connection.execute(
                    text("SELECT set_config('request.jwt.claim.sub', :uid, true)"),
                    {"uid": str(alice)},
                )
                assert (
                    connection.execute(
                        text("SELECT count(*) FROM public.saved_expressions")
                    ).scalar_one()
                    == 1
                )
                connection.execute(
                    text("SELECT set_config('request.jwt.claim.sub', :uid, true)"),
                    {"uid": str(bob)},
                )
                assert (
                    connection.execute(
                        text("SELECT count(*) FROM public.saved_expressions")
                    ).scalar_one()
                    == 0
                )
                assert (
                    connection.execute(
                        text("SELECT count(*) FROM public.real_english_quiz_attempts")
                    ).scalar_one()
                    == 0
                )
                with pytest.raises(ProgrammingError):
                    connection.execute(
                        text("SELECT answer_id FROM public.real_english_quiz_questions")
                    ).all()
            removed = client.delete(
                f"/api/v1/real-english/{expression_id}/save", headers=headers(alice)
            )
            assert removed.status_code == 200 and not removed.json()["data"]["saved"]
    finally:
        with engine.begin() as connection:
            connection.execute(
                text("DELETE FROM auth.users WHERE id IN (:alice, :bob)"),
                {"alice": alice, "bob": bob},
            )
        engine.dispose()
