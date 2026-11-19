-- Disposable local Supabase only. All test users and sessions roll back.
BEGIN;
INSERT INTO auth.users(id) VALUES('a2111111-1111-4111-8111-111111111111'),('a2222222-2222-4222-8222-222222222222');
CREATE TEMP TABLE arena_test_sessions(id uuid PRIMARY KEY,kind text,answers jsonb);
GRANT SELECT,INSERT,UPDATE ON arena_test_sessions TO authenticated;
SELECT set_config('request.jwt.claim.sub','a2111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_kind text; v_session jsonb; v_request uuid; v_again jsonb; BEGIN
  IF jsonb_array_length(public.englify_arena_catalog()->'groups')=0 THEN RAISE EXCEPTION 'Missing Arena catalog'; END IF;
  FOREACH v_kind IN ARRAY ARRAY['multiple_choice','fill_blank','matching','grammar_correction','sentence_order','reading'] LOOP
    v_request:=gen_random_uuid();
    v_session:=public.englify_arena_start(v_request,'A1',NULL,v_kind,5,NULL);
    v_again:=public.englify_arena_start(v_request,'A1',NULL,v_kind,5,NULL);
    IF v_session->>'id'<>v_again->>'id' OR v_session->'result'<>'null'::jsonb OR jsonb_array_length(v_session->'questions')<>5
      OR EXISTS(SELECT 1 FROM jsonb_array_elements(v_session->'questions') q
        WHERE q->>'kind'<>v_kind OR q->>'cefr_level'<>'A1' OR q ? 'answer' OR q ? 'explanation_vi' OR q ? 'correct_answer') THEN
      RAISE EXCEPTION 'Unsafe or incorrect session retrieval for %',v_kind; END IF;
    INSERT INTO arena_test_sessions(id,kind) VALUES((v_session->>'id')::uuid,v_kind);
    BEGIN
      PERFORM public.englify_arena_start(v_request,'A2',NULL,v_kind,5,NULL);
      RAISE EXCEPTION 'Conflicting start request accepted';
    EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL; END;
  END LOOP;
  BEGIN PERFORM public.englify_arena_start(gen_random_uuid(),'C2',NULL,NULL,5,NULL);RAISE EXCEPTION 'C2 accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN PERFORM public.englify_arena_start(gen_random_uuid(),'A1',NULL,NULL,6,NULL);RAISE EXCEPTION 'Invalid count accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN PERFORM public.englify_arena_start(gen_random_uuid(),'A1','not-a-topic',NULL,5,NULL);RAISE EXCEPTION 'Invalid topic accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  IF EXISTS(SELECT 1 FROM public.arena_answer_keys) OR EXISTS(SELECT 1 FROM public.arena_questions) THEN
    RAISE EXCEPTION 'Learner retrieved bank rows or private answer keys'; END IF;
  BEGIN PERFORM answer FROM public.arena_session_questions;RAISE EXCEPTION 'Private session keys readable';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE public.arena_sessions SET earned_xp=10; RAISE EXCEPTION 'Learner changed own score';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
UPDATE arena_test_sessions t SET answers=(SELECT jsonb_object_agg(question_id::text,
  CASE WHEN t.kind IN ('fill_blank','grammar_correction') THEN q.answer->0 ELSE q.answer END)
  FROM public.arena_session_questions q WHERE q.session_id=t.id);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_test record; v_session jsonb; v_retry jsonb; BEGIN
  FOR v_test IN SELECT * FROM arena_test_sessions LOOP
    BEGIN PERFORM public.englify_arena_submit(v_test.id,'{}');RAISE EXCEPTION 'Incomplete answers accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN PERFORM public.englify_arena_submit(v_test.id,v_test.answers||'{"score":100}');RAISE EXCEPTION 'Client score accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    v_session:=public.englify_arena_submit(v_test.id,v_test.answers);
    v_retry:=public.englify_arena_submit(v_test.id,v_test.answers);
    IF v_session<>v_retry OR v_session->>'status'<>'completed' OR (v_session->>'correct_count')::integer<>5
      OR (v_session->>'accuracy')::numeric<>100 OR (v_session->>'duration_seconds')::integer<0
      OR jsonb_array_length(v_session#>'{result,review}')<>5
      OR EXISTS(SELECT 1 FROM jsonb_array_elements(v_session#>'{result,review}') r WHERE coalesce(length(r->>'explanation_vi'),0)=0 OR NOT r ? 'correct_answer') THEN
      RAISE EXCEPTION 'Grading/review/retry failed for %',v_test.kind; END IF;
  END LOOP;
  IF (SELECT count(*) FROM public.xp_events WHERE user_id=auth.uid() AND source_type='arena')<>1
    OR (SELECT sum(amount) FROM public.xp_events WHERE user_id=auth.uid() AND source_type='arena')<>10
    OR (SELECT total_xp FROM public.user_levels WHERE user_id=auth.uid())<>10 THEN
    RAISE EXCEPTION 'Replay duplicated Arena XP or shared level is inconsistent'; END IF;
  IF (public.englify_arena_history()->>'total')::integer<>6 THEN RAISE EXCEPTION 'Practice history missing'; END IF;
END $$;
RESET ROLE;
-- Test every level, topic, and published content count. The caller uses the same RPC.
DO $$ DECLARE v_level text; v_session jsonb; v_topic text; v_difficulty integer; BEGIN
  FOREACH v_level IN ARRAY ARRAY['A1','A2','B1','B2','C1'] LOOP
    v_session:=public.englify_arena_start(gen_random_uuid(),v_level,NULL,NULL,20,NULL);
    IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_session->'questions') q WHERE q->>'cefr_level'<>v_level) THEN
      RAISE EXCEPTION 'CEFR filter failed'; END IF;
    PERFORM public.englify_arena_end((v_session->>'id')::uuid);
  END LOOP;
  FOR v_topic IN SELECT topic FROM public.arena_questions WHERE cefr_level='B1' AND is_published GROUP BY topic HAVING count(*)>=5 LOOP
    v_session:=public.englify_arena_start(gen_random_uuid(),'B1',v_topic,NULL,5,NULL);
    IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_session->'questions') q WHERE q->>'topic'<>v_topic) THEN
      RAISE EXCEPTION 'Topic filter failed'; END IF;
    PERFORM public.englify_arena_end((v_session->>'id')::uuid);
  END LOOP;
  v_difficulty:=2;v_session:=public.englify_arena_start(gen_random_uuid(),'B1',NULL,NULL,5,v_difficulty);
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_session->'questions') q WHERE (q->>'difficulty')::integer<>v_difficulty) THEN
    RAISE EXCEPTION 'Difficulty filter failed'; END IF;
  PERFORM public.englify_arena_end((v_session->>'id')::uuid);
  BEGIN PERFORM public.englify_arena_submit((v_session->>'id')::uuid,'{}');RAISE EXCEPTION 'Abandoned quiz submitted';
  EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL; END;
