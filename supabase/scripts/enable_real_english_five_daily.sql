-- Apply only after the editorial migration, five active topics, Edge quota secrets,
-- RLS checks and a successful manual generation. 00:00 UTC = 07:00 ICT.
-- One eligible slot is dispatched every 15 minutes through 12:45 ICT. Successful
-- slots are not repeated; failed slots back off and stop after three claims.
DO $$
DECLARE v_url text; v_anon text; v_secret text; v_timezone text;
BEGIN
  SELECT setting INTO v_timezone FROM pg_catalog.pg_settings WHERE name='cron.timezone';
  IF coalesce(v_timezone,'') NOT IN ('GMT','UTC','Etc/UTC') THEN
    RAISE EXCEPTION 'Check cron.timezone before scheduling for 07:00 ICT';
  END IF;
  SELECT decrypted_secret INTO v_url FROM vault.decrypted_secrets WHERE name='real_english_generate_url';
  SELECT decrypted_secret INTO v_anon FROM vault.decrypted_secrets WHERE name='real_english_cron_anon_jwt';
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name='real_english_cron_secret';
  IF v_url !~ '^https://[^/]+[.]supabase[.]co/functions/v1/real-english-generate$'
    OR v_anon IS NULL OR length(v_anon)<80 OR v_secret IS NULL OR length(v_secret)<32 THEN
    RAISE EXCEPTION 'Missing verified Cron Vault configuration';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.real_english_generation_settings s WHERE s.id=true
    AND s.ai_generation_enabled AND s.source_import_enabled AND s.daily_generation_target=5
    AND s.maximum_daily_requests>=5) THEN
    RAISE EXCEPTION 'Daily target and Free tier quota are not configured';
  END IF;
  IF (SELECT count(*) FROM public.real_english_topics t CROSS JOIN public.real_english_generation_settings s
    WHERE s.id=true AND t.is_active AND t.slug=ANY(s.enabled_topics)
      AND t.difficulty=ANY(s.enabled_difficulty_levels)) < 5 THEN
    RAISE EXCEPTION 'Enable at least five distinct topics first';
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname='englify-real-english-daily') THEN
    PERFORM cron.unschedule('englify-real-english-daily');
  END IF;
  PERFORM cron.schedule('englify-real-english-daily','*/15 0-5 * * *',$job$
    WITH today AS (SELECT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS day),
    settings AS (SELECT * FROM public.real_english_generation_settings WHERE id=true),
    available AS (
      SELECT t.id,t.search_keyword,t.difficulty,today.day,
        row_number() OVER (ORDER BY t.slug)-1 AS ordinal,
        count(*) OVER () AS topic_count
      FROM public.real_english_topics t CROSS JOIN settings s CROSS JOIN today
      WHERE s.ai_generation_enabled AND s.source_import_enabled AND t.is_active
        AND t.slug=ANY(s.enabled_topics) AND t.difficulty=ANY(s.enabled_difficulty_levels)
    ),
    ranked AS (
      SELECT a.id,a.search_keyword,a.difficulty,a.day,
        row_number() OVER (ORDER BY ((a.ordinal + extract(doy FROM a.day)::integer) % a.topic_count))-1 AS slot
      FROM available a
    ),
    selected AS (
      SELECT r.* FROM ranked r CROSS JOIN settings s
      LEFT JOIN public.real_english_generation_jobs j
        ON j.idempotency_key='real-english:' || r.day || ':' || r.id || ':' || r.slot
      LEFT JOIN public.real_english_generation_preflights p
        ON p.idempotency_key='real-english:' || r.day || ':' || r.id || ':' || r.slot
      WHERE r.slot<s.maximum_daily_requests
        AND (p.idempotency_key IS NULL OR (p.attempt_count<3 AND p.next_retry_at<=now()))
        AND (j.id IS NULL OR (j.status='failed' AND j.attempt_count<3
          AND j.completed_at<now() - (power(2,j.attempt_count)::integer * interval '5 minutes'))
          OR (j.status='running' AND j.lease_expires_at<now()))
        AND coalesce((SELECT b.success_count FROM public.real_english_generation_batches b
          WHERE b.generation_date=r.day),0)<s.daily_generation_target
        AND (SELECT coalesce(sum(attempt_count),0) FROM public.real_english_generation_jobs
          WHERE (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=r.day
            AND error_code IS DISTINCT FROM 'source_timeout')<s.maximum_daily_requests
      ORDER BY r.slot LIMIT 1
    )
    SELECT net.http_post(
      url:=(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='real_english_generate_url'),
      headers:=jsonb_build_object('Content-Type','application/json',
        'Authorization','Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='real_english_cron_anon_jwt'),
        'apikey',(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='real_english_cron_anon_jwt'),
        'x-englify-cron-secret',(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='real_english_cron_secret')),
      body:=jsonb_build_object('topicId',id,'keyword',search_keyword,'difficulty',difficulty,'slot',slot),
      timeout_milliseconds:=90000)
    FROM selected;
  $job$);
END $$;
