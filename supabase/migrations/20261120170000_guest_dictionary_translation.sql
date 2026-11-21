-- Anonymous readers only see fields used by the published vocabulary search.
GRANT SELECT (id, term, definition, translation, ipa, part_of_speech, example, audio_url,
  source_name, license_id, language, is_published, archived_at, normalized_term)
  ON public.dictionary_entries TO anon;
CREATE POLICY dictionary_guest_read ON public.dictionary_entries FOR SELECT TO anon
  USING (language = 'en' AND is_published AND archived_at IS NULL);

ALTER TABLE public.translation_usage DROP CONSTRAINT translation_usage_scope_check;
ALTER TABLE public.translation_usage ADD CONSTRAINT translation_usage_scope_check
  CHECK (scope IN ('user_minute', 'user_day', 'global_month', 'global_day', 'guest_day'));

CREATE FUNCTION public.englify_reserve_guest_translation(p_characters integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_day timestamptz := date_trunc('day', transaction_timestamp() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
  v_month timestamptz := date_trunc('month', transaction_timestamp() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
  v_global uuid := '00000000-0000-0000-0000-000000000000';
BEGIN
  IF p_characters IS NULL OR p_characters NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'Invalid translation length' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('englify:translation:global'));
  IF EXISTS (
    SELECT 1 FROM public.translation_usage u WHERE u.subject = v_global AND (
      (u.scope = 'guest_day' AND u.bucket = v_day AND (u.character_count + p_characters > 900 OR u.request_count >= 40))
      OR (u.scope = 'global_day' AND u.bucket = v_day AND (u.character_count + p_characters > 4500 OR u.request_count >= 200))
      OR (u.scope = 'global_month' AND u.bucket = v_month AND (u.character_count + p_characters > 400000 OR u.request_count >= 10000))
    )
  ) THEN
    RAISE EXCEPTION 'Translation quota reached' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO public.translation_usage(scope, bucket, subject, request_count, character_count)
  VALUES ('guest_day', v_day, v_global, 1, p_characters), ('global_day', v_day, v_global, 1, p_characters),
    ('global_month', v_month, v_global, 1, p_characters)
  ON CONFLICT (scope, bucket, subject) DO UPDATE
    SET request_count = public.translation_usage.request_count + 1,
        character_count = public.translation_usage.character_count + EXCLUDED.character_count;
END $$;
REVOKE ALL ON FUNCTION public.englify_reserve_guest_translation(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.englify_reserve_guest_translation(integer) TO service_role;
