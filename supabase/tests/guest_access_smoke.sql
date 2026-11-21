BEGIN;

DO $$
BEGIN
  IF has_table_privilege('anon', 'public.saved_vocabulary', 'SELECT')
    OR has_function_privilege('anon', 'public.englify_reserve_translation(integer)', 'EXECUTE')
    OR has_function_privilege('anon', 'public.englify_reserve_guest_translation(integer)', 'EXECUTE')
    OR has_function_privilege('authenticated', 'public.englify_reserve_guest_translation(integer)', 'EXECUTE')
    OR NOT has_function_privilege('service_role', 'public.englify_reserve_guest_translation(integer)', 'EXECUTE')
  THEN
    RAISE EXCEPTION 'Unexpected guest or quota permissions';
  END IF;
END $$;

SET LOCAL ROLE anon;
SELECT id, term, definition, translation, ipa, part_of_speech, example, audio_url, source_name, license_id
  FROM public.dictionary_entries WHERE language = 'en' AND is_published AND archived_at IS NULL
  ORDER BY normalized_term LIMIT 1;
DO $$
BEGIN
  IF EXISTS (SELECT id FROM public.dictionary_entries WHERE NOT is_published OR archived_at IS NOT NULL OR language <> 'en') THEN
    RAISE EXCEPTION 'Guest vocabulary policy exposed a private entry';
  END IF;
END $$;
RESET ROLE;

CREATE TEMP TABLE guest_usage_before AS
  SELECT coalesce(sum(request_count), 0) AS requests
  FROM public.translation_usage WHERE scope = 'guest_day'
    AND bucket = date_trunc('day', transaction_timestamp() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';

SET LOCAL ROLE service_role;
DO $$
BEGIN
  BEGIN
    PERFORM public.englify_reserve_guest_translation(0);
    RAISE EXCEPTION 'Invalid quota input accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
END $$;
SELECT public.englify_reserve_guest_translation(1);
RESET ROLE;

DO $$
BEGIN
  IF (SELECT coalesce(sum(request_count), 0) FROM public.translation_usage
      WHERE scope = 'guest_day' AND bucket = date_trunc('day', transaction_timestamp() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC')
      <> (SELECT requests + 1 FROM guest_usage_before) THEN
    RAISE EXCEPTION 'Guest quota did not reserve a request';
  END IF;
END $$;

ROLLBACK;
