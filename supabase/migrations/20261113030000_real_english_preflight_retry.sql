-- Record failures before a Gemini job is claimed. This lets the scheduler
-- move to another licensed topic and prevents endless source retries.
CREATE TABLE public.real_english_generation_preflights (
  idempotency_key text PRIMARY KEY CHECK (length(idempotency_key) BETWEEN 8 AND 160),
  generation_date date NOT NULL,
  topic_id uuid NOT NULL REFERENCES public.real_english_topics(id),
  slot integer NOT NULL CHECK (slot BETWEEN 0 AND 19),
  attempt_count integer NOT NULL DEFAULT 1 CHECK (attempt_count BETWEEN 1 AND 3),
  error_code text NOT NULL,
  error_message text NOT NULL,
  next_retry_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(generation_date,topic_id,slot)
);
CREATE INDEX real_english_preflights_retry_idx ON public.real_english_generation_preflights
  (generation_date,next_retry_at) WHERE attempt_count<3;
ALTER TABLE public.real_english_generation_preflights ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.real_english_generation_preflights TO authenticated,service_role;
CREATE POLICY real_english_preflights_admin_read ON public.real_english_generation_preflights
  FOR SELECT TO authenticated USING (public.englify_is_admin());

CREATE FUNCTION public.englify_record_real_english_preflight_failure(
  p_key text,p_topic_id uuid,p_slot integer,p_code text,p_message text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_day date := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
  v_attempts integer;
BEGIN
  IF p_topic_id IS NULL OR p_slot NOT BETWEEN 0 AND 19
    OR p_key IS DISTINCT FROM 'real-english:' || v_day::text || ':' || p_topic_id::text || ':' || p_slot::text
    OR p_code NOT IN ('source_timeout','source_network','source_rate_limited',
      'source_invalid_response','source_upstream','invalid_response','provider')
    OR nullif(btrim(coalesce(p_message,'')),'') IS NULL THEN
    RAISE EXCEPTION 'Invalid source preflight event' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.real_english_generation_preflights
    (idempotency_key,generation_date,topic_id,slot,error_code,error_message,next_retry_at)
  VALUES (p_key,v_day,p_topic_id,p_slot,p_code,left(p_message,180),now()+interval '10 minutes')
  ON CONFLICT (idempotency_key) DO UPDATE SET
    attempt_count=LEAST(public.real_english_generation_preflights.attempt_count+1,3),
    error_code=EXCLUDED.error_code,error_message=EXCLUDED.error_message,
    next_retry_at=now() + CASE public.real_english_generation_preflights.attempt_count
      WHEN 1 THEN interval '20 minutes' ELSE interval '45 minutes' END,
    updated_at=now()
  RETURNING attempt_count INTO v_attempts;
  PERFORM public.englify_refresh_real_english_batch(v_day);
  RETURN v_attempts;
END $$;
REVOKE ALL ON FUNCTION public.englify_record_real_english_preflight_failure(text,uuid,integer,text,text)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.englify_record_real_english_preflight_failure(text,uuid,integer,text,text)
  TO service_role;

CREATE OR REPLACE FUNCTION public.englify_refresh_real_english_batch(p_date date) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_target integer;
BEGIN
  SELECT daily_generation_target INTO v_target FROM public.real_english_generation_settings WHERE id=true;
  INSERT INTO public.real_english_generation_batches(generation_date,target_count)
  VALUES (p_date,coalesce(v_target,5)) ON CONFLICT (generation_date) DO NOTHING;
  UPDATE public.real_english_generation_batches b SET
    target_count=coalesce(v_target,5),
    success_count=(SELECT count(*)::integer FROM public.real_english_lessons l
      WHERE (l.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date
        AND l.generation_source='hybrid_ai' AND l.status IN ('pending_review','approved','published')),
    failure_count=(SELECT count(*)::integer FROM public.real_english_generation_jobs j
      WHERE (j.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date AND j.status IN ('failed','quota_blocked'))
      + (SELECT coalesce(sum(attempt_count),0)::integer FROM public.real_english_generation_preflights p
      WHERE p.generation_date=p_date),
    pending_count=(SELECT count(*)::integer FROM public.real_english_generation_jobs j
      WHERE (j.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date AND j.status IN ('queued','running')),
    latest_error=(SELECT e.message FROM (
      SELECT j.error_message AS message,coalesce(j.completed_at,j.created_at) AS happened_at
        FROM public.real_english_generation_jobs j
        WHERE (j.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date AND j.error_message IS NOT NULL
      UNION ALL
      SELECT p.error_message,p.updated_at FROM public.real_english_generation_preflights p
        WHERE p.generation_date=p_date
    ) e ORDER BY e.happened_at DESC LIMIT 1),
    completed_at=CASE WHEN (SELECT count(*) FROM public.real_english_lessons l
      WHERE (l.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date
        AND l.generation_source='hybrid_ai' AND l.status IN ('pending_review','approved','published')) >= coalesce(v_target,5)
      THEN coalesce(b.completed_at,now()) ELSE NULL END,
    updated_at=now()
  WHERE b.generation_date=p_date;
END $$;

SELECT public.englify_refresh_real_english_batch((now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date);
