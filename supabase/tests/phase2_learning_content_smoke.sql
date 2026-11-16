-- Run only against a disposable Supabase database after db reset.
BEGIN;
INSERT INTO auth.users(id) VALUES ('91111111-1111-4111-8111-111111111111'),('92222222-2222-4222-8222-222222222222');
INSERT INTO public.admin_members(user_id) VALUES ('91111111-1111-4111-8111-111111111111');

SELECT set_config('request.jwt.claim.sub','91111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
INSERT INTO public.real_english_topics(id,slug,title,search_keyword,difficulty)
VALUES('93333333-3333-4333-8333-333333333333','phase-two-topic','Phase two topic','greeting','A1');
INSERT INTO public.real_english_lessons(id,topic_id,title,description,content_type,difficulty,status,generation_source,normalized_hash,created_by)
VALUES('94444444-4444-4444-8444-444444444444','93333333-3333-4333-8333-333333333333','A friendly greeting','Practice a short greeting.','dialogue','A1','draft','human',repeat('a',64),'91111111-1111-4111-8111-111111111111');
INSERT INTO public.real_english_phrases(id,lesson_id,english_text,vietnamese_translation,formality,usage_context,normalized_hash)
VALUES('95555555-5555-4555-8555-555555555555','94444444-4444-4444-8444-444444444444','Hello there','Xin chào','neutral','Meeting a classmate',repeat('b',64));
INSERT INTO public.real_english_dialogues(id,lesson_id,title,context)
VALUES('95666666-6666-4666-8666-666666666666','94444444-4444-4444-8444-444444444444','Meeting a classmate','An original beginner dialogue.');
INSERT INTO public.real_english_dialogue_lines(id,dialogue_id,speaker,english_text,vietnamese_translation,sort_order)
VALUES
('95777777-7777-4777-8777-777777777771','95666666-6666-4666-8666-666666666666','Mai','Hello there.','Xin chào.',0),
('95777777-7777-4777-8777-777777777772','95666666-6666-4666-8666-666666666666','Nam','Hello, Mai.','Xin chào Mai.',1);
INSERT INTO public.real_english_comprehension_questions(id,lesson_id,position,prompt,options,explanation,is_published)
VALUES('96666666-6666-4666-8666-666666666666','94444444-4444-4444-8444-444444444444',1,'Which phrase is a greeting?',
  '[{"id":"a","text":"Hello there"},{"id":"b","text":"Close the window"}]','Hello there is a greeting.',true);
INSERT INTO public.real_english_comprehension_keys(question_id,answer_id)
VALUES('96666666-6666-4666-8666-666666666666','a');
UPDATE public.real_english_lessons SET status='in_review' WHERE id='94444444-4444-4444-8444-444444444444';
UPDATE public.real_english_lessons SET status='approved' WHERE id='94444444-4444-4444-8444-444444444444';
UPDATE public.real_english_lessons SET status='published' WHERE id='94444444-4444-4444-8444-444444444444';

SELECT set_config('request.jwt.claim.sub','92222222-2222-4222-8222-222222222222',true);
DO $$ DECLARE v_search jsonb; v_progress jsonb; v_answer jsonb; BEGIN
  v_search:=public.englify_search_real_english('xin chao','A1','phase-two-topic','dialogue',false,1,5);
  IF (v_search->>'total')::integer<>1 OR v_search#>>'{items,0,id}'<>'94444444-4444-4444-8444-444444444444' THEN
    RAISE EXCEPTION 'server-side accent-insensitive search/filter failed';
  END IF;
  v_search:=public.englify_search_real_english('',NULL,NULL,NULL,false,1,5);
  IF jsonb_array_length(v_search->'items')>5 OR (v_search->>'total')::integer<6 THEN
    RAISE EXCEPTION 'server-side pagination failed';
  END IF;
  v_progress:=public.englify_record_real_english_reading('94444444-4444-4444-8444-444444444444','open',25,false);
  IF v_progress->>'status'<>'reading' OR (v_progress->>'reading_percent')::integer<>25 THEN RAISE EXCEPTION 'reading progress failed'; END IF;
  v_answer:=public.englify_submit_real_english_comprehension('94444444-4444-4444-8444-444444444444',
    '96666666-6666-4666-8666-666666666666','97777777-7777-4777-8777-777777777777','a');
  IF NOT (v_answer->>'is_correct')::boolean OR v_answer->>'progress_status'<>'passed' THEN RAISE EXCEPTION 'comprehension progress failed'; END IF;
  PERFORM public.englify_submit_real_english_comprehension('94444444-4444-4444-8444-444444444444',
    '96666666-6666-4666-8666-666666666666','97777777-7777-4777-8777-777777777777','b');
END $$;

DO $$ BEGIN
  BEGIN
    INSERT INTO public.saved_vocabulary(user_id,entry_id,next_review_at,review_count)
    VALUES('92222222-2222-4222-8222-222222222222','11111111-1111-4111-8111-111111111101',now()-interval '1 day',999);
    RAISE EXCEPTION 'learner manipulated review scheduling';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
INSERT INTO public.saved_vocabulary(user_id,entry_id)
VALUES('92222222-2222-4222-8222-222222222222','11111111-1111-4111-8111-111111111101');
DO $$ DECLARE v_due jsonb; v_first jsonb; v_retry jsonb; BEGIN
  v_due:=public.englify_due_vocabulary(20);
  IF jsonb_array_length(v_due)<>1 OR v_due#>>'{0,term}'<>'curious' THEN RAISE EXCEPTION 'due vocabulary query failed'; END IF;
  v_first:=public.englify_review_vocabulary((v_due#>>'{0,id}')::uuid,3,'99999999-9999-4999-8999-999999999999');
  v_retry:=public.englify_review_vocabulary((v_due#>>'{0,id}')::uuid,1,'99999999-9999-4999-8999-999999999999');
  IF v_first<>v_retry OR (v_first->>'review_count')::integer<>1 THEN RAISE EXCEPTION 'vocabulary review idempotency failed'; END IF;
END $$;

DO $$ BEGIN
  BEGIN
    INSERT INTO public.content_import_batches(actor_id,content_type,source_name,license_id,idempotency_key)
    VALUES('92222222-2222-4222-8222-222222222222','vocabulary','Untrusted','unknown','learner-import');
    RAISE EXCEPTION 'learner created an import batch';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;

RESET ROLE;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.real_english_comprehension_attempts WHERE user_id='92222222-2222-4222-8222-222222222222')<>1 THEN
    RAISE EXCEPTION 'duplicate comprehension submission created multiple attempts';
  END IF;
  IF (SELECT count(*) FROM public.review_history WHERE user_id='92222222-2222-4222-8222-222222222222')<>1 THEN
    RAISE EXCEPTION 'duplicate vocabulary review created multiple history rows';
  END IF;
END $$;
ROLLBACK;
