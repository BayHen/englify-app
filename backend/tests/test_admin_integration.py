"""Admin authorization, publishing, CRUD, and audit on disposable PostgreSQL."""

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
    reason="Use a disposable migrated PostgreSQL database",
)
def test_admin_crud_publish_mobile_visibility_and_audit(monkeypatch) -> None:
    url = os.environ["ENGLIFY_TEST_DATABASE_URL"]
    engine = create_engine(url)
    admin_id, learner_id = uuid4(), uuid4()
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
            headers={"kid": "admin-test"},
        )
        return {"Authorization": f"Bearer {token}"}

    with engine.begin() as connection:
        for user_id in (admin_id, learner_id):
            connection.execute(
                text("INSERT INTO auth.users(id,raw_user_meta_data) VALUES (:id,'{}'::jsonb)"),
                {"id": user_id},
            )
        connection.execute(
            text("INSERT INTO public.admin_members(user_id) VALUES (:id)"), {"id": admin_id}
        )
    settings = Settings(
        _env_file=None,
        environment="test",
        database_url=url,
        supabase_url="https://test.supabase.co",
    )
    created: list[tuple[str, str]] = []
    slug = f"admin-test-{uuid4().hex[:10]}"
    term = f"Beacon {slug}"
    try:
        with TestClient(create_app(settings)) as client:
            admin = headers(admin_id)
            learner = headers(learner_id)
            assert client.get("/api/v1/admin/me").status_code == 401
            assert client.get("/api/v1/admin/me", headers=learner).status_code == 403
            assert (
                client.post(
                    "/api/v1/admin/catalog/courses",
                    headers=learner,
                    json={"data": {"slug": "blocked", "title": "Blocked", "level": 1}},
                ).status_code
                == 403
            )
            assert client.get("/api/v1/admin/me", headers=admin).json()["data"]["role"] == "admin"

            def create(resource, data):
                response = client.post(
                    f"/api/v1/admin/catalog/{resource}", headers=admin, json={"data": data}
                )
                assert response.status_code == 201, response.text
                item = response.json()["data"]
                created.append((resource, item["id"]))
                return item

            course = create("courses", {"slug": slug, "title": "Test journey", "level": 1})
            unit = create(
                "units",
                {"course_id": course["id"], "slug": slug, "title": "Unit one", "position": 1},
            )
            lesson = create(
                "lessons",
                {
                    "course_id": course["id"],
                    "unit_id": unit["id"],
                    "slug": slug,
                    "title": "First lesson",
                    "objective": "Practice",
                    "position": 1,
                },
            )
            create(
                "lesson-items",
                {
                    "lesson_id": lesson["id"],
                    "position": 1,
                    "kind": "reading",
                    "body": {"text": "Hello"},
                },
            )
            question = create(
                "quiz-questions",
                {
                    "lesson_id": lesson["id"],
                    "position": 1,
                    "kind": "multiple_choice",
                    "prompt": "Choose hello",
                },
            )
            assert (
                client.post(
                    f"/api/v1/admin/catalog/quiz-questions/{question['id']}/publish", headers=admin
                ).status_code
                == 422
            )
            create(
                "quiz-options",
                {
                    "question_id": question["id"],
                    "position": 1,
                    "answer_text": "Hello",
                    "is_correct": True,
                },
            )
            create(
                "quiz-options",
                {
                    "question_id": question["id"],
                    "position": 2,
                    "answer_text": "Goodbye",
                    "is_correct": False,
                },
            )
            word = create(
                "vocabulary",
                {
                    "term": term,
                    "definition": "A guiding light",
                    "translation": "đèn hiệu",
                    "source_name": "Englify Quest editorial",
                    "license_id": "project-owned",
                },
            )
            expression = create(
                "real-english",
                {
                    "slug": slug,
                    "kind": "idiom",
                    "expression": "On the ball",
                    "meaning_vi": "nhanh nhạy",
                    "context_explanation": "Used when attentive.",
                    "example_en": "She is on the ball.",
                    "example_vi": "Cô ấy nhanh nhạy.",
                    "formality": "informal",
                    "region_note": "General",
                    "source_name": "Englify Quest editorial",
                    "license_id": "project-owned",
                    "provenance_note": "Original sample",
                },
            )
            badge = create(
                "badges",
                {"code": slug, "title": "Test badge", "metric": "completed_lessons", "target": 1},
            )
            assert not word["is_published"] and not course["is_published"]
            with engine.begin() as connection:
                connection.execute(text("SET LOCAL ROLE authenticated"))
                connection.execute(
                    text("SELECT set_config('request.jwt.claim.sub', :uid, true)"),
                    {"uid": str(learner_id)},
                )
                assert (
                    connection.execute(
                        text("SELECT count(*) FROM public.courses WHERE id=:id"),
                        {"id": course["id"]},
                    ).scalar_one()
                    == 0
                )
                assert (
                    connection.execute(
                        text("SELECT count(*) FROM public.dictionary_entries WHERE id=:id"),
                        {"id": word["id"]},
                    ).scalar_one()
                    == 0
                )
                assert (
                    connection.execute(
                        text(
                            "SELECT has_table_privilege("
                            "'authenticated','public.admin_members','SELECT')"
                        )
                    ).scalar_one()
                    is False
                )
                # Admin editors need SELECT on answer keys; RLS must still hide
                # them from an ordinary authenticated learner.
                connection.execute(text("SET LOCAL ROLE authenticated"))
                connection.execute(
                    text("SELECT set_config('request.jwt.claim.sub', :uid, true)"),
                    {"uid": str(learner_id)},
                )
                assert (
                    connection.execute(
                        text("SELECT count(*) FROM public.quiz_answer_keys")
                    ).scalar_one()
                    == 0
                )
            assert all(
                item["title"] != "Test journey"
                for item in client.get("/api/v1/journey", headers=learner).json()["data"]
            )
            assert all(
                item["term"] != term
                for item in client.get(f"/api/v1/dictionary?q={term}", headers=learner).json()[
                    "data"
                ]
            )
            for resource, item in [
                ("courses", course),
                ("units", unit),
                ("lessons", lesson),
                ("lesson-items", created[3][1]),
                ("quiz-questions", question),
                ("vocabulary", word),
                ("real-english", expression),
                ("badges", badge),
            ]:
                item_id = item if isinstance(item, str) else item["id"]
                response = client.post(
                    f"/api/v1/admin/catalog/{resource}/{item_id}/publish", headers=admin
                )
                assert response.status_code == 200, response.text
            assert any(
                item["title"] == "Test journey"
                for item in client.get("/api/v1/journey", headers=learner).json()["data"]
            )
            assert any(
                item["term"] == term
                for item in client.get(f"/api/v1/dictionary?q={term}", headers=learner).json()[
                    "data"
                ]
            )
            assert any(
                item["expression"] == "On the ball"
                for item in client.get(
                    "/api/v1/real-english?q=On%20the%20ball", headers=learner
                ).json()["data"]
            )
            edited = client.patch(
                f"/api/v1/admin/catalog/courses/{course['id']}",
                headers=admin,
                json={"data": {"title": "Edited journey"}},
            )
            assert edited.status_code == 200 and edited.json()["data"]["title"] == "Edited journey"
            assert client.get("/api/v1/admin/audit", headers=admin).json()["data"]
            assert (
                client.delete(
                    f"/api/v1/admin/catalog/vocabulary/{word['id']}", headers=admin
                ).status_code
                == 200
            )
            assert not client.get(f"/api/v1/dictionary?q={term}", headers=learner).json()["data"]
            assert client.get("/api/v1/admin/catalog/courses", headers=learner).status_code == 403
    finally:
        with engine.begin() as connection:
            connection.execute(
                text("DELETE FROM public.admin_audit_logs WHERE actor_id=:id"), {"id": admin_id}
            )
            connection.execute(text("DELETE FROM public.badges WHERE code=:slug"), {"slug": slug})
            connection.execute(
                text("DELETE FROM public.real_english_expressions WHERE slug=:slug"), {"slug": slug}
            )
            connection.execute(
                text("DELETE FROM public.dictionary_entries WHERE normalized_term=:term"),
                {"term": term.casefold()},
            )
            connection.execute(text("DELETE FROM public.courses WHERE slug=:slug"), {"slug": slug})
            connection.execute(
                text("DELETE FROM public.admin_members WHERE user_id=:id"), {"id": admin_id}
            )
            connection.execute(
                text("DELETE FROM auth.users WHERE id IN (:admin,:learner)"),
                {"admin": admin_id, "learner": learner_id},
            )
        engine.dispose()
