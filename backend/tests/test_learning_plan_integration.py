"""Optional isolated PostgreSQL test of plan ownership and regeneration."""
# ruff: noqa: E501 -- Assertions keep full API paths and SQL visible.

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
    reason="Use a disposable migrated and seeded PostgreSQL database",
)
def test_plan_from_onboarding_regeneration_reschedule_and_isolation(monkeypatch):
    database_url = os.environ["ENGLIFY_TEST_DATABASE_URL"]
    engine = create_engine(database_url)
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
            {"iss": ISSUER, "aud": "authenticated", "sub": str(user_id),
             "role": "authenticated", "iat": now, "exp": now + timedelta(minutes=10)},
            key, algorithm="RS256", headers={"kid": "test-key"},
        )
        return {"Authorization": f"Bearer {token}"}

    try:
        with engine.begin() as connection:
            for user_id in (alice, bob):
                connection.execute(text("INSERT INTO auth.users(id, raw_user_meta_data) VALUES (:id, '{}'::jsonb)"), {"id": user_id})
        settings = Settings(_env_file=None, environment="test", database_url=database_url,
                            supabase_url="https://test.supabase.co")
        with TestClient(create_app(settings)) as client:
            assert client.get("/api/v1/learning-plan").status_code == 401
            assert client.get("/api/v1/learning-plan", headers=headers(alice)).status_code == 409
            onboarding = {"learning_goal": "travel", "initial_proficiency": "beginner",
                          "daily_goal_minutes": 20}
            assert client.put("/api/v1/me/onboarding", json=onboarding, headers=headers(alice)).status_code == 200
            first_response = client.get("/api/v1/learning-plan", headers=headers(alice))
            assert first_response.status_code == 200, first_response.text
            first = first_response.json()["data"]
            assert first["tasks"] and first["preferences"]["learning_goal"] == "travel"
            assert client.get("/api/v1/learning-plan", headers=headers(alice)).json()["data"]["id"] == first["id"]
            practice = next(task for task in first["tasks"] if task["kind"] != "lesson")
            assert client.post(f"/api/v1/learning-plan/tasks/{practice['id']}/complete", headers=headers(bob)).status_code == 404
            done = client.post(f"/api/v1/learning-plan/tasks/{practice['id']}/complete", headers=headers(alice))
            assert done.status_code == 200
            assert client.post(f"/api/v1/learning-plan/tasks/{practice['id']}/complete", headers=headers(alice)).json()["data"]["completed_count"] == done.json()["data"]["completed_count"]
            lesson = next(task for task in first["tasks"] if task["kind"] == "lesson")
            assert client.post(f"/api/v1/learning-plan/tasks/{lesson['id']}/complete", headers=headers(alice)).status_code == 409
            with engine.begin() as connection:
                connection.execute(text("INSERT INTO public.learning_progress(user_id, lesson_id, status, completed_at) VALUES (:uid, :lesson, 'completed', now())"), {"uid": alice, "lesson": lesson["lesson_id"]})
            refreshed = client.get("/api/v1/learning-plan", headers=headers(alice)).json()["data"]
            assert next(task for task in refreshed["tasks"] if task["id"] == lesson["id"])["status"] == "completed"
            with engine.begin() as connection:
                connection.execute(text("UPDATE public.learning_plan_tasks SET scheduled_on = current_date - 1 WHERE id = :id"), {"id": first["tasks"][-1]["id"]})
            moved = client.post("/api/v1/learning-plan/reschedule", headers=headers(alice)).json()["data"]
            assert next(task for task in moved["tasks"] if task["id"] == first["tasks"][-1]["id"])["scheduled_on"] >= datetime.now(UTC).date().isoformat()
            changed = client.put("/api/v1/learning-plan/preferences", headers=headers(alice), json={
                "learning_goal": "work", "initial_proficiency": "intermediate",
                "daily_goal_minutes": 30, "preferred_topics": ["business"],
            })
            assert changed.status_code == 200, changed.text
            assert changed.json()["data"]["id"] != first["id"]
            assert all(task["lesson_id"] != lesson["lesson_id"] for task in changed.json()["data"]["tasks"])
            with engine.connect() as connection:
                assert connection.execute(text("SELECT status FROM public.learning_plans WHERE id = :id"), {"id": first["id"]}).scalar_one() == "paused"
                assert connection.execute(text("SELECT count(*) FROM public.learning_plan_tasks WHERE plan_id = :id"), {"id": first["id"]}).scalar_one() == len(first["tasks"])
            with engine.begin() as connection:
                connection.execute(text("SET LOCAL ROLE authenticated"))
                connection.execute(text("SELECT set_config('request.jwt.claim.sub', :uid, true)"), {"uid": str(alice)})
                assert connection.execute(text("SELECT count(*) FROM public.learning_plan_tasks")).scalar_one() > 0
                connection.execute(text("SELECT set_config('request.jwt.claim.sub', :uid, true)"), {"uid": str(bob)})
                assert connection.execute(text("SELECT count(*) FROM public.learning_plan_tasks")).scalar_one() == 0
    finally:
        with engine.begin() as connection:
            connection.execute(text("DELETE FROM auth.users WHERE id IN (:alice, :bob)"), {"alice": alice, "bob": bob})
        engine.dispose()
