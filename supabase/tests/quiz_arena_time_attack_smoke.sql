BEGIN;
INSERT INTO auth.users(id) VALUES('a2311111-1111-4111-8111-111111111111'),('a2322222-2222-4222-8222-222222222222');
SELECT set_config('request.jwt.claim.sub','a2311111-1111-4111-8111-111111111111',true);
CREATE TEMP TABLE time_attack_fixture(id uuid,request_id uuid,question_id uuid,answer jsonb);
GRANT SELECT ON time_attack_fixture TO authenticated;
DO $$ DECLARE v_combo integer; v_ms integer; v_expected integer; v_points jsonb; BEGIN
  FOREACH v_combo IN ARRAY ARRAY[1,2,3,4,5,6,7,10] LOOP
    v_expected:=CASE WHEN v_combo>=7 THEN 200 WHEN v_combo>=5 THEN 150 WHEN v_combo>=3 THEN 120 ELSE 100 END;
    IF (public.englify_time_attack_points(true,v_combo,11000,100)->>'points')::integer<>v_expected THEN RAISE EXCEPTION 'Combo boundary failed: %',v_combo; END IF;
  END LOOP;
  FOREACH v_ms IN ARRAY ARRAY[0,3000,3001,6000,6001,10000,10001] LOOP
    v_expected:=CASE WHEN v_ms<=3000 THEN 50 WHEN v_ms<=6000 THEN 30 WHEN v_ms<=10000 THEN 10 ELSE 0 END;
    v_points:=public.englify_time_attack_points(true,1,v_ms,100);
    IF (v_points->>'speed_bonus')::integer<>v_expected OR (v_points->>'points')::integer<>100+v_expected THEN RAISE EXCEPTION 'Speed boundary failed: %',v_ms; END IF;
  END LOOP;
  IF (public.englify_time_attack_points(false,0,0,100)->>'points')::integer<>0
    OR (public.englify_time_attack_points(true,3,11000,101)->>'points')::integer<>121 THEN RAISE EXCEPTION 'Incorrect score or integer floor failed'; END IF;
