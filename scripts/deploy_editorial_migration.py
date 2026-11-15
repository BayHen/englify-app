"""Validate or apply the additive Real English editorial migration.

Default mode executes within a transaction and rolls back. Use --apply only
after the isolated smoke tests pass and the live schema has been inspected.
The database URL is read by the existing target_url helper and never printed.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import psycopg
from deploy_hybrid_migrations import target_url

MIGRATION = Path('supabase/migrations/20261113010000_real_english_editorial_workflow.sql')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    arguments = parser.parse_args()
    with psycopg.connect(target_url(), connect_timeout=10,
                         options='-c lock_timeout=3000 -c statement_timeout=30000') as connection:
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT to_regclass('public.real_english_lessons'), "
                               "to_regclass('public.real_english_review_history')")
                if not all(cursor.fetchone()):
                    raise RuntimeError('Real English hybrid foundation is missing')
                cursor.execute(MIGRATION.read_text(encoding='utf-8'))
                cursor.execute("SELECT to_regclass('public.real_english_generation_batches'), "
                               "to_regprocedure('public.englify_review_real_english_lesson(uuid,text,text)'), "
                               "to_regprocedure('public.englify_save_real_english_lesson(uuid,text,text,jsonb)')")
                if not all(cursor.fetchone()):
                    raise RuntimeError('Editorial migration did not create expected objects')
            if arguments.apply:
                connection.commit()
                print('Editorial migration committed; existing lesson IDs preserved.')
            else:
                connection.rollback()
                print('Editorial migration validated, then rolled back.')
        except BaseException:
            connection.rollback()
            raise


if __name__ == '__main__':
    main()
