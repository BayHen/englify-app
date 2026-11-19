"""Verify concurrent Daily Writing completions against disposable local Supabase only."""

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
        detail = response.text[:200]
        raise RuntimeError(f"{label}: HTTP {response.status_code}: {detail}")


def main() -> int:
    result = subprocess.run(
        [NPX, "supabase", "status", "--output", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    config = json.loads(result.stdout)
    base = config["API_URL"].rstrip("/")
    parsed = urlsplit(base)
    if parsed.scheme != "http" or parsed.hostname not in {"127.0.0.1", "localhost"} or parsed.port != 54321:
        raise RuntimeError("Refusing to test a non-local Supabase project")

    public_key = config["ANON_KEY"]
    service_key = config["SERVICE_ROLE_KEY"]
    service_headers = {"apikey": service_key, "Authorization": f"Bearer {service_key}"}
    email = f"englify-writing-daily-{uuid4().hex}@example.test"
    password = secrets.token_urlsafe(24)
    user_id = ""

    with httpx.Client(base_url=base, timeout=30) as client:
        try:
            created = client.post(
                "/auth/v1/admin/users",
                headers=service_headers,
                json={"email": email, "password": password, "email_confirm": True},
            )
            require(created, {200, 201}, "create local learner")
            user_id = created.json()["id"]
            signed_in = client.post(
                "/auth/v1/token?grant_type=password",
                headers={"apikey": public_key, "Authorization": f"Bearer {public_key}"},
                json={"email": email, "password": password},
            )
            require(signed_in, {200}, "sign in local learner")
            user_headers = {
                "apikey": public_key,
                "Authorization": f"Bearer {signed_in.json()['access_token']}",
                "Content-Type": "application/json",
            }
            level = client.post(
                "/rest/v1/rpc/englify_set_writing_level",
                headers=user_headers,
                json={"p_level": "B1"},
            )
            require(level, {200}, "set Writing level")
            overview = client.post(
                "/rest/v1/rpc/englify_writing_daily_overview",
                headers=user_headers,
                json={},
            )
            require(overview, {200}, "load Daily Writing assignment")
            assignment_id = overview.json()["challenge"]["assignment_id"]
            body = ("This response contains enough original words for a concurrent server validated writing challenge. " * 9).strip()

            def complete() -> httpx.Response:
                with httpx.Client(base_url=base, timeout=30) as worker:
                    return worker.post(
                        "/rest/v1/rpc/englify_submit_daily_writing",
                        headers=user_headers,
                        json={
                            "p_assignment_id": assignment_id,
                            "p_request_id": str(uuid4()),
                            "p_body": body,
                            "p_grammar_check": False,
                        },
                    )

            with ThreadPoolExecutor(max_workers=2) as executor:
                responses = list(executor.map(lambda _: complete(), range(2)))
            for index, response in enumerate(responses, start=1):
                require(response, {200}, f"concurrent completion {index}")
            payloads = [response.json() for response in responses]
            if sum(bool(item["newly_completed"]) for item in payloads) != 1:
                raise RuntimeError("Concurrent requests did not produce exactly one new completion")
            if sorted(int(item["earned_xp"]) for item in payloads) != [0, 20]:
                raise RuntimeError("Concurrent requests awarded an invalid XP total")

            completions = client.get(
                "/rest/v1/writing_daily_completions",
                headers=service_headers,
                params={"select": "id", "user_id": f"eq.{user_id}"},
            )
            events = client.get(
                "/rest/v1/xp_events",
                headers=service_headers,
                params={"select": "id,amount", "user_id": f"eq.{user_id}", "source_type": "eq.writing"},
            )
            require(completions, {200}, "completion ledger")
            require(events, {200}, "XP ledger")
            if len(completions.json()) != 1 or len(events.json()) != 1 or events.json()[0]["amount"] != 20:
                raise RuntimeError("Concurrent requests created duplicate completion or XP rows")
            print("PASS: concurrent Daily Writing completion awards XP exactly once")
        finally:
            if user_id:
                client.delete(f"/auth/v1/admin/users/{user_id}", headers=service_headers)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