END $$;
DO $$ DECLARE v_session jsonb; v_again jsonb; v_id uuid; v_request uuid:=gen_random_uuid(); v_q uuid; v_key jsonb; v_answer jsonb; v_retry uuid; v_index integer; v_start text; BEGIN
  v_session:=public.englify_time_attack_start(v_request,'A1','normal');v_id:=(v_session->>'id')::uuid;
  IF (v_session->>'question_count')::integer<>10 OR (v_session->>'time_limit_seconds')::integer<>120 OR (v_session->>'remaining_lives')::integer<>3
    OR v_session->'review'<>'null'::jsonb OR v_session ? 'questions' OR v_session->'current_question' ? 'answer' THEN RAISE EXCEPTION 'Unsafe start configuration'; END IF;
  v_again:=public.englify_time_attack_finish(v_id,false);
  IF v_again->>'status'<>'active' OR v_again->>'expires_at'<>v_session->>'expires_at' THEN RAISE EXCEPTION 'Early finalize closed or extended a game'; END IF;
  v_again:=public.englify_time_attack_start(v_request,'A1','normal');
  IF v_again->>'id'<>v_session->>'id' OR v_again->>'question_started_at'<>v_session->>'question_started_at' THEN RAISE EXCEPTION 'Start retry reset question clock'; END IF;
  BEGIN PERFORM public.englify_time_attack_start(gen_random_uuid(),'A1','hard');RAISE EXCEPTION 'Two active timed sessions accepted';EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL; END;
  BEGIN PERFORM public.englify_arena_submit(v_id,'{}');RAISE EXCEPTION 'Practice submitted Time Attack';EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL; END;
  BEGIN PERFORM public.englify_arena_end(v_id);RAISE EXCEPTION 'Practice ended Time Attack';EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL; END;
  BEGIN PERFORM public.englify_arena_session(v_id);RAISE EXCEPTION 'Practice exposed timed questions';EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL; END;
  FOR v_index IN 1..10 LOOP
    v_session:=public.englify_time_attack_session(v_id); v_start:=v_session->>'question_started_at';
    IF public.englify_time_attack_session(v_id)->>'question_started_at'<>v_start THEN RAISE EXCEPTION 'Get reset the question clock'; END IF;
    v_q:=(v_session#>>'{current_question,id}')::uuid;v_retry:=gen_random_uuid();
    SELECT CASE WHEN question->>'kind' IN ('fill_blank','grammar_correction') THEN answer->0 ELSE answer END INTO v_answer FROM public.arena_session_questions WHERE session_id=v_id AND question_id=v_q;
    BEGIN PERFORM public.englify_time_attack_answer(v_id,gen_random_uuid(),gen_random_uuid(),v_answer);RAISE EXCEPTION 'Out-of-order answer accepted';EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL; END;
    BEGIN PERFORM public.englify_time_attack_answer(v_id,v_q,gen_random_uuid(),'{"score":99999,"combo":99,"lives":99}');RAISE EXCEPTION 'Forged answer payload accepted';EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    v_session:=public.englify_time_attack_answer(v_id,v_q,v_retry,v_answer);
    v_again:=public.englify_time_attack_answer(v_id,v_q,v_retry,v_answer);
    IF v_session->>'score'<>v_again->>'score' OR (v_session->>'answered_count')::integer<>v_index OR (v_session->>'combo')::integer<>v_index
      OR (v_session->>'remaining_lives')::integer<>3 THEN RAISE EXCEPTION 'Score, combo, lives or retry failed'; END IF;
    IF v_index<10 AND v_session->'current_question'<>'null'::jsonb THEN RAISE EXCEPTION 'Next question was exposed before issuance'; END IF;
    BEGIN PERFORM public.englify_time_attack_answer(v_id,v_q,gen_random_uuid(),v_answer);RAISE EXCEPTION 'Question answered twice';EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL; END;
  END LOOP;
  IF v_session->>'completion_reason'<>'all_questions' OR (v_session->>'score')::integer<>2040 OR (v_session->>'accuracy')::numeric<>100
    OR (v_session->>'max_combo')::integer<>10 OR NOT (v_session->>'is_personal_best')::boolean OR jsonb_array_length(v_session->'review')<>10 THEN
    RAISE EXCEPTION 'Final perfect-game result failed: %',v_session; END IF;
  INSERT INTO time_attack_fixture VALUES(v_id,v_retry,v_q,v_answer);
  IF (public.englify_arena_history()->>'total')::integer<>0 OR EXISTS(SELECT 1 FROM public.xp_events WHERE user_id=auth.uid()) THEN RAISE EXCEPTION 'Time Attack changed Practice history or awarded XP'; END IF;
END $$;
-- Combo reset and life exhaustion, using valid but incorrect answers.
DO $$ DECLARE v_session jsonb; v_id uuid; v_q record; v_answer jsonb; v_index integer; BEGIN
  v_session:=public.englify_time_attack_start(gen_random_uuid(),'A1','normal');v_id:=(v_session->>'id')::uuid;
  FOR v_index IN 1..4 LOOP
    v_session:=public.englify_time_attack_session(v_id);
    SELECT * INTO v_q FROM public.arena_session_questions WHERE session_id=v_id AND question_id=(v_session#>>'{current_question,id}')::uuid;
    IF v_index=1 THEN v_answer:=CASE WHEN v_q.question->>'kind' IN ('fill_blank','grammar_correction') THEN v_q.answer->0 ELSE v_q.answer END;
    ELSE
      v_answer:=CASE WHEN v_q.question->>'kind' IN ('multiple_choice','reading') THEN (SELECT o->'id' FROM jsonb_array_elements(v_q.question->'options') o WHERE o->'id'<>v_q.answer LIMIT 1)
        WHEN v_q.question->>'kind' IN ('fill_blank','grammar_correction') THEN to_jsonb('deliberately incorrect'::text)
        WHEN v_q.question->>'kind'='sentence_order' THEN (SELECT jsonb_agg(v ORDER BY n DESC) FROM jsonb_array_elements(v_q.answer) WITH ORDINALITY t(v,n))
        ELSE (SELECT jsonb_object_agg(key,next_value) FROM (SELECT key,coalesce(lead(value) OVER(ORDER BY key),first_value(value) OVER(ORDER BY key)) next_value FROM jsonb_each(v_q.answer)) t) END;
    END IF;
    v_session:=public.englify_time_attack_answer(v_id,v_q.question_id,gen_random_uuid(),v_answer);
  END LOOP;
  IF v_session->>'completion_reason'<>'no_lives' OR (v_session->>'remaining_lives')::integer<>0 OR (v_session->>'combo')::integer<>0
    OR (v_session->>'max_combo')::integer<>1 OR (v_session->>'answered_count')::integer<>4 THEN RAISE EXCEPTION 'Life/combo reset failed'; END IF;
END $$;
-- Deadline is authoritative; accepted answers survive timeout and no expired answer is added.
DO $$ DECLARE v_session jsonb; v_id uuid; v_q uuid; v_answer jsonb; v_now timestamptz; BEGIN
  v_session:=public.englify_time_attack_start(gen_random_uuid(),'A1','easy');v_id:=(v_session->>'id')::uuid;
  IF (v_session->>'remaining_lives')::integer<>5 OR (v_session->>'time_limit_seconds')::integer<>180 THEN RAISE EXCEPTION 'Easy rules failed'; END IF;
  v_q:=(v_session#>>'{current_question,id}')::uuid;
  SELECT CASE WHEN question->>'kind' IN ('fill_blank','grammar_correction') THEN answer->0 ELSE answer END INTO v_answer FROM public.arena_session_questions WHERE session_id=v_id AND question_id=v_q;
  PERFORM public.englify_time_attack_answer(v_id,v_q,gen_random_uuid(),v_answer);
  v_session:=public.englify_time_attack_session(v_id);v_q:=(v_session#>>'{current_question,id}')::uuid;
  v_now:=clock_timestamp();
  UPDATE public.arena_time_attack_sessions SET started_at=v_now-interval '181 seconds',expires_at=v_now-interval '1 second',question_started_at=v_now-interval '2 seconds' WHERE id=v_id;
  UPDATE public.arena_sessions SET started_at=v_now-interval '181 seconds' WHERE id=v_id;
  v_session:=public.englify_time_attack_answer(v_id,v_q,gen_random_uuid(),v_answer);
  IF v_session->>'status'<>'expired' OR (v_session->>'answered_count')::integer<>1 OR (v_session->>'score')::integer<>150
    OR (v_session->>'duration_ms')::integer<>180000 THEN RAISE EXCEPTION 'Expiration lost an answer or accepted a late answer'; END IF;
  v_session:=public.englify_time_attack_start(gen_random_uuid(),'A1','hard');v_id:=(v_session->>'id')::uuid;
  IF (v_session->>'question_count')::integer<>15 OR (v_session->>'remaining_lives')::integer<>2 THEN RAISE EXCEPTION 'Hard rules failed'; END IF;
  v_session:=public.englify_time_attack_finish(v_id,true);
  IF v_session->>'status'<>'abandoned' OR (v_session->>'is_personal_best')::boolean THEN RAISE EXCEPTION 'Abandoned session qualified for a record'; END IF;
  IF (public.englify_time_attack_records()#>>'{records,2,sessions}') IS NULL THEN RAISE EXCEPTION 'Personal records unavailable'; END IF;
END $$;
-- Rule changes need a new revision; active snapshots and historic records remain unchanged.
DO $$ DECLARE v_session jsonb; v_id uuid; v_old integer; v_again jsonb; BEGIN
  UPDATE public.arena_time_attack_rules SET enabled=false WHERE difficulty='normal';
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.englify_time_attack_records()->'records') r WHERE r->>'difficulty'='normal' AND (r->>'highest_score')::integer=2040) THEN
    RAISE EXCEPTION 'Paused difficulty hid a personal record'; END IF;
  UPDATE public.arena_time_attack_rules SET enabled=true WHERE difficulty='normal';
  v_session:=public.englify_time_attack_start(gen_random_uuid(),'A1','normal');v_id:=(v_session->>'id')::uuid;
  BEGIN UPDATE public.arena_time_attack_rules SET base_points=101 WHERE difficulty='normal';RAISE EXCEPTION 'Rule changed without a version';EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  UPDATE public.arena_time_attack_rules SET base_points=101,version=version+1 WHERE difficulty='normal';
  v_again:=public.englify_time_attack_session(v_id);
  IF v_again->>'rules_version'<>v_session->>'rules_version' OR (v_again->>'base_points')::integer<>100 THEN RAISE EXCEPTION 'Active rules snapshot changed'; END IF;
  PERFORM public.englify_time_attack_finish(v_id,true);
END $$;
-- Existing reward shop claims keep their XP accounting and retry identity.
DO $$ DECLARE v_reward uuid; v_first jsonb; v_retry jsonb; BEGIN
  INSERT INTO public.xp_events(user_id,source_type,source_id,amount) VALUES(auth.uid(),'adjustment',gen_random_uuid(),200);
  INSERT INTO public.user_levels(user_id,total_xp,level) VALUES(auth.uid(),200,3)
    ON CONFLICT(user_id) DO UPDATE SET total_xp=200,level=3;
  SELECT id INTO v_reward FROM public.reward_items WHERE is_active AND xp_cost<=200 AND required_level<=3 ORDER BY xp_cost,id LIMIT 1;
  IF v_reward IS NULL THEN RAISE EXCEPTION 'Missing legacy reward fixture'; END IF;
  v_first:=public.englify_claim_reward(v_reward);v_retry:=public.englify_claim_reward(v_reward);
  IF NOT (v_first->>'newly_claimed')::boolean OR (v_retry->>'newly_claimed')::boolean OR v_first->>'claim_id'<>v_retry->>'claim_id'
    OR (SELECT count(*) FROM public.reward_claims WHERE user_id=auth.uid() AND reward_id=v_reward)<>1
    OR (SELECT total_xp FROM public.user_levels WHERE user_id=auth.uid())<>200 THEN RAISE EXCEPTION 'Legacy reward accounting/retry changed'; END IF;
END $$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_fixture record; BEGIN
  SELECT * INTO v_fixture FROM time_attack_fixture LIMIT 1;
  IF (SELECT count(*) FROM public.arena_time_attack_sessions)=0 THEN RAISE EXCEPTION 'Owner cannot read game metadata'; END IF;
  BEGIN UPDATE public.arena_time_attack_sessions SET score=99999;RAISE EXCEPTION 'Forged score accepted';EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM * FROM public.arena_time_attack_answers;RAISE EXCEPTION 'Private answer table readable';EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.englify_time_attack_points(true,99,0,100);RAISE EXCEPTION 'Private scoring helper callable';EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','a2322222-2222-4222-8222-222222222222',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_fixture record; BEGIN
  SELECT * INTO v_fixture FROM time_attack_fixture LIMIT 1;
  IF EXISTS(SELECT 1 FROM public.arena_time_attack_sessions) OR (public.englify_time_attack_history()->>'total')::integer<>0 THEN RAISE EXCEPTION 'Cross-user history leak'; END IF;
  BEGIN PERFORM public.englify_time_attack_session(v_fixture.id);RAISE EXCEPTION 'Cross-user game read';EXCEPTION WHEN SQLSTATE 'PT404' THEN NULL; END;
  BEGIN PERFORM public.englify_time_attack_answer(v_fixture.id,v_fixture.question_id,gen_random_uuid(),v_fixture.answer);RAISE EXCEPTION 'Cross-user answer';EXCEPTION WHEN SQLSTATE 'PT404' THEN NULL; END;
  BEGIN PERFORM public.englify_time_attack_finish(v_fixture.id,true);RAISE EXCEPTION 'Cross-user abandonment';EXCEPTION WHEN SQLSTATE 'PT404' THEN NULL; END;
END $$;
RESET ROLE;
ROLLBACK;
