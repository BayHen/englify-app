-- Run manually only after migration, provider, RLS, admin/mobile, and repeat-job gates pass.
-- Required Vault entries: real_english_generate_url (full HTTPS Edge Function URL),
-- real_english_cron_anon_jwt (legacy anon JWT for Edge gateway verification),
-- real_english_cron_secret (same random value as Edge REAL_ENGLISH_CRON_SECRET).
-- The anonymous JWT is never a service-role credential; the second secret authorizes Cron.
DO $$
DECLARE v_url text; v_anon text; v_secret text; v_timezone text;
BEGIN
  SELECT setting INTO v_timezone FROM pg_catalog.pg_settings WHERE name='cron.timezone';
  IF coalesce(v_timezone,'') NOT IN ('GMT','UTC','Etc/UTC') THEN
    RAISE EXCEPTION 'Check cron.timezone before scheduling for 07:00 Asia/Ho_Chi_Minh';
  END IF;
  SELECT decrypted_secret INTO v_url FROM vault.decrypted_secrets WHERE name='real_english_generate_url';
  SELECT decrypted_secret INTO v_anon FROM vault.decrypted_secrets WHERE name='real_english_cron_anon_jwt';
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name='real_english_cron_secret';
  IF v_url !~ '^https://[^/]+[.]supabase[.]co/functions/v1/real-english-generate$'
    OR v_anon IS NULL OR length(v_anon)<80 OR v_secret IS NULL OR length(v_secret)<32 THEN
    RAISE EXCEPTION 'Missing verified Cron Vault configuration';
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname='englify-real-english-daily') THEN
    RAISE EXCEPTION 'Real English Cron already exists; inspect it before changing schedule';
  END IF;
  PERFORM cron.schedule('englify-real-english-daily','0 0 * * *',$job$
    WITH picked AS (
      SELECT t.id,t.search_keyword,t.difficulty,
        row_number() OVER (ORDER BY t.slug)-1 AS slot
      FROM public.real_english_topics t CROSS JOIN public.real_english_generation_settings s
      WHERE s.id=true AND s.ai_generation_enabled AND s.source_import_enabled
        AND t.is_active AND t.slug=ANY(s.enabled_topics)
        AND t.difficulty=ANY(s.enabled_difficulty_levels)
      ORDER BY t.slug
      LIMIT (SELECT daily_generation_target FROM public.real_english_generation_settings WHERE id=true)
    )
    SELECT net.http_post(
      url:=(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='real_english_generate_url'),
      headers:=jsonb_build_object('Content-Type','application/json',
        'Authorization','Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='real_english_cron_anon_jwt'),
        'apikey',(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='real_english_cron_anon_jwt'),
        'x-englify-cron-secret',(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='real_english_cron_secret')),
      body:=jsonb_build_object('topicId',id,'keyword',search_keyword,'difficulty',difficulty,'slot',slot),
      -- Tatoeba source lookup can take 30 seconds; generation and validation need time too.
      timeout_milliseconds:=90000)
    FROM picked;
  $job$);
END $$;
