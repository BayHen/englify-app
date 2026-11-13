"""Dry-run or apply archive-aware daily batch counting without exposing secrets."""

from __future__ import annotations

import argparse
from pathlib import Path

import psycopg
from deploy_hybrid_migrations import target_url

MIGRATION = Path('supabase/migrations/20261113020000_real_english_batch_eligibility.sql')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    arguments = parser.parse_args()
    with psycopg.connect(target_url(), connect_timeout=10,
                         options='-c lock_timeout=3000 -c statement_timeout=30000') as connection:
        try:
            with connection.cursor() as cursor:
                cursor.execute(MIGRATION.read_text(encoding='utf-8'))
                cursor.execute("SELECT success_count,target_count "
                               "FROM public.real_english_generation_batches "
                               "WHERE generation_date=(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date")
                result = cursor.fetchone()
                if not result or result[1] != 5:
                    raise RuntimeError('Five-lesson batch did not refresh')
                print('Archive-aware batch count/target=', result)
            if arguments.apply:
                connection.commit()
                print('Archive-aware batch migration committed.')
            else:
                connection.rollback()
                print('Archive-aware batch migration validated, then rolled back.')
        except BaseException:
            connection.rollback()
            raise


if __name__ == '__main__':
    main()
