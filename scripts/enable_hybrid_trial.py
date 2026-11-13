"""Enable one manual Real English draft request per day; no Cron or user records.

Default mode rolls back. --apply commits only if generation settings are untouched.
"""

from __future__ import annotations

import argparse

import psycopg
from deploy_hybrid_migrations import target_url


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--verify', action='store_true')
    arguments = parser.parse_args()
    if arguments.apply and arguments.verify:
        parser.error('--apply and --verify are mutually exclusive')
    connection = psycopg.connect(target_url(), connect_timeout=10,
                                 options='-c lock_timeout=3000 -c statement_timeout=30000'
                                 + (' -c default_transaction_read_only=on' if arguments.verify else ''))
    try:
        with connection.cursor() as cursor:
            if arguments.verify:
                cursor.execute("""
                    SELECT ai_generation_enabled, source_import_enabled,
                           daily_generation_target, maximum_daily_requests,
                           maximum_output_tokens, enabled_topics
                    FROM public.real_english_generation_settings WHERE id=true
                """)
                print('trial_settings=', cursor.fetchone())
                cursor.execute("""
                    SELECT slug,search_keyword,difficulty,is_active
                    FROM public.real_english_topics WHERE slug='coffee-conversation'
                """)
                print('trial_topic=', cursor.fetchone())
                cursor.execute("""
                    SELECT status,count(*) FROM public.real_english_generation_jobs
                    GROUP BY status ORDER BY status
                """)
                print('job_status_counts=', cursor.fetchall())
                cursor.execute("""
                    SELECT status,error_code,error_message,attempt_count,
                           created_at AT TIME ZONE 'Asia/Ho_Chi_Minh'
                    FROM public.real_english_generation_jobs
                    ORDER BY created_at DESC LIMIT 1
                """)
                print('latest_job_diagnostic=', cursor.fetchone())
                cursor.execute("""
                    SELECT status,count(*) FROM public.real_english_lessons
                    GROUP BY status ORDER BY status
                """)
                print('lesson_status_counts=', cursor.fetchall())
                connection.rollback()
                return
            cursor.execute("""
                SELECT ai_generation_enabled, source_import_enabled,
                       daily_generation_target, maximum_daily_requests,
                       maximum_output_tokens, enabled_topics
                FROM public.real_english_generation_settings WHERE id=true FOR UPDATE
            """)
            if cursor.fetchone() != (False, False, 5, 5, 1200, []):
                raise SystemExit('Generation settings changed from defaults; no update applied.')
            cursor.execute("""
                INSERT INTO public.real_english_topics
                  (slug,title,description,search_keyword,difficulty,is_active)
                VALUES ('coffee-conversation','Coffee conversation',
                        'Short everyday exchanges about coffee','coffee','A1',true)
                ON CONFLICT (slug) DO NOTHING
            """)
            cursor.execute("""
                SELECT difficulty,is_active FROM public.real_english_topics
                WHERE slug='coffee-conversation'
            """)
            if cursor.fetchone() != ('A1', True):
                raise RuntimeError('Trial topic conflicts with existing content.')
            cursor.execute("""
                UPDATE public.real_english_generation_settings SET
                  ai_generation_enabled=true, source_import_enabled=true,
                  daily_generation_target=1, maximum_daily_requests=1,
                  maximum_output_tokens=1200,
                  enabled_topics=ARRAY['coffee-conversation']::text[],
                  enabled_difficulty_levels=ARRAY['A1']::text[],
                  updated_at=now()
                WHERE id=true
            """)
            if cursor.rowcount != 1:
                raise RuntimeError('Generation settings row is missing.')
        if arguments.apply:
            connection.commit()
            print('COMMIT completed: one manual draft request per day; Cron unchanged')
        else:
            connection.rollback()
            print('ROLLBACK completed: trial configuration validated only')
    except BaseException:
        connection.rollback()
        raise
    finally:
        connection.close()


if __name__ == '__main__':
    main()
