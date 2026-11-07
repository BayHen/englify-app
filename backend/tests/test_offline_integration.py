"""Offline package versioning and server-authoritative replay validation."""

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
FIRST = "33333333-3333-4333-8333-333333333301"
LOCKED = "33333333-3333-4333-8333-333333333302"


@pytest.mark.skipif(
    not os.getenv("ENGLIFY_TEST_DATABASE_URL"), reason="Use disposable migrated PostgreSQL"
)
def test_offline_download_sync_replay_version_conflict_and_xp(monkeypatch) -> None:
    url = os.environ["ENGLIFY_TEST_DATABASE_URL"]
    engine = create_engine(url)
    user_id = uuid4()
    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    monkeypatch.setitem(
        auth._jwks_clients,
        ISSUER,
        SimpleNamespace(
            get_signing_key_from_jwt=lambda _: SimpleNamespace(key=private.public_key())
        ),
    )

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
        headers={"kid": "offline-test"},
    )
    headers = {"Authorization": f"Bearer {token}"}
    with engine.begin() as connection:
        connection.execute(
            text("INSERT INTO auth.users(id,raw_user_meta_data) VALUES (:id,'{}'::jsonb)"),
            {"id": user_id},
        )
        original = connection.execute(
            text("SELECT objective FROM public.lessons WHERE id=:id"), {"id": FIRST}
        ).scalar_one()
    try:
        settings = Settings(
            _env_file=None,
            environment="test",
            database_url=url,
            supabase_url="https://test.supabase.co",
        )
        with TestClient(create_app(settings)) as client:
            base = f"/api/v1/lessons/{FIRST}"
            assert client.get(f"{base}/offline-package").status_code == 401
            assert (
                client.get(f"/api/v1/lessons/{LOCKED}/offline-package", headers=headers).status_code
                == 403
            )
            downloaded = client.get(f"{base}/offline-package", headers=headers)
            assert downloaded.status_code == 200, downloaded.text
            package = downloaded.json()["data"]
            assert len(package["content_version"]) == 64
            question = package["lesson"]["questions"][0]
            correct = next(
                option["id"]
                for option in question["options"]
                if option["text"] == "How is it going?"
            )
            event = {
                "request_id": str(uuid4()),
                "content_version": package["content_version"],
                "answers": {question["id"]: correct},
            }
            assert (
                client.post(
                    f"{base}/offline-sync", headers=headers, json={**event, "content_version": "x"}
                ).status_code
                == 422
            )
            result = client.post(f"{base}/offline-sync", headers=headers, json=event)
            assert result.status_code == 200, result.text
            first = result.json()["data"]
            assert first["passed"] and first["earned_xp"] > 0
            replay = client.post(f"{base}/offline-sync", headers=headers, json=event)
            assert (
                replay.status_code == 200
                and replay.json()["data"]["attempt_id"] == first["attempt_id"]
            )
            with engine.connect() as connection:
                assert (
                    connection.execute(
                        text("SELECT count(*) FROM public.lesson_attempts WHERE user_id=:uid"),
                        {"uid": user_id},
                    ).scalar_one()
                    == 1
                )
                xp_before = connection.execute(
                    text("SELECT count(*) FROM public.xp_events WHERE user_id=:uid"),
                    {"uid": user_id},
                ).scalar_one()
            with engine.begin() as connection:
                connection.execute(
                    text("UPDATE public.lessons SET objective=:objective WHERE id=:id"),
                    {"objective": "Temporarily changed for offline version test", "id": FIRST},
                )
            newer = client.get(f"{base}/offline-package", headers=headers).json()["data"]
            assert newer["content_version"] != package["content_version"]
            stale = client.post(
                f"{base}/offline-sync", headers=headers, json={**event, "request_id": str(uuid4())}
            )
            assert (
                stale.status_code == 409
                and stale.json()["error"]["code"] == "offline_content_changed"
            )
            with engine.connect() as connection:
                assert (
                    connection.execute(
                        text("SELECT count(*) FROM public.xp_events WHERE user_id=:uid"),
                        {"uid": user_id},
                    ).scalar_one()
                    == xp_before
                )
    finally:
        with engine.begin() as connection:
            connection.execute(
                text("UPDATE public.lessons SET objective=:objective WHERE id=:id"),
                {"objective": original, "id": FIRST},
            )
            connection.execute(text("DELETE FROM auth.users WHERE id=:uid"), {"uid": user_id})
        engine.dispose()
