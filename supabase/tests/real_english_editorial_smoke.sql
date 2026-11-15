-- Run ONLY after hybrid_smoke_setup.sql, source_preflight and editorial migration
-- in a disposable PostgreSQL database. All test content is rolled back.
BEGIN;
GRANT USAGE ON SCHEMA auth TO authenticated,anon;
INSERT INTO auth.users(id) VALUES
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');
INSERT INTO public.admin_members(user_id) VALUES ('11111111-1111-4111-8111-111111111111');
INSERT INTO public.real_english_topics(id,slug,title,search_keyword,difficulty)
VALUES ('33333333-3333-4333-8333-333333333333','coffee','Coffee','coffee','A1');
INSERT INTO public.real_english_lessons(id,topic_id,title,description,content_type,difficulty,status,
  generation_source,normalized_hash)
VALUES ('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333',
  'Ordering coffee','Practice a polite request','dialogue','A1','archived','hybrid_ai',repeat('a',64)),
  ('55555555-5555-4555-8555-555555555555','33333333-3333-4333-8333-333333333333',
  'Incomplete draft','Needs activities','dialogue','A1','pending_review','human',repeat('c',64));
INSERT INTO public.real_english_phrases(lesson_id,english_text,vietnamese_translation,normalized_hash)
VALUES ('44444444-4444-4444-8444-444444444444','Coffee, please.','Cho tôi cà phê.',repeat('b',64));
INSERT INTO public.real_english_dialogues(id,lesson_id,title)
VALUES ('66666666-6666-4666-8666-666666666666','44444444-4444-4444-8444-444444444444','At a cafe');
INSERT INTO public.real_english_dialogue_lines(dialogue_id,speaker,english_text,vietnamese_translation,sort_order)
VALUES ('66666666-6666-4666-8666-666666666666','A','Coffee, please.','Cho tôi cà phê.',0),
  ('66666666-6666-4666-8666-666666666666','B','Certainly.','Chắc chắn rồi.',1);
INSERT INTO public.real_english_source_references(lesson_id,source_sentence_id,translation_sentence_id,
  english_text,vietnamese_text,english_contributor,vietnamese_contributor,english_license,vietnamese_license,
  source_url,translation_url,attribution_text,content_hash,validation_status)
VALUES ('44444444-4444-4444-8444-444444444444',101,202,'Coffee, please.','Cho tôi cà phê.',
  'author_en','author_vi','CC BY 2.0 FR','CC BY 2.0 FR',
  'https://api.tatoeba.org/v1/sentences/101','https://api.tatoeba.org/v1/sentences/202',
  'Tatoeba contributors author_en / author_vi, CC BY 2.0 FR',repeat('d',64),'eligible');

SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM public.real_english_lessons WHERE status IN ('archived','pending_review')) THEN
    RAISE EXCEPTION 'Learner saw unpublished content';
  END IF;
  BEGIN
    PERFORM public.englify_review_real_english_lesson(
      '44444444-4444-4444-8444-444444444444','restore','');
    RAISE EXCEPTION 'Learner restored a lesson';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
SELECT (public.englify_review_real_english_lesson(
  '44444444-4444-4444-8444-444444444444','restore','')).status;
SELECT (public.englify_save_real_english_lesson(
  '44444444-4444-4444-8444-444444444444','Ordering coffee','Practice a polite request',
  jsonb_build_array(
    jsonb_build_object('id',(SELECT id FROM public.real_english_phrases
      WHERE lesson_id='44444444-4444-4444-8444-444444444444'),
      'englishText','Coffee, please.','vietnameseTranslation','Cho tôi cà phê.',
      'formality','neutral','usageContext','At a cafe','isActive',false),
    jsonb_build_object('englishText','A coffee, please.','vietnameseTranslation','Một ly cà phê, làm ơn.',
      'formality','neutral','usageContext','At a cafe','isActive',true)))).status;
DO $$ BEGIN
  IF (SELECT status FROM public.real_english_lessons WHERE id='44444444-4444-4444-8444-444444444444')<>'pending_review' THEN
    RAISE EXCEPTION 'Archived lesson did not return to review';
  END IF;
  BEGIN
    PERFORM public.englify_review_real_english_lesson(
      '55555555-5555-4555-8555-555555555555','approve_publish','');
    RAISE EXCEPTION 'Incomplete lesson published';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;
  IF (SELECT status FROM public.real_english_lessons WHERE id='55555555-5555-4555-8555-555555555555')<>'pending_review' THEN
    RAISE EXCEPTION 'Failed publish left a partial approval';
  END IF;
END $$;
SELECT (public.englify_review_real_english_lesson(
  '44444444-4444-4444-8444-444444444444','approve_publish','Ready')).status;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.real_english_lessons WHERE id='44444444-4444-4444-8444-444444444444'
    AND status='published' AND reviewed_by='11111111-1111-4111-8111-111111111111'
    AND published_by='11111111-1111-4111-8111-111111111111' AND published_at IS NOT NULL) THEN
    RAISE EXCEPTION 'Publication metadata is incomplete';
  END IF;
  IF (SELECT count(*) FROM public.real_english_review_history WHERE lesson_id='44444444-4444-4444-8444-444444444444')<>3 THEN
    RAISE EXCEPTION 'Restore, approval or publication audit is missing';
  END IF;
  IF (SELECT count(*) FROM public.real_english_phrases WHERE lesson_id='44444444-4444-4444-8444-444444444444')<>2 THEN
    RAISE EXCEPTION 'Editorial expression history was lost';
  END IF;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM public.real_english_lessons WHERE id='44444444-4444-4444-8444-444444444444') THEN
    RAISE EXCEPTION 'Published lesson invisible to learner';
  END IF;
  IF EXISTS(SELECT 1 FROM public.real_english_lessons WHERE id='55555555-5555-4555-8555-555555555555') THEN
    RAISE EXCEPTION 'Incomplete lesson visible to learner';
  END IF;
  IF (SELECT count(*) FROM public.real_english_phrases WHERE lesson_id='44444444-4444-4444-8444-444444444444')<>1 THEN
    RAISE EXCEPTION 'Learner saw a removed expression';
  END IF;
END $$;
RESET ROLE;
ROLLBACK;
