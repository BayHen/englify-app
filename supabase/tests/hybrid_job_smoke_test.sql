-- Requires hybrid_smoke_setup.sql on a disposable PostgreSQL database.
BEGIN;
INSERT INTO public.real_english_topics (id,slug,title,search_keyword,difficulty)
VALUES ('33333333-3333-4333-8333-333333333333','coffee','Coffee','coffee','A1');
UPDATE public.real_english_generation_settings
SET ai_generation_enabled=true,source_import_enabled=true,maximum_daily_requests=2,
  enabled_topics=ARRAY['coffee'],maximum_output_tokens=500 WHERE id=true;
SET LOCAL ROLE service_role;
SELECT public.englify_claim_real_english_job('real-english:smoke:coffee:0',now()) AS job_id \gset
DO $$ BEGIN
  IF public.englify_claim_real_english_job('real-english:smoke:coffee:0',now()) IS NOT NULL THEN
    RAISE EXCEPTION 'Duplicate job was claimed';
  END IF;
END $$;
SELECT public.englify_store_real_english_draft(
  :'job_id'::uuid,
  '33333333-3333-4333-8333-333333333333'::uuid,
  jsonb_build_object('title','Coffee in context','description','Practice a request',
    'contentType','expression','difficulty','A1','expression','Coffee, please.',
    'meaningVi','Cho tôi cà phê.','formality','neutral','usageContext','At a cafe.',
    'dialogue',jsonb_build_array(
      jsonb_build_object('speaker','A','englishText','Coffee, please.','vietnameseTranslation','Cho tôi cà phê.'),
      jsonb_build_object('speaker','B','englishText','Of course.','vietnameseTranslation','Được chứ.'))),
  jsonb_build_object('englishId',101,'vietnameseId',202,'englishText','Coffee, please.',
    'vietnameseText','Cho tôi cà phê.','englishContributor','author_en',
    'vietnameseContributor','author_vi','englishLicense','CC BY 2.0 FR',
    'vietnameseLicense','CC BY 2.0 FR','sourceUrl','https://api.tatoeba.org/v1/sentences/101',
    'translationUrl','https://api.tatoeba.org/v1/sentences/202','validationStatus','eligible')) AS lesson_id \gset
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.real_english_lessons WHERE status='in_review')
    OR NOT EXISTS (SELECT 1 FROM public.real_english_source_references WHERE validation_status='eligible')
    OR NOT EXISTS (SELECT 1 FROM public.real_english_generation_jobs WHERE status='completed') THEN
    RAISE EXCEPTION 'Atomic draft insertion incomplete';
  END IF;
  IF public.englify_claim_real_english_job('real-english:smoke:coffee:0',now()) IS NOT NULL THEN
    RAISE EXCEPTION 'Completed job was claimed again';
  END IF;
END $$;
SELECT public.englify_claim_real_english_job('real-english:smoke:coffee:1',now()) AS second_job \gset
DO $$ BEGIN
  BEGIN
    PERFORM public.englify_claim_real_english_job('real-english:smoke:coffee:2',now());
    RAISE EXCEPTION 'Quota did not block third request';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL;
  END;
END $$;
RESET ROLE;
ROLLBACK;
