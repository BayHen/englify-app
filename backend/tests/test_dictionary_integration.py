"""Dictionary API against a disposable PostgreSQL database and the editorial seed."""

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
    reason="Set ENGLIFY_TEST_DATABASE_URL to a disposable seeded PostgreSQL database",
)
def test_dictionary_search_save_flashcard_source_and_isolation(monkeypatch) -> None:
    engine = create_engine(os.environ["ENGLIFY_TEST_DATABASE_URL"])
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
        token = jwt.encode(
            {
                "iss": ISSUER, "aud": "authenticated", "sub": str(user_id),
                "role": "authenticated", "iat": now, "exp": now + timedelta(minutes=10),
            },
            private,
            algorithm="RS256",
            headers={"kid": "test-key"},
        )
        return {"Authorization": f"Bearer {token}"}

    try:
        with engine.begin() as connection:
            for user_id in (alice, bob):
                connection.execute(text("INSERT INTO auth.users(id) VALUES (:id)"), {"id": user_id})
        app = create_app(
            Settings(
                _env_file=None, environment="test",
                database_url=os.environ["ENGLIFY_TEST_DATABASE_URL"],
                supabase_url="https://test.supabase.co",
            )
        )
        with TestClient(app) as client:
            assert client.get("/api/v1/dictionary?q=cur").status_code == 401
            found = client.get("/api/v1/dictionary?q=cur", headers=headers(alice))
            assert found.status_code == 200
            assert [word["term"] for word in found.json()["data"]] == ["curious"]
            word = found.json()["data"][0]
            assert word["definition"] and word["translation"] == "tò mò"
            assert word["ipa"] and word["part_of_speech"] and word["example"]
            assert word["source_name"] == "Englify Quest editorial"
            assert word["license_id"] == "project-owned"
            meaning_search = client.get(
                "/api/v1/dictionary?q=tò+mò", headers=headers(alice)
            ).json()["data"]
            assert meaning_search[0]["id"] == word["id"]
            detail = client.get(
                f"/api/v1/dictionary/{word['id']}", headers=headers(alice)
            ).json()["data"]
            assert detail["term"] == "curious"
            no_match = client.get(
                "/api/v1/dictionary?q=nonexistent", headers=headers(alice)
            ).json()["data"]
            assert no_match == []
            invalid = client.get("/api/v1/dictionary?limit=0", headers=headers(alice))
            assert invalid.status_code == 422
            assert client.post(f"/api/v1/me/vocabulary/{word['id']}").status_code == 401
            first = client.post(f"/api/v1/me/vocabulary/{word['id']}", headers=headers(alice))
            second = client.post(f"/api/v1/me/vocabulary/{word['id']}", headers=headers(alice))
            assert first.status_code == second.status_code == 200
            assert first.json()["data"]["id"] == second.json()["data"]["id"]
            alice_words = client.get(
                "/api/v1/me/vocabulary", headers=headers(alice)
            ).json()["data"]
            bob_words = client.get(
                "/api/v1/me/vocabulary", headers=headers(bob)
            ).json()["data"]
            assert len(alice_words) == 1
            assert bob_words == []
            bob_remove = client.delete(
                f"/api/v1/me/vocabulary/{word['id']}", headers=headers(bob)
            ).json()["data"]
            assert bob_remove == {"removed": False}
            assert len(client.get(
                "/api/v1/me/vocabulary", headers=headers(alice)
            ).json()["data"]) == 1
            alice_remove = client.delete(
                f"/api/v1/me/vocabulary/{word['id']}", headers=headers(alice)
            ).json()["data"]
            assert alice_remove == {"removed": True}
            assert client.get(
                "/api/v1/me/vocabulary", headers=headers(alice)
            ).json()["data"] == []
    finally:
        with engine.begin() as connection:
            connection.execute(
                text("DELETE FROM auth.users WHERE id IN (:alice, :bob)"),
                {"alice": alice, "bob": bob},
            )
        engine.dispose()
