-- Run only against a disposable Supabase database after db reset.
BEGIN;
INSERT INTO auth.users(id) VALUES ('a1111111-1111-4111-8111-111111111111'),('a2222222-2222-4222-8222-222222222222');
INSERT INTO public.writing_submissions(id,user_id,exercise_id,request_id,prompt,body) VALUES
('a3333333-3333-4333-8333-333333333333','a1111111-1111-4111-8111-111111111111','44444444-4444-4444-8444-444444444404','a4444444-4444-4444-8444-444444444444','Write about a place.','I enjoy visiting the library because it is quiet and welcoming. I can read and study there every weekend.'),
('a5555555-5555-4555-8555-555555555555','a2222222-2222-4222-8222-222222222222','44444444-4444-4444-8444-444444444404','a6666666-6666-4666-8666-666666666666','Write about a place.','I enjoy the park because it is peaceful. I walk there with my family on Sunday mornings.');

SET LOCAL ROLE service_role;
DO $$ DECLARE v_first jsonb; v_retry jsonb; BEGIN
  v_first:=public.englify_claim_writing_ai_request('a1111111-1111-4111-8111-111111111111','coach','a7777777-7777-4777-8777-777777777777',1);
  v_retry:=public.englify_claim_writing_ai_request('a1111111-1111-4111-8111-111111111111','coach','a7777777-7777-4777-8777-777777777777',1);
  IF (v_first->>'duplicate')::boolean OR NOT (v_retry->>'duplicate')::boolean OR v_first->>'usage_id'<>v_retry->>'usage_id' THEN
    RAISE EXCEPTION 'Writing AI quota idempotency failed';
  END IF;
  BEGIN
    PERFORM public.englify_claim_writing_ai_request('a1111111-1111-4111-8111-111111111111','coach','a8888888-8888-4888-8888-888888888888',1);
    RAISE EXCEPTION 'Writing AI daily quota was bypassed';
  EXCEPTION WHEN SQLSTATE 'PT429' THEN NULL; END;
END $$;
INSERT INTO public.writing_ai_feedback(id,submission_id,user_id,request_id,overall_score,grammar_score,vocabulary_score,
  sentence_structure_score,coherence_score,task_score,assessment_vi,strengths,improvements,errors,next_steps,model)
VALUES('a9999999-9999-4999-8999-999999999999','a3333333-3333-4333-8333-333333333333','a1111111-1111-4111-8111-111111111111',
  'abbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',80,80,80,80,80,80,'Bài viết rõ ràng.','[]','[]','[]','[]','gemini-test');
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','a1111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_revision jsonb; BEGIN
  IF (SELECT count(*) FROM public.writing_ai_feedback)<>1 THEN RAISE EXCEPTION 'Owner cannot read AI feedback'; END IF;
  v_revision:=public.englify_create_writing_revision('accccccc-cccc-4ccc-8ccc-cccccccccccc','a3333333-3333-4333-8333-333333333333',
    'I enjoy visiting the library because it is quiet, welcoming, and useful for study.',NULL,'a9999999-9999-4999-8999-999999999999');
  IF (v_revision->>'revision_number')::integer<>1 THEN RAISE EXCEPTION 'Revision numbering failed'; END IF;
  BEGIN
    INSERT INTO public.writing_ai_feedback(submission_id,user_id,request_id,overall_score,grammar_score,vocabulary_score,
      sentence_structure_score,coherence_score,task_score,assessment_vi,model)
    VALUES('a3333333-3333-4333-8333-333333333333','a1111111-1111-4111-8111-111111111111',gen_random_uuid(),100,100,100,100,100,100,'Client score','fake');
    RAISE EXCEPTION 'Learner wrote an AI score directly';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','a2222222-2222-4222-8222-222222222222',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.writing_ai_feedback)<>0 OR (SELECT count(*) FROM public.writing_revisions)<>0 THEN
    RAISE EXCEPTION 'Cross-user Writing AI data was exposed';
  END IF;
  BEGIN
    PERFORM public.englify_create_writing_revision('addddddd-dddd-4ddd-8ddd-dddddddddddd','a3333333-3333-4333-8333-333333333333','Stolen revision.',NULL,NULL);
    RAISE EXCEPTION 'Cross-user revision was allowed';
  EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END;
END $$;
ROLLBACK;
