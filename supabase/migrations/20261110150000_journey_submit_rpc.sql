-- Quiz grading and XP are atomic and never accept a client-provided score.
CREATE FUNCTION public.englify_normalize_answer(p_value text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT pg_catalog.rtrim(pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.btrim(p_value)), '\s+', ' ', 'g'), '.!? ')
$$;
REVOKE ALL ON FUNCTION public.englify_normalize_answer(text) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.englify_start_lesson(p_lesson_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_state text; v_lesson record;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(auth.uid()::text));
  v_state := public.englify_lesson_state(p_lesson_id);
  IF v_state IS NULL THEN RAISE EXCEPTION 'Published lesson not found' USING ERRCODE='P0002'; END IF;
  IF v_state='locked' THEN RAISE EXCEPTION 'Complete the previous lesson first' USING ERRCODE='42501'; END IF;
  IF v_state='available' THEN
    INSERT INTO public.learning_progress(user_id,lesson_id,status)
    VALUES(auth.uid(),p_lesson_id,'in_progress') ON CONFLICT (user_id,lesson_id) DO NOTHING;
    v_state := 'in_progress';
  END IF;
  SELECT id,title,objective,position INTO v_lesson FROM public.lessons WHERE id=p_lesson_id;
  RETURN jsonb_build_object('id',v_lesson.id,'title',v_lesson.title,'objective',v_lesson.objective,
    'position',v_lesson.position,'state',v_state);
