"""Validate or apply the isolated Vocabulary Review migration.

Default mode executes inside a transaction and rolls back. ``--apply`` commits.
The target is cross-checked against the Admin Supabase URL and credentials are
never printed.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import psycopg
from deploy_hybrid_migrations import target_url

MIGRATION = Path("supabase/migrations/20261116010000_vocabulary_review_foundation.sql")


def main() -> None:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--verify", action="store_true")
    arguments = parser.parse_args()
    connection = psycopg.connect(
        target_url(),
        connect_timeout=10,
        options="-c lock_timeout=3000 -c statement_timeout=60000",
    )
    try:
        if arguments.verify:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT to_regprocedure('public.englify_due_vocabulary(integer)') IS NOT NULL,
                           to_regprocedure('public.englify_review_vocabulary(uuid,integer,uuid)') IS NOT NULL,
                           has_function_privilege('authenticated',
                             'public.englify_due_vocabulary(integer)','EXECUTE'),
                           has_function_privilege('anon',
                             'public.englify_due_vocabulary(integer)','EXECUTE'),
                           EXISTS (SELECT 1 FROM information_schema.columns
                             WHERE table_schema='public' AND table_name='saved_vocabulary'
                               AND column_name='algorithm_version')
                    """
                )
                if cursor.fetchone() != (True, True, True, False, True):
                    raise RuntimeError("Vocabulary Review live verification failed")
                cursor.execute("NOTIFY pgrst, 'reload schema'")
            connection.commit()
            print("PASS: Vocabulary Review RPC, grants and PostgREST schema reload verified")
            return
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT to_regclass('public.saved_vocabulary') IS NOT NULL,
                       to_regclass('public.review_history') IS NOT NULL,
                       to_regclass('public.dictionary_entries') IS NOT NULL,
                       to_regprocedure('public.englify_due_vocabulary(integer)') IS NOT NULL
                """
            )
            state = cursor.fetchone()
            if state != (True, True, True, False):
                raise SystemExit(f"Unexpected prerequisite state: {state}")
        connection.execute(MIGRATION.read_text(encoding="utf-8"))
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT to_regprocedure('public.englify_due_vocabulary(integer)') IS NOT NULL,
                       to_regprocedure('public.englify_review_vocabulary(uuid,integer,uuid)') IS NOT NULL,
                       has_function_privilege('authenticated',
                         'public.englify_due_vocabulary(integer)','EXECUTE'),
                       has_function_privilege('anon',
                         'public.englify_due_vocabulary(integer)','EXECUTE')
                """
            )
            if cursor.fetchone() != (True, True, True, False):
                raise RuntimeError("Vocabulary Review RPC postcondition failed")
        if arguments.apply:
            connection.commit()
            print("COMMIT: Vocabulary Review migration applied")
        else:
            connection.rollback()
            print("ROLLBACK: Vocabulary Review migration validated without persistent changes")
    except BaseException:
        connection.rollback()
        raise
    finally:
        connection.close()


if __name__ == "__main__":
    main()
