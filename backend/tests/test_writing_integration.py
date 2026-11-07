"""Optional writing integration on a disposable migrated PostgreSQL database."""
# ruff: noqa: E501 -- API assertions stay explicit.

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
from app.writing import grammar
from app.writing.grammar import GrammarMatch

ISSUER = "https://test.supabase.co/auth/v1"


@pytest.mark.skipif(
    not os.getenv("ENGLIFY_TEST_DATABASE_URL"),
    reason="Use disposable migrated and seeded PostgreSQL",
)
def test_writing_history_feedback_idempotency_and_isolation(monkeypatch) -> None:
    url = os.environ["ENGLIFY_TEST_DATABASE_URL"]
    engine = create_engine(url)
    alice, bob = uuid4(), uuid4()
    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    monkeypatch.setitem(
        auth._jwks_clients,
        ISSUER,
        SimpleNamespace(
            get_signing_key_from_jwt=lambda _: SimpleNamespace(key=private.public_key())
        ),
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
            private,
            algorithm="RS256",
            headers={"kid": "test-key"},
        )
        return {"Authorization": f"Bearer {token}"}

    async def unavailable(_self, _body):
        raise TimeoutError("local provider unavailable")

    async def available(_self, _body):
        return [GrammarMatch("Consider an article here.", 0, 1, ("The",))]

    try:
        with engine.begin() as connection:
            for user_id in (alice, bob):
                connection.execute(
                    text("INSERT INTO auth.users(id,raw_user_meta_data) VALUES (:id,'{}'::jsonb)"),
                    {"id": user_id},
                )
        settings = Settings(
            _env_file=None,
            environment="test",
            database_url=url,
            supabase_url="https://test.supabase.co",
            languagetool_url="http://127.0.0.1:8082",
        )
        with TestClient(create_app(settings)) as client:
            assert client.get("/api/v1/writing/exercises").status_code == 401
            exercises = client.get("/api/v1/writing/exercises", headers=headers(alice)).json()[
                "data"
            ]
            assert {item["kind"] for item in exercises} == {
                "sentence",
                "fill_blank",
                "sentence_order",
                "paragraph",
            }
            exercise = next(item for item in exercises if item["kind"] == "fill_blank")
            payload = {
                "request_id": str(uuid4()),
                "exercise_id": exercise["id"],
                "body": "station",
                "grammar_check": True,
            }
            monkeypatch.setattr(grammar.LanguageToolProvider, "check", unavailable)
            first = client.post("/api/v1/writing/submit", json=payload, headers=headers(alice))
            assert first.status_code == 200, first.text
            data = first.json()["data"]
            assert data["body"] == "station" and data["feedback"]["rule_result"] == "matched"
            assert data["feedback"]["grammar_status"] == "unavailable"
            repeat = client.post("/api/v1/writing/submit", json=payload, headers=headers(alice))
            assert repeat.json()["data"]["id"] == data["id"]
            conflict = client.post(
                "/api/v1/writing/submit",
                json={**payload, "body": "airport"},
                headers=headers(alice),
            )
            assert conflict.status_code == 409
            assert client.get("/api/v1/writing/history", headers=headers(bob)).json()["data"] == []
            assert (
                client.get(
                    f"/api/v1/writing/history/{data['id']}", headers=headers(bob)
                ).status_code
                == 404
            )
            assert (
                len(client.get("/api/v1/writing/history", headers=headers(alice)).json()["data"])
                == 1
            )
            monkeypatch.setattr(grammar.LanguageToolProvider, "check", available)
            paragraph = next(item for item in exercises if item["kind"] == "paragraph")
            second = client.post(
                "/api/v1/writing/submit",
                headers=headers(alice),
                json={
                    "request_id": str(uuid4()),
                    "exercise_id": paragraph["id"],
                    "body": "I enjoy visiting the park near my house. It is quiet. I go there on weekends.",
                    "grammar_check": True,
                },
            )
            assert second.status_code == 200, second.text
            assert second.json()["data"]["feedback"]["rule_result"] == "self_review"
            assert second.json()["data"]["feedback"]["grammar_status"] == "available"
            assert second.json()["data"]["feedback"]["grammar_matches"][0]["replacements"] == [
                "The"
            ]
            with engine.connect() as connection:
                assert (
                    connection.execute(
                        text("SELECT body FROM public.writing_submissions WHERE id=:id"),
                        {"id": data["id"]},
                    ).scalar_one()
                    == "station"
                )
                assert (
                    connection.execute(
                        text(
                            "SELECT grammar_status FROM public.writing_feedback WHERE submission_id=:id"
                        ),
                        {"id": data["id"]},
                    ).scalar_one()
                    == "unavailable"
                )
            with engine.begin() as connection:
                connection.execute(text("SET LOCAL ROLE authenticated"))
                connection.execute(
                    text("SELECT set_config('request.jwt.claim.sub', :uid, true)"),
                    {"uid": str(bob)},
                )
                assert connection.execute(text("SELECT count(*) FROM public.writing_feedback")).scalar_one() == 0
                assert connection.execute(text("SELECT count(*) FROM public.writing_submissions")).scalar_one() == 0
            with engine.begin() as connection:
                connection.execute(text("SET LOCAL ROLE authenticated"))
                connection.execute(
                    text("SELECT set_config('request.jwt.claim.sub', :uid, true)"),
                    {"uid": str(alice)},
                )
                assert connection.execute(text("SELECT count(*) FROM public.writing_feedback")).scalar_one() == 2
                assert connection.execute(text("SELECT has_table_privilege('authenticated', 'public.writing_answer_keys', 'SELECT')")).scalar_one() is False
    finally:
        with engine.begin() as connection:
            connection.execute(
                text("DELETE FROM auth.users WHERE id IN (:alice,:bob)"),
                {"alice": alice, "bob": bob},
            )
        engine.dispose()
