-- Disposable local Supabase only. Writing V2.4 analytics, isolation and bounded history.
BEGIN;
INSERT INTO auth.users(id) VALUES
  ('d4111111-1111-4111-8111-111111111111'),
  ('d4222222-2222-4222-8222-222222222222');

SELECT set_config('request.jwt.claim.sub','d4111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_empty jsonb:=public.englify_writing_progress_summary(); BEGIN
  IF (v_empty->>'total_submissions')::integer<>0 OR (v_empty->>'total_words')::integer<>0
    OR v_empty->'average_ai_score'<>'null'::jsonb THEN
    RAISE EXCEPTION 'Empty Writing analytics fabricated progress: %',v_empty;
  END IF;
END $$;
RESET ROLE;

DO $$ DECLARE v_exercise uuid; v_valid jsonb; v_invalid jsonb; BEGIN
  SELECT id INTO v_exercise FROM public.writing_exercises
    WHERE is_published AND kind IN ('paragraph','email','opinion','essay') ORDER BY cefr_level,difficulty,id LIMIT 1;
  IF v_exercise IS NULL THEN RAISE EXCEPTION 'Writing analytics fixture exercise unavailable'; END IF;
  PERFORM set_config('request.jwt.claim.sub','d4111111-1111-4111-8111-111111111111',true);
  SET LOCAL ROLE authenticated;
  v_valid:=public.englify_submit_writing(gen_random_uuid(),v_exercise,
    btrim(repeat('I practice a clear English paragraph with useful details and careful structure. ',12)),false);
  v_invalid:=public.englify_submit_writing(gen_random_uuid(),v_exercise,'Too short.',false);
  RESET ROLE;
  UPDATE public.writing_feedback SET rule_result='needs_revision'
    WHERE submission_id=(v_invalid->>'id')::uuid;
  INSERT INTO public.writing_ai_feedback(submission_id,user_id,request_id,overall_score,grammar_score,vocabulary_score,
    sentence_structure_score,coherence_score,task_score,assessment_vi,strengths,improvements,errors,next_steps,model)
  VALUES ((v_valid->>'id')::uuid,'d4111111-1111-4111-8111-111111111111',gen_random_uuid(),78,75,80,77,76,82,
    'Phản hồi thử nghiệm.','[]','[]','[{"type":"grammar","original":"I practice","corrected":"I practised","explanation_vi":"Kiểm tra thì."},{"type":"vocabulary","original":"useful","corrected":"practical","explanation_vi":"Lựa chọn từ."}]','[]','test-model');
  INSERT INTO public.writing_ai_rewrites(submission_id,user_id,request_id,mode,original_text,improved_text,key_changes,
    explanations_vi,vocabulary_suggestions,model) VALUES ((v_valid->>'id')::uuid,
    'd4111111-1111-4111-8111-111111111111',gen_random_uuid(),'natural','Original text','Rewritten text','[]','[]','[]','test-model');
END $$;

SELECT set_config('request.jwt.claim.sub','d4111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_summary jsonb:=public.englify_writing_progress_summary(); v_scores jsonb; v_mistakes jsonb;
  v_history jsonb; v_report jsonb; v_detail_id uuid;
BEGIN
  IF (v_summary->>'total_submissions')::integer<>1 OR (v_summary->>'average_ai_score')::numeric<>78
    OR (v_summary->>'ai_score_samples')::integer<>1 THEN
    RAISE EXCEPTION 'Invalid submission or rewrite polluted Writing summary: %',v_summary;
  END IF;
  v_scores:=public.englify_writing_score_analytics('30d',NULL,NULL);
  IF jsonb_array_length(v_scores->'trends')<>1 OR (v_scores#>>'{groups,0,sample_size}')::integer<>1
    OR (v_scores#>>'{groups,0,reliable_trend}')::boolean THEN
    RAISE EXCEPTION 'AI score grouping/reliability failed: %',v_scores;
  END IF;
  v_mistakes:=public.englify_writing_mistake_summary('30d');
  IF jsonb_array_length(v_mistakes)<>2 THEN RAISE EXCEPTION 'Structured mistake aggregation failed: %',v_mistakes; END IF;
  v_history:=public.englify_writing_analytics_history('all',NULL,NULL,NULL,'all',1,1);
  IF (v_history->>'total')::integer<>2 OR jsonb_array_length(v_history->'items')<>1 THEN
    RAISE EXCEPTION 'Writing history pagination failed: %',v_history; END IF;
  SELECT (item->>'id')::uuid INTO v_detail_id FROM jsonb_array_elements(v_history->'items') item LIMIT 1;
  PERFORM public.englify_writing_analytics_detail(v_detail_id);
  v_report:=public.englify_writing_report('weekly');
  IF v_report->>'period'<>'weekly' THEN RAISE EXCEPTION 'Weekly report failed: %',v_report; END IF;
  PERFORM public.englify_writing_activity_stats('7d');
  PERFORM public.englify_writing_cefr_progress();
  PERFORM public.englify_writing_topic_progress();
  PERFORM public.englify_writing_recommendations();
  BEGIN
    PERFORM public.englify_writing_analytics_history('invalid',NULL,NULL,NULL,'all',1,5);
    RAISE EXCEPTION 'Invalid analytics range was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL; END;
END $$;
RESET ROLE;

-- Another learner receives empty own analytics and cannot open the first learner's detail.
SELECT set_config('request.jwt.claim.sub','d4222222-2222-4222-8222-222222222222',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_summary jsonb:=public.englify_writing_progress_summary(); v_foreign uuid; BEGIN
  IF (v_summary->>'total_submissions')::integer<>0 THEN RAISE EXCEPTION 'Cross-user analytics leaked'; END IF;
  SELECT id INTO v_foreign FROM public.writing_submissions WHERE user_id='d4111111-1111-4111-8111-111111111111' LIMIT 1;
  BEGIN
    PERFORM public.englify_writing_analytics_detail(v_foreign);
    RAISE EXCEPTION 'Cross-user Writing detail leaked';
  EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;
