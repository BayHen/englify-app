-- MyMemory anonymous allowance is shared by Edge egress IP. Reserve a conservative
-- project-wide daily budget as well as the existing user rate limit. No text is stored.
ALTER TABLE public.translation_usage DROP CONSTRAINT translation_usage_scope_check;
ALTER TABLE public.translation_usage ADD CONSTRAINT translation_usage_scope_check
  CHECK (scope IN ('user_minute', 'user_day', 'global_month', 'global_day'));

CREATE OR REPLACE FUNCTION public.englify_reserve_translation(p_characters integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_now timestamptz := transaction_timestamp();
  v_minute timestamptz := date_trunc('minute', v_now);
  v_day timestamptz := date_trunc('day', v_now AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
  v_month timestamptz := date_trunc('month', v_now AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
  v_global uuid := '00000000-0000-0000-0000-000000000000'::uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_characters IS NULL OR p_characters NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'Translation text must contain 1-500 characters' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('englify:translation:global'));
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('englify:translation:' || v_uid::text));
  IF EXISTS (
    SELECT 1 FROM public.translation_usage u
    WHERE u.scope = 'global_day' AND u.bucket = v_day AND u.subject = v_global
      AND (u.character_count + p_characters > 4500 OR u.request_count >= 200)
  ) OR EXISTS (
    SELECT 1 FROM public.translation_usage u
    WHERE u.scope = 'global_month' AND u.bucket = v_month AND u.subject = v_global
      AND (u.character_count + p_characters > 400000 OR u.request_count >= 10000)
  ) OR EXISTS (
    SELECT 1 FROM public.translation_usage u
    WHERE u.scope = 'user_day' AND u.bucket = v_day AND u.subject = v_uid
      AND (u.character_count + p_characters > 4500 OR u.request_count >= 50)
  ) OR EXISTS (
    SELECT 1 FROM public.translation_usage u
    WHERE u.scope = 'user_minute' AND u.bucket = v_minute AND u.subject = v_uid
      AND u.request_count >= 10
  ) THEN
    RAISE EXCEPTION 'Translation quota reached' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO public.translation_usage(scope,bucket,subject,request_count,character_count)
  VALUES ('global_day',v_day,v_global,1,p_characters),
         ('global_month',v_month,v_global,1,p_characters),
         ('user_day',v_day,v_uid,1,p_characters),
         ('user_minute',v_minute,v_uid,1,p_characters)
  ON CONFLICT (scope,bucket,subject) DO UPDATE
    SET request_count = public.translation_usage.request_count + 1,
        character_count = public.translation_usage.character_count + EXCLUDED.character_count;
END $$;
REVOKE ALL ON FUNCTION public.englify_reserve_translation(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_reserve_translation(integer) TO authenticated;