"""Learning rules and optional full-unit PostgreSQL integration."""

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
from app.gamification.service import level_for_xp, period_bounds
from app.learning.grading import is_correct, passes
from app.main import create_app

ISSUER = "https://test.supabase.co/auth/v1"


def test_deterministic_grading() -> None:
    assert is_correct("multiple_choice", "option-1", "option-1")
    assert not is_correct("multiple_choice", "option-2", "option-1")
    assert is_correct("fill_blank", "  ARE!  ", ["are"])
    assert is_correct("grammar", "she is happy", ["She is happy."])
    assert is_correct("listening", "good morning", ["Good morning"])
    assert is_correct("matching", {"station": "trains"}, {"station": "trains"})
    assert not is_correct("matching", {"station": "books"}, {"station": "trains"})
    assert passes(7, 10) and not passes(6, 10)


def test_level_and_quest_windows() -> None:
    assert [level_for_xp(xp, 100) for xp in (0, 99, 100, 250)] == [1, 1, 2, 3]
    boundary = datetime(2026, 11, 1, 23, 59, tzinfo=UTC)
    assert period_bounds("daily", boundary)[0].isoformat() == "2026-11-01"
    assert period_bounds("weekly", boundary)[0].isoformat() == "2026-10-26"


@pytest.mark.skipif(
    not os.getenv("ENGLIFY_TEST_DATABASE_URL"),
    reason="Set ENGLIFY_TEST_DATABASE_URL to a disposable migrated and seeded database",
)
def test_complete_unit_unlock_idempotency_replay_and_isolation(monkeypatch) -> None:
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

    def answers_for(detail):
        result = {}
        for question in detail["questions"]:
            kind = question["kind"]
            if kind == "multiple_choice":
                result[question["id"]] = next(
                    option["id"]
                    for option in question["options"]
                    if option["text"] in {"How is it going?", "Good morning!"}
                )
            elif kind == "fill_blank":
                result[question["id"]] = "are"
            elif kind == "grammar":
                result[question["id"]] = "She is happy."
            elif kind == "matching":
                result[question["id"]] = {"station": "trains", "library": "books"}
            else:
                result[question["id"]] = "Good morning"
        return result

    try:
        with engine.begin() as connection:
            for user_id in (alice, bob):
                connection.execute(text("INSERT INTO auth.users(id) VALUES (:id)"), {"id": user_id})
        app = create_app(
            Settings(
                _env_file=None,
                environment="test",
                database_url=database_url,
                supabase_url="https://test.supabase.co",
            )
        )
        with TestClient(app) as client:
            assert client.get("/api/v1/journey").status_code == 401
            journey = client.get("/api/v1/journey", headers=headers(alice)).json()["data"]
            lessons = journey[0]["units"][0]["lessons"]
            assert len(lessons) == 4
            assert [item["state"] for item in lessons] == [
                "available",
                "locked",
                "locked",
                "locked",
            ]
            assert (
                client.get(
                    f"/api/v1/lessons/{lessons[1]['id']}", headers=headers(alice)
                ).status_code
                == 403
            )
            locked_path = f"/api/v1/lessons/{lessons[1]['id']}"
            assert client.post(f"{locked_path}/start", headers=headers(alice)).status_code == 403
            assert (
                client.post(
                    f"{locked_path}/submit",
                    headers=headers(alice),
                    json={"request_id": str(uuid4()), "answers": {str(uuid4()): "are"}},
                ).status_code
                == 403
            )
            first_request_id = None
            reward_id = "77777777-7777-4777-8777-777777777701"
            for index, lesson in enumerate(lessons):
                path = f"/api/v1/lessons/{lesson['id']}"
                detail_response = client.get(path, headers=headers(alice))
                assert detail_response.status_code == 200
                detail = detail_response.json()["data"]
                assert client.post(f"{path}/start", headers=headers(alice)).status_code == 200
                request = {"request_id": str(uuid4()), "answers": answers_for(detail)}
                if index == 0:
                    first_request_id = request["request_id"]
                first = client.post(f"{path}/submit", headers=headers(alice), json=request)
                duplicate = client.post(f"{path}/submit", headers=headers(alice), json=request)
                assert first.status_code == duplicate.status_code == 200
                assert first.json()["data"] == duplicate.json()["data"]
                assert first.json()["data"]["passed"]
                if index == 0:
                    assert {r["kind"] for r in first.json()["data"]["rewards"]} == {
                        "xp",
                        "quest",
                        "badge",
                    }
                    assert (
                        client.post(
                            f"/api/v1/gamification/rewards/{reward_id}/claim",
                            headers=headers(alice),
                        ).status_code
                        == 403
                    )
                assert client.get("/api/v1/journey", headers=headers(bob)).json()["data"][0][
                    "units"
                ][0]["lessons"][index]["state"] == ("available" if index == 0 else "locked")
            all_done = client.get("/api/v1/journey", headers=headers(alice)).json()["data"][0][
                "units"
            ][0]["lessons"]
            assert all(item["state"] == "completed" for item in all_done)
            reused = client.post(
                f"/api/v1/lessons/{lessons[1]['id']}/submit",
                headers=headers(alice),
                json={"request_id": first_request_id, "answers": {str(uuid4()): "are"}},
            )
            assert reused.status_code == 409
            summary = client.get("/api/v1/journey/summary", headers=headers(alice)).json()["data"]
            assert summary["completed_lessons"] == summary["total_lessons"] == 4
            assert summary["xp_total"] == 120
            assert summary["level"] == 2
            overview = client.get("/api/v1/gamification", headers=headers(alice)).json()["data"]
            assert overview["total_xp"] == 120
            assert overview["available_xp"] == 120
            assert overview["statistics"]["completed_lessons"] == 4
            assert overview["statistics"]["quiz_attempts"] == 4
            assert (
                client.get("/api/v1/gamification", headers=headers(bob)).json()["data"]["total_xp"]
                == 0
            )
            assert (
                client.get("/api/v1/gamification/notifications", headers=headers(bob)).json()[
                    "data"
                ]
                == []
            )
            assert all(quest["completed"] for quest in overview["quests"])
            assert {badge["title"] for badge in overview["badges"] if badge["unlocked"]} == {
                "First step",
                "Pathfinder",
                "Rising star",
            }
            notifications = client.get(
                "/api/v1/gamification/notifications", headers=headers(alice)
            ).json()["data"]
            assert len(notifications) == 10
            assert client.post(
                f"/api/v1/gamification/notifications/{notifications[0]['id']}/read",
                headers=headers(bob),
            ).json()["data"] == {"read": False}
            assert overview["rewards"][0]["id"] == reward_id
            claim_path = f"/api/v1/gamification/rewards/{reward_id}/claim"
            claimed = client.post(claim_path, headers=headers(alice))
            duplicate_claim = client.post(claim_path, headers=headers(alice))
            assert claimed.status_code == duplicate_claim.status_code == 200
            assert claimed.json()["data"]["newly_claimed"]
            assert not duplicate_claim.json()["data"]["newly_claimed"]
            assert claimed.json()["data"]["claim_id"] == duplicate_claim.json()["data"]["claim_id"]
            assert claimed.json()["data"]["available_xp"] == 0
            assert (
                client.get("/api/v1/gamification", headers=headers(alice)).json()["data"][
                    "total_xp"
                ]
                == 120
            )
            assert (
                client.get("/api/v1/journey/summary", headers=headers(bob)).json()["data"][
                    "xp_total"
                ]
                == 0
            )
            replay_path = f"/api/v1/lessons/{lessons[0]['id']}"
            replay = client.post(
                f"{replay_path}/submit",
                headers=headers(alice),
                json={
                    "request_id": str(uuid4()),
                    "answers": answers_for(
                        client.get(replay_path, headers=headers(alice)).json()["data"]
                    ),
                },
            )
            assert replay.json()["data"]["state"] == "mastered"
            assert replay.json()["data"]["earned_xp"] == 0
            first_question_id = client.get(replay_path, headers=headers(alice)).json()["data"][
                "questions"
            ][0]["id"]
            wrong = client.post(
                f"{replay_path}/submit",
                headers=headers(alice),
                json={"request_id": str(uuid4()), "answers": {first_question_id: str(uuid4())}},
            )
            assert wrong.status_code == 200
            assert wrong.json()["data"]["state"] == "mastered"
            assert not wrong.json()["data"]["passed"]
            assert (
                client.get("/api/v1/journey/summary", headers=headers(alice)).json()["data"][
                    "xp_total"
                ]
                == 120
            )
        # A new app/client instance models logout and login: progress stays in PostgreSQL.
        with TestClient(
            create_app(
                Settings(
                    _env_file=None,
                    environment="test",
                    database_url=database_url,
                    supabase_url="https://test.supabase.co",
                )
            )
        ) as client:
            restored = client.get("/api/v1/journey", headers=headers(alice)).json()["data"]
            assert restored[0]["units"][0]["lessons"][0]["state"] == "mastered"
            assert (
                client.get("/api/v1/gamification", headers=headers(alice)).json()["data"]["level"]
                == 2
            )
    finally:
        with engine.begin() as connection:
            connection.execute(
                text("DELETE FROM auth.users WHERE id IN (:alice, :bob)"),
                {"alice": alice, "bob": bob},
            )
        engine.dispose()
