"""Fail a release when remote migrations or Arena RPC contracts are missing.

This check is deliberately read-only. RPC probes use the public anonymous role and
only assert that PostgREST can resolve each function signature; authentication or
authorization failures are expected and accepted.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

PROBES: dict[str, dict[str, object]] = {
    "englify_arena_catalog": {},
    "englify_arena_history": {"p_page": 1},
    "englify_time_attack_history": {"p_page": 1},
    "englify_time_attack_records": {},
    "englify_ranked_me": {},
    "englify_ranked_history": {"p_page": 1},
    "englify_ranked_leaderboard": {
        "p_scope": "weekly",
        "p_page": 1,
        "p_season_id": None,
    },
    "englify_quiz_mistake_summary": {},
    "englify_quiz_weakness_analytics": {},
    "englify_quiz_recommendations": {},
}

MISSING_CODES = {"PGRST202", "PGRST203"}
MISSING_TEXT = ("schema cache", "could not find the function")


def migration_parity() -> None:
    executable = "npx.cmd" if os.name == "nt" else "npx"
    result = subprocess.run(
        [executable, "--no-install", "supabase", "migration", "list", "--remote"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Could not read remote migrations")
    payload = json.loads(result.stdout)
    mismatches = [
        row
        for row in payload.get("migrations", [])
        if not row.get("local") or row.get("local") != row.get("remote")
    ]
    if mismatches:
        versions = ", ".join(
            f"local={row.get('local') or '-'} remote={row.get('remote') or '-'}"
            for row in mismatches
        )
        raise RuntimeError(f"Remote migration drift detected: {versions}")


def rpc_contracts() -> None:
    base = (os.getenv("SUPABASE_URL") or os.getenv("EXPO_PUBLIC_SUPABASE_URL") or "").rstrip("/")
    key = os.getenv("SUPABASE_ANON_KEY") or os.getenv("EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY") or ""
    if not base or not key:
        raise RuntimeError("SUPABASE_URL and SUPABASE_ANON_KEY are required")

    failures: list[str] = []
    for name, body in PROBES.items():
        request = urllib.request.Request(
            f"{base}/rest/v1/rpc/{name}",
            data=json.dumps(body).encode(),
            headers={
                "apikey": key,
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                raw = response.read().decode()
        except urllib.error.HTTPError as error:
            raw = error.read().decode()
        except (urllib.error.URLError, TimeoutError) as error:
            failures.append(f"{name}: request failed: {error}")
            continue
        try:
            parsed = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            parsed = {}
        code = parsed.get("code") if isinstance(parsed, dict) else None
        lowered = raw.lower()
        if code in MISSING_CODES or any(marker in lowered for marker in MISSING_TEXT):
            failures.append(f"{name}: PostgREST could not resolve the expected signature ({code})")
    if failures:
        raise RuntimeError("\n".join(failures))


def main() -> int:
    try:
        migration_parity()
        rpc_contracts()
    except (RuntimeError, json.JSONDecodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(f"PASS: remote migration parity and {len(PROBES)} Arena RPC contracts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
