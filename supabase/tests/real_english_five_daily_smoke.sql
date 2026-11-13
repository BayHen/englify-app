-- Disposable database only. Mock Tatoeba/Gemini payloads exercise the real SQL
-- claim/store/batch path without calling external services. Rolls back.
BEGIN;
UPDATE public.real_english_generation_settings SET ai_generation_enabled=true,
  source_import_enabled=true,daily_generation_target=5,maximum_daily_requests=5,
  maximum_output_tokens=500 WHERE id=true;
SET LOCAL ROLE service_role;
DO $$
DECLARE v_topic uuid; v_job uuid; v_lesson uuid; v_index integer;
BEGIN
  FOR v_index IN 1..5 LOOP
    INSERT INTO public.real_english_topics(slug,title,search_keyword,difficulty)
    VALUES ('daily-' || v_index,'Daily topic ' || v_index,'hello','A1') RETURNING id INTO v_topic;
    v_job:=public.englify_claim_real_english_job('real-english:smoke:slot:' || v_index,now());
    IF v_job IS NULL THEN RAISE EXCEPTION 'A distinct slot was not claimed'; END IF;
    v_lesson:=public.englify_store_real_english_draft(v_job,v_topic,
      jsonb_build_object('title','Lesson ' || v_index,'description','Practice a daily conversation',
        'contentType','dialogue','difficulty','A1','expression','Hello ' || v_index,
        'meaningVi','Xin chào ' || v_index,'formality','neutral','usageContext','Daily conversation',
        'dialogue',jsonb_build_array(
          jsonb_build_object('speaker','A','englishText','Hello ' || v_index,'vietnameseTranslation','Xin chào ' || v_index),
          jsonb_build_object('speaker','B','englishText','Welcome.','vietnameseTranslation','Chào mừng.'))),
      jsonb_build_object('englishId',1000+v_index,'vietnameseId',2000+v_index,
        'englishText','Hello ' || v_index,'vietnameseText','Xin chào ' || v_index,
        'englishContributor','author_en','vietnameseContributor','author_vi',
        'englishLicense','CC BY 2.0 FR','vietnameseLicense','CC BY 2.0 FR',
        'sourceUrl','https://api.tatoeba.org/v1/sentences/' || (1000+v_index),
        'translationUrl','https://api.tatoeba.org/v1/sentences/' || (2000+v_index),
        'validationStatus','eligible'));
    IF v_lesson IS NULL THEN RAISE EXCEPTION 'A valid lesson was not persisted'; END IF;
    IF public.englify_claim_real_english_job('real-english:smoke:slot:' || v_index,now()) IS NOT NULL THEN
      RAISE EXCEPTION 'Completed slot was claimed twice';
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM public.real_english_lessons WHERE status='pending_review')<>5 THEN
    RAISE EXCEPTION 'Expected five pending lessons';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.real_english_generation_batches
    WHERE generation_date=(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
      AND target_count=5 AND success_count=5 AND completed_at IS NOT NULL) THEN
    RAISE EXCEPTION 'Daily batch did not count five stored lessons';
  END IF;
  BEGIN
    PERFORM public.englify_claim_real_english_job('real-english:smoke:slot:6',now());
    RAISE EXCEPTION 'Sixth request bypassed the daily quota';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL;
  END;
END $$;
RESET ROLE;
ROLLBACK;
