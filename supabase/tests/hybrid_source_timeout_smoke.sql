-- Run only on a disposable/local Supabase DB with the prior Admin migration.
-- Every DDL/DML statement is inside one transaction that always rolls back.
\set ON_ERROR_STOP on
BEGIN;
\i supabase/migrations/20261111010000_real_english_hybrid_foundation.sql
\i supabase/migrations/20261112010000_real_english_source_preflight.sql

UPDATE public.real_english_generation_settings
SET ai_generation_enabled=true,source_import_enabled=true,
    daily_generation_target=1,maximum_daily_requests=1,
    maximum_output_tokens=1200,enabled_topics=ARRAY['coffee'];
INSERT INTO public.real_english_topics(slug,title,search_keyword,difficulty)
VALUES ('coffee','Coffee','coffee','A1');
INSERT INTO public.real_english_generation_jobs
  (idempotency_key,status,scheduled_for,error_code,error_message,attempt_count)
VALUES ('real-english:smoke:coffee:0','failed',now(),'source_timeout','Tatoeba request timed out.',1);

SET LOCAL ROLE service_role;
DO $$ DECLARE v_claim uuid; BEGIN
  v_claim := public.englify_claim_real_english_job('real-english:smoke:coffee:0',now());
  IF v_claim IS NULL THEN RAISE EXCEPTION 'Source timeout wrongly consumed the Gemini slot'; END IF;
  BEGIN
    PERFORM public.englify_claim_real_english_job('real-english:smoke:coffee:1',now());
    RAISE EXCEPTION 'A second Gemini attempt was allowed';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL;
  END;
END $$;
ROLLBACK;
