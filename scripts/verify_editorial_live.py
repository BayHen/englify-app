"""Read-only Real English production metadata check; never prints credentials."""

from __future__ import annotations

import psycopg
from deploy_hybrid_migrations import target_url


def main() -> None:
    with psycopg.connect(target_url(), connect_timeout=10,
                         options='-c statement_timeout=10000') as connection, connection.cursor() as cursor:
        cursor.execute("SELECT status,count(*) FROM public.real_english_lessons GROUP BY status ORDER BY status")
        print('lesson_status_counts=', cursor.fetchall())
        cursor.execute("SELECT count(*),count(DISTINCT l.topic_id),count(DISTINCT l.normalized_hash), "
                       "count(*) FILTER (WHERE EXISTS(SELECT 1 FROM public.real_english_phrases p "
                       "WHERE p.lesson_id=l.id AND p.is_active) "
                       "AND EXISTS(SELECT 1 FROM public.real_english_dialogues d "
                       "JOIN public.real_english_dialogue_lines line ON line.dialogue_id=d.id "
                       "WHERE d.lesson_id=l.id GROUP BY d.id HAVING count(*)>=2) "
                       "AND EXISTS(SELECT 1 FROM public.real_english_source_references r "
                       "WHERE r.lesson_id=l.id AND r.validation_status='eligible' "
                       "AND r.english_license IN ('CC0 1.0','CC BY 2.0 FR') "
                       "AND r.vietnamese_license IN ('CC0 1.0','CC BY 2.0 FR'))) "
                       "FROM public.real_english_lessons l "
                       "WHERE l.status='pending_review' AND l.generation_source='hybrid_ai' "
                       "AND (l.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date="
                       "(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date")
        print('today_pending_distinct_topics_hashes_complete=', cursor.fetchone())
        cursor.execute("SELECT status, count(*) FROM public.real_english_generation_jobs "
                       "WHERE (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date="
                       "(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date GROUP BY status ORDER BY status")
        print('today_job_status_counts=', cursor.fetchall())
        cursor.execute("SELECT target_count,success_count,failure_count,pending_count "
                       "FROM public.real_english_generation_batches "
                       "WHERE generation_date=(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date")
        print('today_batch=', cursor.fetchone())
        cursor.execute("SELECT daily_generation_target,maximum_daily_requests,maximum_output_tokens, "
                       "cardinality(enabled_topics),cardinality(enabled_difficulty_levels) "
                       "FROM public.real_english_generation_settings WHERE id=true")
        print('generation_settings=', cursor.fetchone())
        cursor.execute("SELECT name, setting FROM pg_catalog.pg_settings "
                       "WHERE name='cron.timezone'")
        print('cron_timezone=', cursor.fetchone())
        cursor.execute("SELECT jobname,schedule,active FROM cron.job "
                       "WHERE jobname='englify-real-english-daily'")
        print('cron_schedule=', cursor.fetchone())
        cursor.execute("SELECT has_function_privilege('authenticated', "
                       "'public.englify_review_real_english_lesson(uuid,text,text)','EXECUTE'), "
                       "has_function_privilege('anon', "
                       "'public.englify_review_real_english_lesson(uuid,text,text)','EXECUTE')")
        print('review_rpc_authenticated_anon=', cursor.fetchone())
        cursor.execute("SELECT has_function_privilege('authenticated', "
                       "'public.englify_save_real_english_lesson(uuid,text,text,jsonb)','EXECUTE'), "
                       "has_function_privilege('anon', "
                       "'public.englify_save_real_english_lesson(uuid,text,text,jsonb)','EXECUTE')")
        print('save_rpc_authenticated_anon=', cursor.fetchone())


if __name__ == '__main__':
    main()
