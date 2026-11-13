"""Dry-run or apply bounded source preflight logging on Supabase."""

from __future__ import annotations

import argparse
from pathlib import Path

import psycopg
from deploy_hybrid_migrations import target_url

MIGRATION = Path('supabase/migrations/20261113030000_real_english_preflight_retry.sql')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    arguments = parser.parse_args()
    with psycopg.connect(target_url(), connect_timeout=10,
                         options='-c lock_timeout=3000 -c statement_timeout=30000') as connection:
        try:
            with connection.cursor() as cursor:
                cursor.execute(MIGRATION.read_text(encoding='utf-8'))
                cursor.execute("SELECT to_regclass('public.real_english_generation_preflights'), "
                               "to_regprocedure('public.englify_record_real_english_preflight_failure(" 
                               "text,uuid,integer,text,text)')")
                if not all(cursor.fetchone()):
                    raise RuntimeError('Preflight retry objects missing')
            if arguments.apply:
                connection.commit()
                print('Bounded source preflight migration committed.')
            else:
                connection.rollback()
                print('Bounded source preflight migration validated, then rolled back.')
        except BaseException:
            connection.rollback()
            raise


if __name__ == '__main__':
    main()
