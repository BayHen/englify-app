"""Dry-run or apply the approved five-lesson daily configuration.

The SQL file includes BEGIN/COMMIT for manual use. This runner removes only
those wrappers so its default mode can always roll back.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import psycopg
from deploy_hybrid_migrations import target_url

CONFIG = Path('supabase/scripts/configure_real_english_five_daily.sql')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    arguments = parser.parse_args()
    sql = CONFIG.read_text(encoding='utf-8')
    if sql.count('BEGIN;') != 1 or sql.count('COMMIT;') != 1:
        raise RuntimeError('Unexpected transaction wrapper in daily configuration')
    sql = sql.replace('BEGIN;', '', 1).replace('COMMIT;', '', 1)
    with psycopg.connect(target_url(), connect_timeout=10,
                         options='-c lock_timeout=3000 -c statement_timeout=30000') as connection:
        try:
            with connection.cursor() as cursor:
                cursor.execute(sql)
                cursor.execute("SELECT daily_generation_target,maximum_daily_requests," 
                               "cardinality(enabled_topics) "
                               "FROM public.real_english_generation_settings WHERE id=true")
                if cursor.fetchone() != (5, 10, 6):
                    raise RuntimeError('Daily target, cap, or topic count is incorrect')
                cursor.execute("SELECT count(*) FROM public.real_english_topics t "
                               "CROSS JOIN public.real_english_generation_settings s "
                               "WHERE s.id=true AND t.is_active "
                               "AND t.slug=ANY(s.enabled_topics) "
                               "AND t.difficulty=ANY(s.enabled_difficulty_levels)")
                if cursor.fetchone()[0] < 5:
                    raise RuntimeError('Fewer than five eligible configured topics')
            if arguments.apply:
                connection.commit()
                print('Five-lesson daily settings committed; existing content preserved.')
            else:
                connection.rollback()
                print('Five-lesson daily settings validated, then rolled back.')
        except BaseException:
            connection.rollback()
            raise


if __name__ == '__main__':
    main()
