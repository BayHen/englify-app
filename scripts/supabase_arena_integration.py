"""Exercise Arena Auth/RLS, private keys and concurrent rewards on local Supabase only."""

from __future__ import annotations

import json
import os
import secrets
import subprocess
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlsplit
from uuid import uuid4

import httpx

NPX = "npx.cmd" if os.name == "nt" else "npx"


def require(response: httpx.Response, allowed: set[int], label: str) -> None:
    if response.status_code not in allowed:
        # Report no request headers, tokens or credentials.
        raise RuntimeError(f"{label}: HTTP {response.status_code}")


def main() -> int:
    output = subprocess.run(
        [NPX, "supabase", "status", "--output", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    config = json.loads(output.stdout)
    base = config["API_URL"].rstrip("/")
    target = urlsplit(base)
    if (
        target.scheme != "http"
        or target.hostname not in {"127.0.0.1", "localhost"}
        or target.port != 54321
    ):
        raise RuntimeError("Refusing to test a non-local Supabase project")
    service = {
        "apikey": config["SERVICE_ROLE_KEY"],
        "Authorization": f"Bearer {config['SERVICE_ROLE_KEY']}",
    }
    public = {
        "apikey": config["ANON_KEY"],
        "Authorization": f"Bearer {config['ANON_KEY']}",
    }
    accounts: list[str] = []
    with httpx.Client(base_url=base, timeout=30) as client:
        try:
            headers = []
            for _ in range(2):
                email, password = (
                    f"arena-{uuid4().hex}@example.test",
                    secrets.token_urlsafe(24),
                )
                created = client.post(
                    "/auth/v1/admin/users",
                    headers=service,
                    json={"email": email, "password": password, "email_confirm": True},
                )
                require(created, {200, 201}, "create local test user")
                accounts.append(created.json()["id"])
                signed = client.post(
                    "/auth/v1/token?grant_type=password",
                    headers=public,
                    json={"email": email, "password": password},
                )
                require(signed, {200}, "sign in")
                headers.append(
                    {
                        "apikey": config["ANON_KEY"],
                        "Authorization": f"Bearer {signed.json()['access_token']}",
                    }
                )
            alice, bob = headers

            def rpc(name: str, body: dict, auth: dict = alice) -> httpx.Response:
                return client.post(
                    f"/rest/v1/rpc/englify_arena_{name}", headers=auth, json=body
                )

            require(rpc("catalog", {}, public), {401, 403}, "anonymous Arena access")
            for table in ("arena_questions", "arena_answer_keys"):
                response = client.get(f"/rest/v1/{table}", headers=alice)
                require(response, {200}, "RLS bank access")
                if response.json():
                    raise RuntimeError("Learner read raw bank or answer-key rows")
            require(
                client.get("/rest/v1/arena_session_questions", headers=alice),
                {401, 403},
                "private session snapshots",
            )
            require(
                rpc("start", {"p_request_id": str(uuid4()), "p_level": "C2"}),
                {400},
                "invalid CEFR",
            )
            catalog = rpc("catalog", {})
            require(catalog, {200}, "catalog")
            if not catalog.json()["groups"]:
                raise RuntimeError("No published Arena seed content")

            def start(kind: str | None = None) -> dict:
                body = {
                    "p_request_id": str(uuid4()),
                    "p_level": "A1",
                    "p_count": 5,
                    "p_kind": kind,
                }
                response = rpc("start", body)
                require(response, {200}, "start quiz")
                retry = rpc("start", body)
                require(retry, {200}, "retry start")
                session = response.json()
                if retry.json()["id"] != session["id"] or session["result"] is not None:
                    raise RuntimeError("Start is not idempotent or result leaked")
                for question in session["questions"]:
                    if any(
                        key in question
                        for key in ("answer", "correct_answer", "explanation_vi")
                    ):
                        raise RuntimeError("Private key leaked before submission")
                return session

            def answers(session: dict) -> dict:
                rows = client.get(
                    "/rest/v1/arena_session_questions",
                    headers=service,
                    params={
                        "session_id": f"eq.{session['id']}",
                        "select": "question_id,question,answer",
                    },
                )
                require(rows, {200}, "read test fixture keys as service")
                return {
                    row["question_id"]: row["answer"][0]
                    if row["question"]["kind"] in {"fill_blank", "grammar_correction"}
                    else row["answer"]
                    for row in rows.json()
                }

            sessions = [start(), start()]
            first = sessions[0]
            require(
                rpc("session", {"p_session_id": first["id"]}, bob),
                {404},
                "cross-user session read",
            )
            require(
                rpc("submit", {"p_session_id": first["id"], "p_answers": {}}, bob),
                {404},
                "cross-user submit",
            )
            require(
                rpc("end", {"p_session_id": first["id"]}, bob), {404}, "cross-user end"
            )
            require(
                rpc(
                    "submit", {"p_session_id": first["id"], "p_answers": {"score": 100}}
                ),
                {400},
                "client score rejected",
            )
            require(
                client.patch(
                    "/rest/v1/arena_sessions",
                    headers=alice,
                    params={"id": f"eq.{first['id']}"},
                    json={"earned_xp": 10},
                ),
                {401, 403},
                "direct reward mutation",
            )
            fixtures = [answers(session) for session in sessions]

            def complete(index: int) -> httpx.Response:
                with httpx.Client(base_url=base, timeout=30) as worker:
                    return worker.post(
                        "/rest/v1/rpc/englify_arena_submit",
                        headers=alice,
                        json={
                            "p_session_id": sessions[index]["id"],
                            "p_answers": fixtures[index],
                        },
                    )

            # Two independent qualifying sessions must share one daily reward.
            with ThreadPoolExecutor(max_workers=2) as pool:
                results = list(pool.map(complete, [0, 1]))
            for response in results:
                require(response, {200}, "concurrent independent completion")
            if sorted(response.json()["earned_xp"] for response in results) != [0, 10]:
                raise RuntimeError(
                    "Daily reward was not bounded across concurrent sessions"
                )
            retry = complete(0)
            require(retry, {200}, "completed retry")
            if retry.json() != results[0].json():
                raise RuntimeError("Completed session changed on retry")

            # Two simultaneous submissions of the same new session must produce one immutable result.
            third = start()
            third_answers = answers(third)

            def duplicate(_: int) -> httpx.Response:
                with httpx.Client(base_url=base, timeout=30) as worker:
                    return worker.post(
                        "/rest/v1/rpc/englify_arena_submit",
                        headers=alice,
                        json={"p_session_id": third["id"], "p_answers": third_answers},
                    )

            with ThreadPoolExecutor(max_workers=2) as pool:
                duplicates = list(pool.map(duplicate, [0, 1]))
            for response in duplicates:
                require(response, {200}, "concurrent duplicate submit")
            if duplicates[0].json() != duplicates[1].json():
                raise RuntimeError("Duplicate submission produced different results")
            events = client.get(
                "/rest/v1/xp_events",
                headers=service,
                params={
                    "user_id": f"eq.{accounts[0]}",
                    "source_type": "eq.arena",
                    "select": "amount",
                },
            )
            require(events, {200}, "XP ledger")
            if events.json() != [{"amount": 10}]:
                raise RuntimeError("Arena XP ledger contains duplicate rewards")
            summary = client.post(
                "/rest/v1/rpc/englify_journey_summary", headers=alice, json={}
            )
            require(summary, {200}, "shared XP summary")
            if (
                summary.json()["xp_total"] != 10
                or summary.json()["completed_lessons"] != 0
            ):
                raise RuntimeError(
                    "Practice changed Journey progress or shared XP is stale"
                )
            history = rpc("history", {})
            require(history, {200}, "history")
            if history.json()["total"] != 3:
                raise RuntimeError("Practice history has missing or duplicate sessions")
            bob_history = rpc("history", {}, bob)
            require(bob_history, {200}, "other user history")
            if bob_history.json()["total"] != 0:
                raise RuntimeError("History leaked across users")
            journey = client.post(
                "/rest/v1/rpc/englify_journey", headers=alice, json={}
            )
            require(journey, {200}, "existing Journey read")
            lesson = next(
                lesson
                for course in journey.json()
                for unit in course["units"]
                for lesson in unit["lessons"]
                if lesson["state"] != "locked"
            )
            questions = client.get(
                "/rest/v1/quiz_questions",
                headers=service,
                params={
                    "lesson_id": f"eq.{lesson['id']}",
                    "is_published": "eq.true",
                    "archived_at": "is.null",
                    "select": "id,kind",
                },
            )
            require(questions, {200}, "Journey test question fixture")
            lesson_answers = {}
            for question in questions.json():
                if question["kind"] == "multiple_choice":
                    options = client.get(
                        "/rest/v1/quiz_options",
                        headers=service,
                        params={
                            "question_id": f"eq.{question['id']}",
                            "is_correct": "eq.true",
                            "select": "id",
                        },
                    )
                    require(options, {200}, "Journey test choice fixture")
                    lesson_answers[question["id"]] = options.json()[0]["id"]
                else:
                    key = client.get(
                        "/rest/v1/quiz_answer_keys",
                        headers=service,
                        params={
                            "question_id": f"eq.{question['id']}",
                            "select": "answer",
                        },
                    )
                    require(key, {200}, "Journey test text fixture")
                    value = key.json()[0]["answer"]
                    lesson_answers[question["id"]] = (
                        value if question["kind"] == "matching" else value[0]
                    )
            completed = client.post(
                "/rest/v1/rpc/englify_submit_lesson",
                headers=alice,
                json={
                    "p_lesson_id": lesson["id"],
                    "p_request_id": str(uuid4()),
                    "p_answers": lesson_answers,
                    "p_content_version": None,
                },
            )
            require(completed, {200}, "Journey completion after Arena")
            if not completed.json()["passed"] or completed.json()["earned_xp"] <= 0:
                raise RuntimeError(
                    "Journey completion or its reward was broken by Arena"
                )
            combined = client.post(
                "/rest/v1/rpc/englify_journey_summary", headers=alice, json={}
            )
            require(combined, {200}, "combined Journey and Arena XP")
            if (
                combined.json()["completed_lessons"] != 1
                or combined.json()["xp_total"] < 10 + completed.json()["earned_xp"]
            ):
                raise RuntimeError("Journey and Arena XP did not coexist")
            print(
                "PASS: existing Journey grading, completion and lesson rewards coexist with Arena XP"
            )
            print(
                "PASS: Arena Auth/RLS, key privacy, start retry, immutable results, concurrent duplicate submissions"
            )
            print(
                "PASS: independent concurrent sessions share one 10 XP reward; Journey progress unchanged"
            )
        finally:
            for account in accounts:
                response = client.delete(
                    f"/auth/v1/admin/users/{account}", headers=service
                )
                require(response, {200, 204}, "clean up local Arena test user")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