END $$;
-- A second learner has no access to the first learner's sessions, reviews or rewards.
SELECT set_config('request.jwt.claim.sub','a2222222-2222-4222-8222-222222222222',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_id uuid; BEGIN
  SELECT id INTO v_id FROM arena_test_sessions LIMIT 1;
  IF (SELECT count(*) FROM public.arena_sessions)<>0 OR (SELECT count(*) FROM public.arena_reward_claims)<>0
    OR (public.englify_arena_history()->>'total')::integer<>0 THEN RAISE EXCEPTION 'RLS leaked user attempts'; END IF;
  BEGIN PERFORM public.englify_arena_session(v_id);RAISE EXCEPTION 'Cross-user review read';EXCEPTION WHEN SQLSTATE 'PT404' THEN NULL; END;
  BEGIN PERFORM public.englify_arena_submit(v_id,'{}');RAISE EXCEPTION 'Cross-user submit accepted';EXCEPTION WHEN SQLSTATE 'PT404' THEN NULL; END;
  BEGIN PERFORM public.englify_arena_end(v_id);RAISE EXCEPTION 'Cross-user end accepted';EXCEPTION WHEN SQLSTATE 'PT404' THEN NULL; END;
END $$;
RESET ROLE;
-- Wrong answers must be graded by the server without granting XP.
RESET ROLE;
TRUNCATE arena_test_sessions;
DO $$ DECLARE v_kind text; v_session jsonb; BEGIN
  FOREACH v_kind IN ARRAY ARRAY['multiple_choice','fill_blank','matching','grammar_correction','sentence_order','reading'] LOOP
    v_session:=public.englify_arena_start(gen_random_uuid(),'A1',NULL,v_kind,5,NULL);
    INSERT INTO arena_test_sessions(id,kind) VALUES((v_session->>'id')::uuid,v_kind);
  END LOOP;
END $$;
UPDATE arena_test_sessions t SET answers=(SELECT jsonb_object_agg(q.question_id::text,
  CASE WHEN t.kind IN ('multiple_choice','reading') THEN (SELECT o->'id' FROM jsonb_array_elements(q.question->'options') o WHERE o->'id'<>q.answer LIMIT 1)
    WHEN t.kind IN ('fill_blank','grammar_correction') THEN to_jsonb('This is deliberately incorrect'::text)
    WHEN t.kind='sentence_order' THEN (SELECT jsonb_agg(v ORDER BY n DESC) FROM jsonb_array_elements(q.answer) WITH ORDINALITY a(v,n))
    ELSE (SELECT jsonb_object_agg(key,next_value) FROM (
      SELECT key,coalesce(lead(value) OVER(ORDER BY key),first_value(value) OVER(ORDER BY key)) next_value FROM jsonb_each(q.answer)) rotated) END)
  FROM public.arena_session_questions q WHERE q.session_id=t.id);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_test record; v_result jsonb; v_first text; BEGIN
  FOR v_test IN SELECT * FROM arena_test_sessions LOOP
    SELECT key INTO v_first FROM jsonb_object_keys(v_test.answers) key LIMIT 1;
    BEGIN PERFORM public.englify_arena_submit(v_test.id,jsonb_set(v_test.answers,ARRAY[v_first],'777'));
      RAISE EXCEPTION 'Invalid answer shape accepted'; EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    v_result:=public.englify_arena_submit(v_test.id,v_test.answers);
    IF (v_result->>'correct_count')::integer<>0 OR (v_result->>'earned_xp')::integer<>0
      OR jsonb_array_length(v_result#>'{result,review_topics}')=0 THEN RAISE EXCEPTION 'Incorrect grading failed for %',v_test.kind; END IF;
  END LOOP;
  IF EXISTS(SELECT 1 FROM public.xp_events WHERE user_id=auth.uid() AND source_type='arena') THEN
    RAISE EXCEPTION 'Incorrect attempts earned XP'; END IF;
END $$;
RESET ROLE;
-- Active withdrawn sessions cannot reveal or grade withdrawn content, but can still be ended.
DO $$ DECLARE v_session jsonb; v_id uuid; BEGIN
  v_session:=public.englify_arena_start(gen_random_uuid(),'A1',NULL,NULL,5,NULL);v_id:=(v_session->>'id')::uuid;
  UPDATE public.arena_questions SET is_published=false WHERE id=(v_session#>>'{questions,0,id}')::uuid;
  BEGIN PERFORM public.englify_arena_session(v_id);RAISE EXCEPTION 'Withdrawn active question still readable';
  EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL; END;
  PERFORM public.englify_arena_end(v_id);
END $$;
-- A sentence with two identical tokens is correct whichever matching token ID is tapped first.
DO $$ DECLARE v_session jsonb; v_id uuid; v_answers jsonb; v_q record; v_word text; v_ids text[]; BEGIN
  v_session:=public.englify_arena_start(gen_random_uuid(),'C1',NULL,'sentence_order',5,NULL);v_id:=(v_session->>'id')::uuid;
  SELECT jsonb_object_agg(question_id::text,answer) INTO v_answers FROM public.arena_session_questions WHERE session_id=v_id;
  FOR v_q IN SELECT * FROM public.arena_session_questions WHERE session_id=v_id LOOP
    SELECT o->>'text',array_agg(o->>'id') INTO v_word,v_ids FROM jsonb_array_elements(v_q.question->'options') o GROUP BY o->>'text' HAVING count(*)>1 LIMIT 1;
    IF v_ids IS NOT NULL THEN
      v_answers:=jsonb_set(v_answers,ARRAY[v_q.question_id::text],(SELECT jsonb_agg(CASE WHEN v=v_ids[1] THEN to_jsonb(v_ids[2]) WHEN v=v_ids[2] THEN to_jsonb(v_ids[1]) ELSE to_jsonb(v) END ORDER BY n)
        FROM jsonb_array_elements_text(v_q.answer) WITH ORDINALITY t(v,n)));
    END IF;
  END LOOP;
  IF (public.englify_arena_submit(v_id,v_answers)->>'correct_count')::integer<>5 THEN RAISE EXCEPTION 'Identical sentence tokens were not interchangeable'; END IF;
END $$;
-- Withdraw publication: catalog and new sessions must not include draft questions.
UPDATE public.arena_questions SET is_published=false;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF jsonb_array_length(public.englify_arena_catalog()->'groups')<>0 THEN RAISE EXCEPTION 'Unpublished bank visible'; END IF;
  BEGIN PERFORM public.englify_arena_start(gen_random_uuid(),'A1',NULL,NULL,5,NULL);RAISE EXCEPTION 'Unpublished questions assigned';
  EXCEPTION WHEN SQLSTATE 'PT422' THEN NULL; END;
END $$;
RESET ROLE;
-- Keys are still available only in the owner’s completed historical review.
SELECT set_config('request.jwt.claim.sub','a2111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_id uuid; BEGIN
  SELECT id INTO v_id FROM public.arena_sessions WHERE user_id=auth.uid() AND status='completed' ORDER BY started_at LIMIT 1;
  IF public.englify_arena_session(v_id)#>'{result,review}' IS NULL THEN RAISE EXCEPTION 'Historical review lost after unpublish'; END IF;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  BEGIN PERFORM public.englify_arena_catalog();RAISE EXCEPTION 'Unauthenticated catalog accepted';
  EXCEPTION WHEN invalid_authorization_specification THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;
