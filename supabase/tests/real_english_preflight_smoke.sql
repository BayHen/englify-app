-- Disposable PostgreSQL only, after preflight migration. Rolls back.
BEGIN;
INSERT INTO public.real_english_topics(id,slug,title,search_keyword,difficulty)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','source-test','Source test','hello','A1');
SET LOCAL ROLE service_role;
DO $$
DECLARE v_key text := 'real-english:' || (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
  || ':aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa:0'; v_result integer;
BEGIN
  v_result:=public.englify_record_real_english_preflight_failure(v_key,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'source_timeout','Tatoeba request timed out.');
  IF v_result<>1 THEN RAISE EXCEPTION 'First source attempt not logged'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.real_english_generation_preflights
    WHERE idempotency_key=v_key AND next_retry_at>now()) THEN
    RAISE EXCEPTION 'Source backoff missing';
  END IF;
  PERFORM public.englify_record_real_english_preflight_failure(v_key,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'source_timeout','Tatoeba request timed out.');
  v_result:=public.englify_record_real_english_preflight_failure(v_key,
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',0,'source_timeout','Tatoeba request timed out.');
  IF v_result<>3 OR (SELECT failure_count FROM public.real_english_generation_batches
    WHERE generation_date=(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)<>3 THEN
    RAISE EXCEPTION 'Bounded preflight retry or batch error count failed';
  END IF;
END $$;
RESET ROLE;
ROLLBACK;
