"""Seed or verify one historical Writing row during the local V2 migration test."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from urllib.parse import urlsplit

import psycopg

NPX = "npx.cmd" if os.name == "nt" else "npx"
USER_ID = "d6111111-1111-4111-8111-111111111111"
EXERCISE_ID = "d6222222-2222-4222-8222-222222222222"
SUBMISSION_ID = "d6333333-3333-4333-8333-333333333333"
REQUEST_ID = "d6444444-4444-4444-8444-444444444444"
BODY = "Historical writing must remain unchanged during the Writing V2 upgrade."


def local_database_url() -> str:
    result = subprocess.run(
        [NPX, "supabase", "status", "--output", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    database_url = json.loads(result.stdout)["DB_URL"]
    parsed = urlsplit(database_url)
    if parsed.hostname not in {"127.0.0.1", "localhost"} or parsed.port != 54322:
        raise RuntimeError("Refusing to inspect a non-local database")
    return database_url


def seed(connection: psycopg.Connection[tuple[object, ...]]) -> None:
    connection.execute("INSERT INTO auth.users(id) VALUES (%s)", (USER_ID,))
    connection.execute(
        """INSERT INTO public.writing_exercises(id,slug,kind,prompt,hint,tokens,is_published)
        VALUES (%s,'historical-writing-v1','paragraph','Describe a historical event.','', '[]'::jsonb,true)""",
        (EXERCISE_ID,),
    )
    connection.execute(
        """INSERT INTO public.writing_submissions(id,user_id,exercise_id,request_id,prompt,body,created_at)
        VALUES (%s,%s,%s,%s,'Describe a historical event.',%s,'2026-11-01T00:30:00Z')""",
        (SUBMISSION_ID, USER_ID, EXERCISE_ID, REQUEST_ID, BODY),
    )
    connection.execute(
        """INSERT INTO public.writing_feedback(submission_id,rule_result,suggestions,grammar_status,grammar_matches)
        VALUES (%s,'self_review','[]'::jsonb,'not_requested','[]'::jsonb)""",
        (SUBMISSION_ID,),
    )
    print("PASS: seeded representative pre-V2 Writing history")


def verify(connection: psycopg.Connection[tuple[object, ...]]) -> None:
    row = connection.execute(
        """SELECT body,word_count,cefr_level_snapshot,exercise_kind_snapshot,
        analytics_metadata_source FROM public.writing_submissions WHERE id=%s""",
        (SUBMISSION_ID,),
    ).fetchone()
    if row is None:
        raise RuntimeError("Historical Writing submission was deleted")
    expected_words = len(BODY.split())
    if row != (BODY, expected_words, "A1", "paragraph", "backfilled"):
        raise RuntimeError(f"Historical Writing submission changed unexpectedly: {row!r}")
    feedback = connection.execute(
        "SELECT rule_result FROM public.writing_feedback WHERE submission_id=%s", (SUBMISSION_ID,)
    ).fetchone()
    if feedback != ("self_review",):
        raise RuntimeError("Historical deterministic feedback was not preserved")
    print("PASS: Writing V2 migrations preserve representative historical data")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("seed", "verify"))
    args = parser.parse_args()
    with psycopg.connect(local_database_url(), autocommit=True) as connection:
        if args.mode == "seed":
            seed(connection)
        else:
            verify(connection)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
