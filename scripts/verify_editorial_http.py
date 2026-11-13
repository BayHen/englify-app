"""Read only recent Cron HTTP result codes; never print request headers or tokens."""

from __future__ import annotations

import psycopg
from deploy_hybrid_migrations import target_url


def main() -> None:
    with psycopg.connect(target_url(), connect_timeout=10,
                         options='-c statement_timeout=10000') as connection, connection.cursor() as cursor:
        cursor.execute("SELECT id,status_code,timed_out,content::jsonb->>'error', "
                       "content::jsonb->>'code' FROM net._http_response "
                       "ORDER BY id DESC LIMIT 5")
        for row in cursor.fetchall():
            print('request_result=', row)


if __name__ == '__main__':
    main()
