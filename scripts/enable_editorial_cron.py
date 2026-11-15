"""Dry-run or apply the approved bounded 07:00–12:45 ICT Cron schedule."""

from __future__ import annotations

import argparse
from pathlib import Path

import psycopg
from deploy_hybrid_migrations import target_url

SCRIPT = Path('supabase/scripts/enable_real_english_five_daily.sql')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    arguments = parser.parse_args()
    with psycopg.connect(target_url(), connect_timeout=10,
                         options='-c lock_timeout=3000 -c statement_timeout=30000') as connection:
        try:
            with connection.cursor() as cursor:
                cursor.execute(SCRIPT.read_text(encoding='utf-8'))
                cursor.execute("SELECT schedule,active FROM cron.job "
                               "WHERE jobname='englify-real-english-daily'")
                if cursor.fetchone() != ('*/15 0-5 * * *', True):
                    raise RuntimeError('Cron schedule did not match the approved window')
            if arguments.apply:
                connection.commit()
                print('Bounded five-lesson Cron schedule committed.')
            else:
                connection.rollback()
                print('Bounded five-lesson Cron schedule validated, then rolled back.')
        except BaseException:
            connection.rollback()
            raise


if __name__ == '__main__':
    main()
