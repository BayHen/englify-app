-- Requires hybrid_smoke_setup.sql in a disposable database. Rolls back all sample data.
BEGIN;
GRANT USAGE ON SCHEMA auth TO authenticated,anon;
INSERT INTO auth.users (id) VALUES
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');
INSERT INTO public.admin_members (user_id) VALUES ('11111111-1111-4111-8111-111111111111');
INSERT INTO public.real_english_topics (id,slug,title,search_keyword,difficulty)
VALUES ('33333333-3333-4333-8333-333333333333','coffee','Coffee','coffee','A1');
INSERT INTO public.real_english_lessons (id,topic_id,title,description,content_type,difficulty,status,normalized_hash)
VALUES ('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333',
  'Coffee in context','Practice a request','expression','A1','in_review',repeat('a',64));
INSERT INTO public.real_english_phrases (lesson_id,english_text,vietnamese_translation,normalized_hash)
VALUES ('44444444-4444-4444-8444-444444444444','Coffee, please.','Cho tôi cà phê.',repeat('b',64));

SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.real_english_lessons WHERE id='44444444-4444-4444-8444-444444444444') THEN
    RAISE EXCEPTION 'Learner saw a draft';
  END IF;
  IF EXISTS (SELECT 1 FROM public.real_english_phrases WHERE lesson_id='44444444-4444-4444-8444-444444444444') THEN
    RAISE EXCEPTION 'Learner saw draft content';
  END IF;
  IF EXISTS (SELECT 1 FROM public.real_english_generation_settings) THEN
    RAISE EXCEPTION 'Learner saw private settings';
  END IF;
  BEGIN
    INSERT INTO public.real_english_lessons (topic_id,title,content_type,difficulty,normalized_hash)
    VALUES ('33333333-3333-4333-8333-333333333333','Unauthorized lesson','expression','A1',repeat('c',64));
    RAISE EXCEPTION 'Learner created an editorial lesson';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE public.real_english_lessons SET status='published' WHERE id='44444444-4444-4444-8444-444444444444';
  IF FOUND THEN RAISE EXCEPTION 'Learner modified a draft'; END IF;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
UPDATE public.real_english_lessons SET status='approved' WHERE id='44444444-4444-4444-8444-444444444444';
UPDATE public.real_english_lessons SET status='published' WHERE id='44444444-4444-4444-8444-444444444444';
DO $$ BEGIN
  IF (SELECT count(*) FROM public.real_english_review_history WHERE lesson_id='44444444-4444-4444-8444-444444444444')<>2 THEN
    RAISE EXCEPTION 'Review audit missing';
  END IF;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.real_english_lessons WHERE id='44444444-4444-4444-8444-444444444444') THEN
    RAISE EXCEPTION 'Published lesson invisible';
  END IF;
END $$;
INSERT INTO public.real_english_user_progress (user_id,lesson_id,status,is_bookmarked)
VALUES ('22222222-2222-4222-8222-222222222222','44444444-4444-4444-8444-444444444444','in_progress',true);
UPDATE public.real_english_user_progress SET status='completed'
WHERE user_id='22222222-2222-4222-8222-222222222222';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.real_english_user_progress WHERE status='completed' AND completed_at IS NOT NULL) THEN
    RAISE EXCEPTION 'Completion did not persist';
  END IF;
  BEGIN
    UPDATE public.real_english_user_progress SET status='in_progress';
    RAISE EXCEPTION 'Completed history was erased';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM public.real_english_user_progress WHERE user_id='22222222-2222-4222-8222-222222222222') THEN
    RAISE EXCEPTION 'Cross-user progress visible';
  END IF;
  UPDATE public.real_english_user_progress SET is_bookmarked=false
    WHERE user_id='22222222-2222-4222-8222-222222222222';
  IF FOUND THEN RAISE EXCEPTION 'Cross-user progress was modified'; END IF;
END $$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN
  BEGIN
    PERFORM 1 FROM public.real_english_lessons;
    RAISE EXCEPTION 'Anonymous read lesson data';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;
ROLLBACK;
