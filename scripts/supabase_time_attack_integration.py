"""Verify Time Attack concurrency, recovery and score privacy against local Supabase only."""

from __future__ import annotations

import json
import os
import secrets
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from urllib.parse import urlsplit
from uuid import uuid4

import httpx

NPX = "npx.cmd" if os.name == "nt" else "npx"


def require(response: httpx.Response, allowed: set[int], label: str) -> None:
    if response.status_code not in allowed:
        raise RuntimeError(f"{label}: HTTP {response.status_code}")


def main() -> int:
    config = json.loads(
        subprocess.run(
            [NPX, "--no-install", "supabase", "status", "--output", "json"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    )
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
    accounts = []
    with httpx.Client(base_url=base, timeout=30) as client:
        try:
            headers = []
            for _ in range(2):
                email, password = (
                    f"arena-timed-{uuid4().hex}@example.test",
                    secrets.token_urlsafe(24),
                )
                created = client.post(
                    "/auth/v1/admin/users",
                    headers=service,
                    json={"email": email, "password": password, "email_confirm": True},
                )
                require(created, {200, 201}, "create local learner")
                accounts.append(created.json()["id"])
                login = client.post(
                    "/auth/v1/token?grant_type=password",
                    headers=public,
                    json={"email": email, "password": password},
                )
                require(login, {200}, "sign in")
                headers.append(
                    {
                        "apikey": config["ANON_KEY"],
                        "Authorization": f"Bearer {login.json()['access_token']}",
                    }
                )
            alice, bob = headers

            def rpc(name: str, body: dict, auth: dict = alice) -> httpx.Response:
                return client.post(
                    f"/rest/v1/rpc/englify_time_attack_{name}", headers=auth, json=body
                )

            require(rpc("records", {}, public), {401, 403}, "anonymous records")
            body = {
                "p_request_id": str(uuid4()),
                "p_level": "A1",
                "p_difficulty": "normal",
            }

            def start(_: int) -> httpx.Response:
                with httpx.Client(base_url=base, timeout=30) as worker:
                    return worker.post(
                        "/rest/v1/rpc/englify_time_attack_start",
                        headers=alice,
                        json=body,
                    )

            with ThreadPoolExecutor(max_workers=2) as pool:
                starts = list(pool.map(start, [0, 1]))
            for response in starts:
                require(response, {200}, "concurrent start")
            game = starts[0].json()
            game_id = game["id"]
            if (
                starts[1].json()["id"] != game_id
                or starts[1].json()["question_started_at"]
                != game["question_started_at"]
            ):
                raise RuntimeError("Duplicate starts reset or duplicated the game")
            if (
                "questions" in game
                or game["review"] is not None
                or "answer" in game["current_question"]
            ):
                raise RuntimeError("Future questions or keys leaked")
            for operation, extra in [
                ("session", {}),
                (
                    "answer",
                    {
                        "p_question_id": game["current_question"]["id"],
                        "p_request_id": str(uuid4()),
                        "p_answer": "forged",
                    },
                ),
                ("finish", {"p_abandon": True}),
            ]:
                require(
                    rpc(operation, {"p_session_id": game_id, **extra}, bob),
                    {404},
                    "cross-user game mutation",
                )
            require(
                rpc("start", {**body, "p_time_limit_seconds": 9999}),
                {404},
                "arbitrary rule arguments",
            )
            require(
                client.patch(
                    "/rest/v1/arena_time_attack_sessions",
                    headers=alice,
                    params={"id": f"eq.{game_id}"},
                    json={"score": 99999, "remaining_lives": 99},
                ),
                {401, 403},
                "direct score/life write",
            )
            require(
                client.get("/rest/v1/arena_time_attack_answers", headers=alice),
                {401, 403},
                "private answer events",
            )
            require(
                client.post(
                    "/rest/v1/rpc/englify_arena_submit",
                    headers=alice,
                    json={"p_session_id": game_id, "p_answers": {}},
                ),
                {409},
                "Practice bypass",
            )

            def fixture(question_id: str):
                rows = client.get(
                    "/rest/v1/arena_session_questions",
                    headers=service,
                    params={
                        "session_id": f"eq.{game_id}",
                        "question_id": f"eq.{question_id}",
                        "select": "answer,question",
                    },
                )
                require(rows, {200}, "read private fixture as service")
                row = rows.json()[0]
                return (
                    row["answer"][0]
                    if row["question"]["kind"] in {"fill_blank", "grammar_correction"}
                    else row["answer"]
                )

            first_question = game["current_question"]["id"]
            answer_body = {
                "p_session_id": game_id,
                "p_question_id": first_question,
                "p_request_id": str(uuid4()),
                "p_answer": fixture(first_question),
            }

            def submit(payload: dict) -> httpx.Response:
                with httpx.Client(base_url=base, timeout=30) as worker:
                    return worker.post(
                        "/rest/v1/rpc/englify_time_attack_answer",
                        headers=alice,
                        json=payload,
                    )

            with ThreadPoolExecutor(max_workers=2) as pool:
                duplicates = list(pool.map(submit, [answer_body, answer_body]))
            for response in duplicates:
                require(response, {200}, "duplicate concurrent answer")
                if (
                    response.json()["answered_count"] != 1
                    or response.json()["combo"] != 1
                ):
                    raise RuntimeError("Duplicate answer inflated the game")
            restored = rpc("session", {"p_session_id": game_id})
            require(restored, {200}, "restore after lost answer response")
            current = restored.json()
            second = current["current_question"]["id"]
            repeated = rpc("session", {"p_session_id": game_id})
            require(repeated, {200}, "repeat question load")
            if repeated.json()["question_started_at"] != current["question_started_at"]:
                raise RuntimeError("Reload reset the response timer")
            payload = {
                "p_session_id": game_id,
                "p_question_id": second,
                "p_request_id": str(uuid4()),
                "p_answer": fixture(second),
            }
            with ThreadPoolExecutor(max_workers=2) as pool:
                races = list(
                    pool.map(
                        submit, [payload, {**payload, "p_request_id": str(uuid4())}]
                    )
                )
            if sorted(response.status_code for response in races) != [200, 409]:
                raise RuntimeError("Two distinct submissions changed the same question")
            accepted = next(
                response.json() for response in races if response.status_code == 200
            )
            if accepted["answered_count"] != 2 or accepted["combo"] != 2:
                raise RuntimeError("Answer race advanced progression twice")
            keys = client.get(
                "/rest/v1/arena_session_questions",
                headers=service,
                params={
                    "session_id": f"eq.{game_id}",
                    "select": "question_id,position",
                    "order": "position",
                },
            )
            require(keys, {200}, "sequence fixture")
            third = keys.json()[2]["question_id"]
            require(
                rpc(
                    "answer",
                    {
                        "p_session_id": game_id,
                        "p_question_id": third,
                        "p_request_id": str(uuid4()),
                        "p_answer": fixture(third),
                    },
                ),
                {409},
                "unissued next question",
            )
            expiry = datetime.now(UTC) + timedelta(milliseconds=200)
            patch = client.patch(
                "/rest/v1/arena_time_attack_sessions",
                headers=service,
                params={"id": f"eq.{game_id}"},
                json={
                    "started_at": (expiry - timedelta(seconds=120)).isoformat(),
                    "expires_at": expiry.isoformat(),
                },
            )
            require(patch, {200, 204}, "local deadline fixture")
            time.sleep(0.25)
            expired = rpc("session", {"p_session_id": game_id})
            require(expired, {200}, "lazy expiration after app absence")
            if (
                expired.json()["status"] != "expired"
                or expired.json()["answered_count"] != 2
                or expired.json()["score"] != accepted["score"]
            ):
                raise RuntimeError("Expiry lost accepted answers or restored time")
            require(
                rpc(
                    "answer",
                    {
                        "p_session_id": game_id,
                        "p_question_id": third,
                        "p_request_id": str(uuid4()),
                        "p_answer": fixture(third),
                    },
                ),
                {409},
                "post-expiry answer",
            )
            retry = submit(answer_body)
            require(retry, {200}, "retry accepted answer after expiry")
            if retry.json()["answered_count"] != 2:
                raise RuntimeError("Terminal retry changed score")
            records = rpc("records", {})
            require(records, {200}, "personal records")
            normal = next(
                record
                for record in records.json()["records"]
                if record["difficulty"] == "normal"
            )
            if (
                normal["highest_score"] != accepted["score"]
                or normal["fastest_completion_ms"] is not None
            ):
                raise RuntimeError(
                    "Personal records included an invalid completion time"
                )
            xp = client.get(
                "/rest/v1/xp_events",
                headers=alice,
                params={"user_id": f"eq.{accounts[0]}", "select": "id"},
            )
            require(xp, {200}, "XP preservation")
            if xp.json():
                raise RuntimeError("Time Attack awarded XP")
            practice = client.post(
                "/rest/v1/rpc/englify_arena_history", headers=alice, json={}
            )
            require(practice, {200}, "Practice history isolation")
            if practice.json()["total"] != 0:
                raise RuntimeError("Timed games polluted Practice history")
            other_history = rpc("history", {}, bob)
            require(other_history, {200}, "other learner history")
            if other_history.json()["total"] != 0:
                raise RuntimeError("History RLS leaked results")
            print(
                "PASS: timed Auth/RLS, rule and score forgery rejection, answer privacy, sequence and restore"
            )
            print(
                "PASS: concurrent starts/duplicate answers/distinct answer races, expiry, personal records and unchanged XP"
            )
        finally:
            for account in accounts:
                require(
                    client.delete(f"/auth/v1/admin/users/{account}", headers=service),
                    {200, 204},
                    "clean up test learner",
                )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