END $$;
REVOKE ALL ON FUNCTION public.englify_start_lesson(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_start_lesson(uuid) TO authenticated;

CREATE FUNCTION public.englify_submit_lesson(p_lesson_id uuid,p_request_id uuid,p_answers jsonb,p_content_version text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid(); v_old record; v_state text; v_question record; v_answer jsonb;
  v_correct boolean; v_correct_count int := 0; v_question_count int; v_passed boolean;
  v_prior_pass boolean; v_result_state text; v_attempt_id uuid; v_created_at timestamptz;
  v_step int; v_multiplier int; v_before_total int; v_before_level int; v_total int; v_new_level int;
  v_base_xp int; v_earned_xp int := 0; v_rewards jsonb := '[]'::jsonb;
  v_quest record; v_claim_id uuid; v_start_day date; v_period_start timestamptz; v_period_end timestamptz;
  v_badge record; v_badge_event_id uuid; v_completed int; v_level_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_request_id IS NULL OR pg_catalog.jsonb_typeof(p_answers) <> 'object'
     OR (SELECT count(*) FROM pg_catalog.jsonb_object_keys(p_answers)) NOT BETWEEN 1 AND 30 THEN
    RAISE EXCEPTION 'Submit one answer for every lesson question' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_uid::text));
  SELECT * INTO v_old FROM public.lesson_attempts WHERE user_id=v_uid AND request_id=p_request_id;
  IF FOUND THEN
    IF v_old.lesson_id<>p_lesson_id THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Submission ID belongs to another lesson'; END IF;
    RETURN jsonb_build_object('attempt_id',v_old.id,'correct_count',v_old.correct_count,
      'question_count',v_old.question_count,'passed',v_old.passed,'state',v_old.result_state,
      'earned_xp',v_old.earned_xp,'rewards',v_old.reward_payload,'created_at',v_old.created_at);
  END IF;
  v_state := public.englify_lesson_state(p_lesson_id);
  IF v_state IS NULL THEN RAISE EXCEPTION 'Published lesson not found' USING ERRCODE='P0002'; END IF;
  IF v_state='locked' THEN RAISE EXCEPTION 'Complete the previous lesson first' USING ERRCODE='42501'; END IF;
  IF p_content_version IS NOT NULL AND p_content_version<>public.englify_lesson_content_version(p_lesson_id) THEN
    RAISE SQLSTATE 'PT409' USING MESSAGE='Lesson content changed. Download it again';
  END IF;
  SELECT count(*) INTO v_question_count FROM public.quiz_questions
  WHERE lesson_id=p_lesson_id AND is_published AND archived_at IS NULL;
  IF v_question_count=0 OR v_question_count<>(SELECT count(*) FROM pg_catalog.jsonb_object_keys(p_answers))
     OR EXISTS (SELECT 1 FROM pg_catalog.jsonb_object_keys(p_answers) AS a(id)
        WHERE NOT EXISTS (SELECT 1 FROM public.quiz_questions q
          WHERE q.id::text=a.id AND q.lesson_id=p_lesson_id AND q.is_published AND q.archived_at IS NULL)) THEN
    RAISE EXCEPTION 'Submit one answer for every lesson question' USING ERRCODE='22023';
  END IF;
  SELECT EXISTS(SELECT 1 FROM public.lesson_attempts WHERE user_id=v_uid AND lesson_id=p_lesson_id AND passed)
    INTO v_prior_pass;
  v_attempt_id := gen_random_uuid();
  FOR v_question IN SELECT q.id,q.kind,k.answer AS answer_key FROM public.quiz_questions q
    LEFT JOIN public.quiz_answer_keys k ON k.question_id=q.id
    WHERE q.lesson_id=p_lesson_id AND q.is_published AND q.archived_at IS NULL ORDER BY q.position
  LOOP
    v_answer := p_answers->(v_question.id::text);
    IF v_question.kind='multiple_choice' THEN
      IF NOT EXISTS(SELECT 1 FROM public.quiz_options WHERE question_id=v_question.id AND is_correct) THEN
        RAISE EXCEPTION 'Lesson answer key is incomplete' USING ERRCODE='P0001';
      END IF;
      SELECT pg_catalog.jsonb_typeof(v_answer)='string' AND v_answer#>>'{}'=o.id::text
        INTO v_correct FROM public.quiz_options o WHERE o.question_id=v_question.id AND o.is_correct;
    ELSIF v_question.answer_key IS NULL THEN
      RAISE EXCEPTION 'Lesson answer key is incomplete' USING ERRCODE='P0001';
    ELSIF v_question.kind IN ('fill_blank','listening','grammar') THEN
      SELECT pg_catalog.jsonb_typeof(v_answer)='string' AND EXISTS(
        SELECT 1 FROM pg_catalog.jsonb_array_elements_text(v_question.answer_key) AS k(value)
        WHERE public.englify_normalize_answer(v_answer#>>'{}')=public.englify_normalize_answer(k.value))
        INTO v_correct;
    ELSIF v_question.kind='matching' THEN
      v_correct := pg_catalog.jsonb_typeof(v_answer)='object' AND v_answer=v_question.answer_key;
    ELSE v_correct := false;
    END IF;
    v_correct_count := v_correct_count + CASE WHEN coalesce(v_correct,false) THEN 1 ELSE 0 END;
  END LOOP;
  v_passed := v_correct_count*100 >= v_question_count*70;
  v_result_state := CASE WHEN v_state='mastered' OR (v_passed AND v_correct_count=v_question_count AND v_prior_pass)
    THEN 'mastered' WHEN v_passed THEN 'completed'
    WHEN v_state IN ('completed','mastered') THEN v_state ELSE 'in_progress' END;
  INSERT INTO public.lesson_attempts(id,user_id,lesson_id,request_id,correct_count,question_count,passed,result_state)
    VALUES(v_attempt_id,v_uid,p_lesson_id,p_request_id,v_correct_count,v_question_count,v_passed,v_result_state)
    RETURNING created_at INTO v_created_at;
  FOR v_question IN SELECT q.id,q.kind,k.answer AS answer_key FROM public.quiz_questions q
    LEFT JOIN public.quiz_answer_keys k ON k.question_id=q.id
    WHERE q.lesson_id=p_lesson_id AND q.is_published AND q.archived_at IS NULL ORDER BY q.position
  LOOP
    v_answer := p_answers->(v_question.id::text);
    IF v_question.kind='multiple_choice' THEN
      SELECT v_answer#>>'{}'=o.id::text INTO v_correct FROM public.quiz_options o
        WHERE o.question_id=v_question.id AND o.is_correct;
    ELSIF v_question.kind IN ('fill_blank','listening','grammar') THEN
      SELECT pg_catalog.jsonb_typeof(v_answer)='string' AND EXISTS(
        SELECT 1 FROM pg_catalog.jsonb_array_elements_text(v_question.answer_key) AS k(value)
        WHERE public.englify_normalize_answer(v_answer#>>'{}')=public.englify_normalize_answer(k.value)) INTO v_correct;
    ELSE v_correct := v_answer=v_question.answer_key; END IF;
    INSERT INTO public.lesson_answer_attempts(attempt_id,question_id,answer,is_correct)
      VALUES(v_attempt_id,v_question.id,v_answer,coalesce(v_correct,false));
  END LOOP;
  INSERT INTO public.learning_progress(user_id,lesson_id,status,completed_at)
    VALUES(v_uid,p_lesson_id,v_result_state,
      CASE WHEN v_result_state IN ('completed','mastered') THEN transaction_timestamp() ELSE NULL END)
    ON CONFLICT (user_id,lesson_id) DO UPDATE SET status=excluded.status,
      completed_at=coalesce(public.learning_progress.completed_at,excluded.completed_at);
  IF v_passed AND NOT v_prior_pass THEN
    SELECT level_xp_step,lesson_multiplier_percent INTO v_step,v_multiplier FROM public.gamification_config WHERE id=1;
    IF v_step IS NULL OR v_step<=0 THEN RAISE EXCEPTION 'Gamification rules unavailable' USING ERRCODE='P0001'; END IF;
    SELECT total_xp,level INTO v_before_total,v_before_level FROM public.user_levels WHERE user_id=v_uid;
    IF NOT FOUND THEN
      SELECT greatest(0,coalesce(sum(amount),0)) INTO v_before_total FROM public.xp_events WHERE user_id=v_uid;
      v_before_level := v_before_total/v_step+1;
    END IF;
    SELECT xp_reward INTO v_base_xp FROM public.lessons WHERE id=p_lesson_id;
    INSERT INTO public.xp_events(user_id,source_type,source_id,amount)
      SELECT v_uid,'lesson',p_lesson_id,v_base_xp*v_multiplier/100 WHERE v_base_xp*v_multiplier/100>0
      ON CONFLICT (user_id,source_type,source_id) DO NOTHING RETURNING amount INTO v_earned_xp;
    v_earned_xp := coalesce(v_earned_xp,0);
    IF v_earned_xp>0 THEN
      v_rewards := v_rewards||jsonb_build_array(jsonb_build_object('kind','xp','title','Lesson XP',
        'message','You earned '||v_earned_xp||' XP.','amount',v_earned_xp));
      INSERT INTO public.reward_notifications(user_id,kind,source_id,title,message)
        VALUES(v_uid,'xp',v_attempt_id,'Lesson XP','You earned '||v_earned_xp||' XP.')
        ON CONFLICT (user_id,kind,source_id) DO NOTHING;
    END IF;
    FOR v_quest IN SELECT * FROM public.quests WHERE is_active ORDER BY period,id LOOP
      v_start_day := CASE WHEN v_quest.period='daily' THEN (transaction_timestamp() AT TIME ZONE 'UTC')::date
        ELSE (transaction_timestamp() AT TIME ZONE 'UTC')::date
          -(extract(isodow from transaction_timestamp() AT TIME ZONE 'UTC')::int-1) END;
      v_period_start := v_start_day::timestamp AT TIME ZONE 'UTC';
      v_period_end := (v_start_day+CASE WHEN v_quest.period='daily' THEN 1 ELSE 7 END)::timestamp AT TIME ZONE 'UTC';
      IF (SELECT count(*) FROM public.learning_progress WHERE user_id=v_uid
          AND completed_at>=v_period_start AND completed_at<v_period_end)<v_quest.target_lessons THEN CONTINUE; END IF;
      INSERT INTO public.quest_claims(user_id,quest_id,period_start,awarded_xp)
        VALUES(v_uid,v_quest.id,v_start_day,v_quest.reward_xp)
        ON CONFLICT (user_id,quest_id,period_start) DO NOTHING RETURNING id INTO v_claim_id;
      IF v_claim_id IS NULL THEN CONTINUE; END IF;
      IF v_quest.reward_xp>0 THEN
        INSERT INTO public.xp_events(user_id,source_type,source_id,amount)
          VALUES(v_uid,'quest',v_claim_id,v_quest.reward_xp)
          ON CONFLICT (user_id,source_type,source_id) DO NOTHING;
      END IF;
      v_rewards := v_rewards||jsonb_build_array(jsonb_build_object('kind','quest','title',v_quest.title,
        'message','Quest completed!','amount',v_quest.reward_xp));
      INSERT INTO public.reward_notifications(user_id,kind,source_id,title,message)
        VALUES(v_uid,'quest',v_claim_id,v_quest.title,'Quest completed!')
        ON CONFLICT (user_id,kind,source_id) DO NOTHING;
    END LOOP;
    SELECT greatest(0,coalesce(sum(amount),0)) INTO v_total FROM public.xp_events WHERE user_id=v_uid;
    v_new_level := v_total/v_step+1;
    INSERT INTO public.user_levels(user_id,total_xp,level) VALUES(v_uid,v_total,v_new_level)
      ON CONFLICT (user_id) DO UPDATE SET total_xp=excluded.total_xp,level=excluded.level,updated_at=now();
    IF v_new_level>v_before_level THEN
      FOR i IN v_before_level+1..v_new_level LOOP
        v_level_id := pg_catalog.md5('englify-level:'||v_uid::text||':'||i::text)::uuid;
        v_rewards := v_rewards||jsonb_build_array(jsonb_build_object('kind','level','title','Level '||i,
          'message','Level up!','amount',0));
        INSERT INTO public.reward_notifications(user_id,kind,source_id,title,message)
          VALUES(v_uid,'level',v_level_id,'Level '||i,'Level up!')
          ON CONFLICT (user_id,kind,source_id) DO NOTHING;
      END LOOP;
    END IF;
    SELECT count(*) INTO v_completed FROM public.learning_progress WHERE user_id=v_uid
      AND status IN ('completed','mastered');
    FOR v_badge IN SELECT b.id,b.title,r.metric,r.target FROM public.badge_rules r
      JOIN public.badges b ON b.id=r.badge_id WHERE b.is_published AND b.archived_at IS NULL
      ORDER BY r.target,b.id LOOP
      IF (CASE WHEN v_badge.metric='completed_lessons' THEN v_completed ELSE v_total END)<v_badge.target THEN CONTINUE; END IF;
      INSERT INTO public.user_badges(user_id,badge_id) VALUES(v_uid,v_badge.id)
        ON CONFLICT (user_id,badge_id) DO NOTHING RETURNING id INTO v_badge_event_id;
      IF v_badge_event_id IS NULL THEN CONTINUE; END IF;
      v_rewards := v_rewards||jsonb_build_array(jsonb_build_object('kind','badge','title',v_badge.title,
        'message','Badge unlocked!','amount',0));
      INSERT INTO public.reward_notifications(user_id,kind,source_id,title,message)
        VALUES(v_uid,'badge',v_badge_event_id,v_badge.title,'Badge unlocked!')
        ON CONFLICT (user_id,kind,source_id) DO NOTHING;
    END LOOP;
  END IF;
  UPDATE public.lesson_attempts SET earned_xp=v_earned_xp,reward_payload=v_rewards WHERE id=v_attempt_id;
  RETURN jsonb_build_object('attempt_id',v_attempt_id,'correct_count',v_correct_count,
    'question_count',v_question_count,'passed',v_passed,'state',v_result_state,
    'earned_xp',v_earned_xp,'rewards',v_rewards,'created_at',v_created_at);
END $$;
REVOKE ALL ON FUNCTION public.englify_submit_lesson(uuid,uuid,jsonb,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_submit_lesson(uuid,uuid,jsonb,text) TO authenticated;
