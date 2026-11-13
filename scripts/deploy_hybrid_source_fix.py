"""Validate or apply the additive source-preflight quota migration.

Default mode rolls back. --apply commits after the local smoke test passes.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import psycopg
from deploy_hybrid_migrations import target_url

MIGRATION = Path('supabase/migrations/20261112010000_real_english_source_preflight.sql')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    arguments = parser.parse_args()
    connection = psycopg.connect(target_url(), connect_timeout=10,
                                 options='-c lock_timeout=3000 -c statement_timeout=30000')
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT count(*) FROM public.real_english_generation_jobs
                WHERE status='failed' AND error_code='provider'
                  AND error_message='Tatoeba request timed out.'
            """)
            before = cursor.fetchone()[0]
            connection.execute(MIGRATION.read_text(encoding='utf-8'))
            cursor.execute("""
                SELECT count(*) FROM public.real_english_generation_jobs
                WHERE status='failed' AND error_code='source_timeout'
                  AND error_message='Tatoeba request timed out.'
            """)
            print('source_timeout_jobs_classified=', cursor.fetchone()[0], 'newly_classified=', before)
        if arguments.apply:
            connection.commit()
            print('COMMIT completed: source preflight quota fix applied')
        else:
            connection.rollback()
            print('ROLLBACK completed: source preflight quota fix validated only')
    except BaseException:
        connection.rollback()
        raise
    finally:
        connection.close()


if __name__ == '__main__':
    main()
