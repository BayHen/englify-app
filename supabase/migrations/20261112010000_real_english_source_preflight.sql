-- Source lookup must not consume the one daily Gemini attempt.
-- Classify only legacy failed jobs that were known to stop before Gemini.
UPDATE public.real_english_generation_jobs
SET error_code='source_timeout'
WHERE status='failed' AND error_code='provider'
  AND error_message='Tatoeba request timed out.';

CREATE OR REPLACE FUNCTION public.englify_claim_real_english_job(p_key text, p_scheduled_for timestamptz)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_settings public.real_english_generation_settings%ROWTYPE;
  v_job public.real_english_generation_jobs%ROWTYPE;
  v_today date := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
BEGIN
  SELECT * INTO v_settings FROM public.real_english_generation_settings WHERE id=true FOR UPDATE;
  IF NOT v_settings.ai_generation_enabled OR NOT v_settings.source_import_enabled THEN
    RAISE EXCEPTION 'Generation disabled' USING ERRCODE='42501';
  END IF;
  IF p_key IS NULL OR length(p_key) NOT BETWEEN 8 AND 160 OR p_scheduled_for IS NULL THEN
    RAISE EXCEPTION 'Invalid generation job' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_job FROM public.real_english_generation_jobs WHERE idempotency_key=p_key FOR UPDATE;
  IF FOUND THEN
    IF v_job.status='failed' OR (v_job.status='running' AND v_job.lease_expires_at < now()) THEN
      IF (SELECT coalesce(sum(attempt_count),0) FROM public.real_english_generation_jobs
          WHERE (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=v_today
            AND error_code IS DISTINCT FROM 'source_timeout') >= v_settings.maximum_daily_requests THEN
        RAISE EXCEPTION 'Daily generation request limit reached' USING ERRCODE='P0001';
      END IF;
      UPDATE public.real_english_generation_jobs SET status='running',started_at=now(),lease_expires_at=now()+interval '2 minutes',
        attempt_count=attempt_count+1,error_code=NULL,error_message=NULL WHERE id=v_job.id;
      RETURN v_job.id;
    END IF;
    RETURN NULL;
  END IF;
  IF (SELECT coalesce(sum(attempt_count),0) FROM public.real_english_generation_jobs
      WHERE (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=v_today
        AND error_code IS DISTINCT FROM 'source_timeout') >= v_settings.maximum_daily_requests THEN
    RAISE EXCEPTION 'Daily generation request limit reached' USING ERRCODE='P0001';
  END IF;
  INSERT INTO public.real_english_generation_jobs
    (idempotency_key,scheduled_for,status,started_at,lease_expires_at)
  VALUES (p_key,p_scheduled_for,'running',now(),now()+interval '2 minutes') RETURNING id INTO v_job.id;
  RETURN v_job.id;
END $$;
