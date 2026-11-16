"""Verify concurrent Admin RPC retries against disposable local Supabase only."""

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
        raise RuntimeError(f"{label}: HTTP {response.status_code}")


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
    email = f"englify-atomic-{uuid4().hex}@example.test"
    password = secrets.token_urlsafe(24)
    user_id = ""
    badge_id = str(uuid4())
    request_id = str(uuid4())
    code = f"atomic-{badge_id[:8]}"

    with httpx.Client(base_url=base, timeout=20) as client:
        try:
            created = client.post(
                "/auth/v1/admin/users",
                headers=service_headers,
                json={"email": email, "password": password, "email_confirm": True},
            )
            require(created, {200, 201}, "create local admin")
            user_id = created.json()["id"]
            signed_in = client.post(
                "/auth/v1/token?grant_type=password",
                headers={"apikey": public_key, "Authorization": f"Bearer {public_key}"},
                json={"email": email, "password": password},
            )
            require(signed_in, {200}, "sign in local admin")
            user_headers = {
                "apikey": public_key,
                "Authorization": f"Bearer {signed_in.json()['access_token']}",
                "Content-Type": "application/json",
            }
            membership = client.post(
                "/rest/v1/admin_members",
                headers=service_headers,
                json={"user_id": user_id},
            )
            require(membership, {201}, "grant local admin membership")

            payload = {
                "p_request_id": request_id,
                "p_badge_id": badge_id,
                "p_data": {
                    "code": code,
                    "title": "Concurrent Admin Badge",
                    "description": "Disposable concurrency test",
                    "metric": "total_xp",
                    "target": 50,
                },
            }

            def mutate() -> httpx.Response:
                with httpx.Client(base_url=base, timeout=20) as worker:
                    return worker.post(
                        "/rest/v1/rpc/englify_admin_upsert_badge",
                        headers=user_headers,
                        json=payload,
                    )

            with ThreadPoolExecutor(max_workers=2) as executor:
                responses = list(executor.map(lambda _: mutate(), range(2)))
            for index, response in enumerate(responses, start=1):
                require(response, {200}, f"concurrent retry {index}")
            if responses[0].json() != responses[1].json():
                raise RuntimeError("Concurrent retries returned different records")

            badge_rows = client.get(
                "/rest/v1/badges",
                headers=service_headers,
                params={"select": "id", "id": f"eq.{badge_id}"},
            )
            rule_rows = client.get(
                "/rest/v1/badge_rules",
                headers=service_headers,
                params={"select": "badge_id", "badge_id": f"eq.{badge_id}"},
            )
            request_rows = client.get(
                "/rest/v1/admin_mutation_requests",
                headers=service_headers,
                params={"select": "request_id", "request_id": f"eq.{request_id}"},
            )
            for response, label in ((badge_rows, "badge"), (rule_rows, "badge rule"), (request_rows, "mutation request")):
                require(response, {200}, label)
                if len(response.json()) != 1:
                    raise RuntimeError(f"Concurrent retries created an invalid {label} count")
            print("PASS: concurrent Admin mutation retries are idempotent")
        finally:
            if badge_id:
                client.delete("/rest/v1/badges", headers=service_headers, params={"id": f"eq.{badge_id}"})
            if user_id:
                client.delete("/rest/v1/admin_audit_logs", headers=service_headers, params={"actor_id": f"eq.{user_id}"})
                client.delete(f"/auth/v1/admin/users/{user_id}", headers=service_headers)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
