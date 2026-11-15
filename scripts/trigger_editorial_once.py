"""Run one approved Cron dispatch now, without printing Vault values.

Uses the exact query stored by enable_real_english_five_daily.sql. The SQL
selects at most one eligible slot and checks the batch target/quota.
"""

from __future__ import annotations

import re
from pathlib import Path

import psycopg
from deploy_hybrid_migrations import target_url

SCRIPT = Path('supabase/scripts/enable_real_english_five_daily.sql')


def main() -> None:
    source = SCRIPT.read_text(encoding='utf-8')
    match = re.search(r'\$job\$(.*?)\$job\$', source, flags=re.DOTALL)
    if not match:
        raise RuntimeError('Cron dispatch query missing')
    with psycopg.connect(target_url(), connect_timeout=10,
                         options='-c lock_timeout=3000 -c statement_timeout=30000') as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT schedule,active FROM cron.job "
                           "WHERE jobname='englify-real-english-daily'")
            if cursor.fetchone() != ('*/15 0-5 * * *', True):
                raise RuntimeError('Approved Cron schedule is not active')
            cursor.execute(match.group(1))
            rows = cursor.fetchall()
            if len(rows) > 1:
                raise RuntimeError('Scheduler dispatched more than one slot')
        connection.commit()
        print('One bounded dispatch queued.' if rows else 'No eligible slot remains today.')


if __name__ == '__main__':
    main()
