-- Disposable PostgreSQL only, after both editorial migrations. Rolls back.
BEGIN;
INSERT INTO public.real_english_topics(id,slug,title,search_keyword,difficulty)
VALUES ('77777777-7777-4777-8777-777777777777','batch-test','Batch test','hello','A1');
INSERT INTO public.real_english_lessons(id,topic_id,title,description,content_type,difficulty,status,
  generation_source,normalized_hash)
VALUES ('88888888-8888-4888-8888-888888888888','77777777-7777-4777-8777-777777777777',
  'Archived today','Archived content','dialogue','A1','archived','hybrid_ai',repeat('e',64)),
  ('99999999-9999-4999-8999-999999999999','77777777-7777-4777-8777-777777777777',
  'Reviewable today','Reviewable content','dialogue','A1','pending_review','hybrid_ai',repeat('f',64));
DO $$ BEGIN
  IF (SELECT success_count FROM public.real_english_generation_batches
    WHERE generation_date=(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)<>1 THEN
    RAISE EXCEPTION 'Archived lesson incorrectly counted toward target';
  END IF;
END $$;
UPDATE public.real_english_lessons SET status='archived'
WHERE id='99999999-9999-4999-8999-999999999999';
DO $$ BEGIN
  IF (SELECT success_count FROM public.real_english_generation_batches
    WHERE generation_date=(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)<>0 THEN
    RAISE EXCEPTION 'Archiving did not release daily target slot';
  END IF;
END $$;
ROLLBACK;
