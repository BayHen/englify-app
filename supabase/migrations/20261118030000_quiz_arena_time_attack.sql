-- Time Attack reuses Practice sessions/snapshots and the exact same answer semantics.
ALTER TABLE public.arena_sessions ADD COLUMN mode text NOT NULL DEFAULT 'practice' CHECK(mode IN ('practice','time_attack'));
ALTER TABLE public.arena_sessions ADD CONSTRAINT arena_sessions_id_user_key UNIQUE(id,user_id);
CREATE INDEX arena_sessions_mode_history ON public.arena_sessions(user_id,mode,started_at DESC,id);
CREATE FUNCTION public.englify_arena_grade(p_question jsonb,p_key jsonb,p_given jsonb) RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE v_correct boolean;
BEGIN
  IF p_given IS NULL THEN RAISE EXCEPTION 'Provide an answer' USING ERRCODE='22023'; END IF;
    IF p_question->>'kind' IN ('fill_blank','grammar_correction') THEN
      IF jsonb_typeof(p_given)<>'string' OR length(btrim(p_given#>>'{}')) NOT BETWEEN 1 AND 2000 THEN
        RAISE EXCEPTION 'Provide a nonempty text answer' USING ERRCODE='22023'; END IF;
      SELECT EXISTS(SELECT 1 FROM jsonb_array_elements_text(p_key) k WHERE public.englify_normalize_answer(p_given#>>'{}')=public.englify_normalize_answer(k)) INTO v_correct;
    ELSE
      IF p_question->>'kind' IN ('multiple_choice','reading') AND (jsonb_typeof(p_given)<>'string'
        OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_question->'options') o WHERE o->>'id'=p_given#>>'{}')) THEN
        RAISE EXCEPTION 'Choose an option from this question' USING ERRCODE='22023'; END IF;
      IF p_question->>'kind'='sentence_order' THEN
        IF jsonb_typeof(p_given)<>'array' THEN RAISE EXCEPTION 'Expected ordered token IDs' USING ERRCODE='22023'; END IF;
        IF jsonb_array_length(p_given)<>jsonb_array_length(p_question->'options')
          OR (SELECT count(DISTINCT v) FROM jsonb_array_elements(p_given) v)<>jsonb_array_length(p_given)
          OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(p_given) v WHERE NOT EXISTS(
            SELECT 1 FROM jsonb_array_elements(p_question->'options') o WHERE o->>'id'=v)) THEN
          RAISE EXCEPTION 'Use every sentence token exactly once' USING ERRCODE='22023'; END IF;
      END IF;
      IF p_question->>'kind'='matching' THEN
        IF jsonb_typeof(p_given)<>'object' THEN RAISE EXCEPTION 'Expected matching pairs' USING ERRCODE='22023'; END IF;
        IF (SELECT count(*) FROM jsonb_object_keys(p_given))<>jsonb_array_length(p_question->'left_items')
          OR (SELECT count(DISTINCT value) FROM jsonb_each_text(p_given))<>jsonb_array_length(p_question->'right_items')
          OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_question->'left_items') l WHERE NOT EXISTS(
            SELECT 1 FROM jsonb_array_elements(p_question->'right_items') r WHERE r->>'id'=p_given->>(l->>'id'))) THEN
          RAISE EXCEPTION 'Match every item exactly once using the provided choices' USING ERRCODE='22023'; END IF;
      END IF;
      IF jsonb_typeof(p_given)<>jsonb_typeof(p_key) OR p_given='null'::jsonb THEN
        RAISE EXCEPTION 'Invalid answer type' USING ERRCODE='22023'; END IF;
      IF p_question->>'kind'='sentence_order' THEN
        -- Identical words have interchangeable IDs; grade the visible token sequence.
        v_correct:=(SELECT jsonb_agg(o->>'text' ORDER BY t.n) FROM jsonb_array_elements_text(p_given) WITH ORDINALITY t(id,n)
          JOIN jsonb_array_elements(p_question->'options') o ON o->>'id'=t.id)
          =(SELECT jsonb_agg(o->>'text' ORDER BY t.n) FROM jsonb_array_elements_text(p_key) WITH ORDINALITY t(id,n)
          JOIN jsonb_array_elements(p_question->'options') o ON o->>'id'=t.id);
      ELSE v_correct:=p_given=p_key; END IF;
    END IF;
  RETURN coalesce(v_correct,false);
END $$;
REVOKE ALL ON FUNCTION public.englify_arena_grade(jsonb,jsonb,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.englify_arena_session(p_session_id uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_session public.arena_sessions%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT * INTO v_session FROM public.arena_sessions WHERE id=p_session_id AND user_id=auth.uid();
  IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Practice session not found'; END IF;
  IF v_session.mode<>'practice' THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Use the Time Attack API for this session'; END IF;
  IF v_session.status='active' AND EXISTS(SELECT 1 FROM public.arena_session_questions s JOIN public.arena_questions q ON q.id=s.question_id
      WHERE s.session_id=v_session.id AND (NOT q.is_published OR q.archived_at IS NOT NULL)) THEN
    RAISE SQLSTATE 'PT409' USING MESSAGE='A question was withdrawn. Start a new practice quiz.'; END IF;
  RETURN to_jsonb(v_session)-'user_id'-'request_id'||jsonb_build_object('questions',coalesce((
    SELECT jsonb_agg(question ORDER BY position) FROM public.arena_session_questions WHERE session_id=v_session.id AND v_session.status<>'abandoned'),'[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION public.englify_arena_start(p_request_id uuid,p_level text,p_topic text DEFAULT NULL,
  p_kind text DEFAULT NULL,p_count integer DEFAULT 5,p_difficulty integer DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_session public.arena_sessions%ROWTYPE; v_question record; v_position integer:=0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_request_id IS NULL OR p_level IS NULL OR p_level NOT IN ('A1','A2','B1','B2','C1') OR p_count IS NULL OR p_count NOT IN (5,10,15,20)
    OR (p_difficulty IS NOT NULL AND p_difficulty NOT BETWEEN 1 AND 3)
    OR (p_topic IS NOT NULL AND p_topic NOT IN ('grammar','vocabulary','reading','everyday','business','travel','sentence_structure','phrasal_verbs','idioms'))
    OR (p_kind IS NOT NULL AND p_kind NOT IN ('multiple_choice','fill_blank','matching','grammar_correction','sentence_order','reading')) THEN
    RAISE EXCEPTION 'Invalid practice configuration' USING ERRCODE='22023'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(v_uid::text));
  SELECT * INTO v_session FROM public.arena_sessions WHERE user_id=v_uid AND request_id=p_request_id;
  IF FOUND THEN
    IF v_session.mode<>'practice' THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Request ID belongs to Time Attack'; END IF;
    IF v_session.cefr_level<>p_level OR v_session.topic IS DISTINCT FROM p_topic OR v_session.kind IS DISTINCT FROM p_kind
      OR v_session.question_count<>p_count OR v_session.difficulty IS DISTINCT FROM p_difficulty THEN
      RAISE SQLSTATE 'PT409' USING MESSAGE='Request ID belongs to another configuration'; END IF;
    RETURN public.englify_arena_session(v_session.id);
  END IF;
  -- Keep at most ten unfinished sessions to bound accidental retry/new-session growth.
  IF (SELECT count(*) FROM public.arena_sessions WHERE user_id=v_uid AND status='active')>=10 THEN
    RAISE SQLSTATE 'PT409' USING MESSAGE='Resume or end an unfinished practice quiz first'; END IF;
  INSERT INTO public.arena_sessions(user_id,request_id,cefr_level,topic,kind,question_count,difficulty)
    VALUES(v_uid,p_request_id,p_level,p_topic,p_kind,p_count,p_difficulty) RETURNING * INTO v_session;
  FOR v_question IN SELECT q.*,k.answer,k.explanation_vi FROM public.arena_questions q JOIN public.arena_answer_keys k ON k.question_id=q.id
    WHERE q.is_published AND q.archived_at IS NULL AND q.cefr_level=p_level AND (p_topic IS NULL OR q.topic=p_topic)
      AND (p_kind IS NULL OR q.kind=p_kind) AND (p_difficulty IS NULL OR q.difficulty=p_difficulty)
    ORDER BY random() LIMIT p_count FOR SHARE OF q,k LOOP
    v_position:=v_position+1;
    INSERT INTO public.arena_session_questions(session_id,question_id,position,question,answer,explanation_vi) VALUES(v_session.id,v_question.id,v_position,
      jsonb_build_object('id',v_question.id,'kind',v_question.kind,'topic',v_question.topic,'cefr_level',v_question.cefr_level,
        'difficulty',v_question.difficulty,'prompt',v_question.prompt,'passage',v_question.passage,
        'options',public.englify_arena_items(v_question.options),'left_items',public.englify_arena_items(v_question.left_items),
        'right_items',public.englify_arena_items(v_question.right_items)),v_question.answer,v_question.explanation_vi);
  END LOOP;
  IF v_position<>p_count THEN RAISE SQLSTATE 'PT422' USING MESSAGE='Not enough published questions for these filters'; END IF;
  RETURN public.englify_arena_session(v_session.id);
END $$;

CREATE OR REPLACE FUNCTION public.englify_arena_submit(p_session_id uuid,p_answers jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_session public.arena_sessions%ROWTYPE; v_question record; v_given jsonb; v_correct boolean;
  v_count integer:=0; v_review jsonb:='[]'; v_xp integer:=0; v_claim uuid; v_total integer; v_step integer; v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(v_uid::text));
  SELECT * INTO v_session FROM public.arena_sessions WHERE id=p_session_id AND user_id=v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Practice session not found'; END IF;
  IF v_session.mode<>'practice' THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Use the Time Attack API for this session'; END IF;
  -- Session identity is the submission idempotency key. Completed results are immutable.
  IF v_session.status='completed' THEN RETURN public.englify_arena_session(v_session.id); END IF;
  IF v_session.status<>'active' THEN RAISE SQLSTATE 'PT409' USING MESSAGE='This practice session has ended'; END IF;
  IF p_answers IS NULL OR jsonb_typeof(p_answers)<>'object' OR octet_length(p_answers::text)>50000 THEN
    RAISE EXCEPTION 'Submit an answer object' USING ERRCODE='22023'; END IF;
  IF (SELECT count(*) FROM jsonb_object_keys(p_answers))<>v_session.question_count
    OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_answers) a WHERE NOT EXISTS(
      SELECT 1 FROM public.arena_session_questions q WHERE q.session_id=v_session.id AND q.question_id::text=a)) THEN
    RAISE EXCEPTION 'Answer every question in this session' USING ERRCODE='22023'; END IF;
  -- Lock publication state through grading. Edits cannot replace frozen answer semantics.
  PERFORM q.id FROM public.arena_questions q JOIN public.arena_session_questions s ON s.question_id=q.id WHERE s.session_id=v_session.id FOR SHARE OF q;
  PERFORM public.englify_arena_session(v_session.id);
  FOR v_question IN SELECT * FROM public.arena_session_questions WHERE session_id=v_session.id ORDER BY position LOOP
    v_given:=p_answers->(v_question.question_id::text);
    v_correct:=public.englify_arena_grade(v_question.question,v_question.answer,v_given);
    v_count:=v_count+CASE WHEN v_correct THEN 1 ELSE 0 END;
    v_review:=v_review||jsonb_build_array(jsonb_build_object('question',v_question.question,'given_answer',v_given,
      'correct_answer',v_question.answer,'correct',v_correct,'explanation_vi',v_question.explanation_vi));
  END LOOP;
  IF v_count*100>=v_session.question_count*70 THEN
    INSERT INTO public.arena_reward_claims(user_id,reward_day,session_id) VALUES(v_uid,(statement_timestamp() AT TIME ZONE 'UTC')::date,v_session.id)
      ON CONFLICT(user_id,reward_day) DO NOTHING RETURNING session_id INTO v_claim;
    IF v_claim IS NOT NULL THEN
      INSERT INTO public.xp_events(user_id,source_type,source_id,amount) VALUES(v_uid,'arena',v_session.id,10)
        ON CONFLICT(user_id,source_type,source_id) DO NOTHING RETURNING amount INTO v_xp;
      v_xp:=coalesce(v_xp,0);
      SELECT level_xp_step INTO v_step FROM public.gamification_config WHERE id=1;
      IF v_step IS NULL OR v_step<=0 THEN RAISE EXCEPTION 'Gamification configuration unavailable'; END IF;
      SELECT greatest(0,coalesce(sum(amount),0)) INTO v_total FROM public.xp_events WHERE user_id=v_uid;
      INSERT INTO public.user_levels(user_id,total_xp,level) VALUES(v_uid,v_total,v_total/v_step+1)
        ON CONFLICT(user_id) DO UPDATE SET total_xp=excluded.total_xp,level=excluded.level,updated_at=now();
      INSERT INTO public.reward_notifications(user_id,kind,source_id,title,message) VALUES(v_uid,'xp',v_session.id,'Quiz Practice','You earned 10 XP.')
        ON CONFLICT(user_id,kind,source_id) DO NOTHING;
    END IF;
  END IF;
  v_result:=jsonb_build_object('review',v_review,'review_topics',coalesce((SELECT jsonb_agg(topic ORDER BY topic) FROM (
    SELECT DISTINCT r#>>'{question,topic}' AS topic FROM jsonb_array_elements(v_review) r WHERE NOT (r->>'correct')::boolean) t),'[]'::jsonb));
  UPDATE public.arena_sessions SET status='completed',completed_at=statement_timestamp(),correct_count=v_count,
    accuracy=round(v_count*100.0/question_count,1),duration_seconds=greatest(0,floor(extract(epoch FROM statement_timestamp()-started_at)))::integer,
    earned_xp=v_xp,result=v_result WHERE id=v_session.id;
  RETURN public.englify_arena_session(v_session.id);
END $$;

CREATE OR REPLACE FUNCTION public.englify_arena_end(p_session_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text));
  IF EXISTS(SELECT 1 FROM public.arena_sessions WHERE id=p_session_id AND user_id=auth.uid() AND mode<>'practice') THEN
    RAISE SQLSTATE 'PT409' USING MESSAGE='Use the Time Attack API for this session'; END IF;
  UPDATE public.arena_sessions SET status='abandoned' WHERE id=p_session_id AND user_id=auth.uid() AND status='active';
  IF NOT FOUND AND NOT EXISTS(SELECT 1 FROM public.arena_sessions WHERE id=p_session_id AND user_id=auth.uid()) THEN
    RAISE SQLSTATE 'PT404' USING MESSAGE='Practice session not found'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.englify_arena_history(p_page integer DEFAULT 1) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_page IS NULL OR p_page NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'Invalid history page' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('page',p_page,'total',(SELECT count(*) FROM public.arena_sessions WHERE user_id=auth.uid() AND mode='practice'),
    'items',coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY started_at DESC,id) FROM (
      SELECT id,cefr_level,topic,kind,difficulty,question_count,status,started_at,completed_at,correct_count,accuracy,duration_seconds,earned_xp
      FROM public.arena_sessions WHERE user_id=auth.uid() AND mode='practice' ORDER BY started_at DESC,id LIMIT 10 OFFSET (p_page-1)*10) h),'[]'::jsonb));
END $$;

CREATE TABLE public.arena_time_attack_rules (
  difficulty text PRIMARY KEY CHECK(difficulty IN ('easy','normal','hard')),
  version integer NOT NULL DEFAULT 1 CHECK(version>0), question_count integer NOT NULL CHECK(question_count IN (5,10,15,20)),
  time_limit_seconds integer NOT NULL CHECK(time_limit_seconds BETWEEN 30 AND 600), initial_lives integer NOT NULL CHECK(initial_lives BETWEEN 1 AND 10),
  base_points integer NOT NULL DEFAULT 100 CHECK(base_points BETWEEN 1 AND 1000), enabled boolean NOT NULL DEFAULT true
);
INSERT INTO public.arena_time_attack_rules(difficulty,question_count,time_limit_seconds,initial_lives) VALUES('easy',10,180,5),('normal',10,120,3),('hard',15,120,2);
CREATE TABLE public.arena_time_attack_sessions (
  id uuid PRIMARY KEY, user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  FOREIGN KEY(id,user_id) REFERENCES public.arena_sessions(id,user_id) ON DELETE CASCADE,
  difficulty text NOT NULL REFERENCES public.arena_time_attack_rules(difficulty), rules_version integer NOT NULL CHECK(rules_version>0),
  question_count integer NOT NULL CHECK(question_count IN (5,10,15,20)), time_limit_seconds integer NOT NULL CHECK(time_limit_seconds BETWEEN 30 AND 600),
  initial_lives integer NOT NULL CHECK(initial_lives BETWEEN 1 AND 10), base_points integer NOT NULL CHECK(base_points BETWEEN 1 AND 1000),
  status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','completed','expired','abandoned')),
  completion_reason text CHECK(completion_reason IN ('all_questions','time_expired','no_lives','abandoned')),
  started_at timestamptz NOT NULL, expires_at timestamptz NOT NULL, question_started_at timestamptz,
  completed_at timestamptz, answered_count integer NOT NULL DEFAULT 0, correct_count integer NOT NULL DEFAULT 0,
  remaining_lives integer NOT NULL, combo integer NOT NULL DEFAULT 0, max_combo integer NOT NULL DEFAULT 0,
  score integer NOT NULL DEFAULT 0, duration_ms integer, is_personal_best boolean NOT NULL DEFAULT false,
  CHECK(expires_at=started_at+time_limit_seconds*interval '1 second'),
  CHECK(question_started_at IS NULL OR question_started_at>=started_at),
  CHECK(completed_at IS NULL OR completed_at BETWEEN started_at AND expires_at),
  CHECK(answered_count BETWEEN 0 AND question_count AND correct_count BETWEEN 0 AND answered_count),
  CHECK(remaining_lives BETWEEN 0 AND initial_lives AND combo>=0 AND max_combo>=combo AND score>=0),
  CHECK(duration_ms IS NULL OR duration_ms BETWEEN 0 AND time_limit_seconds*1000),
  CHECK((status='active' AND completed_at IS NULL AND completion_reason IS NULL) OR (status<>'active' AND completed_at IS NOT NULL AND completion_reason IS NOT NULL))
);
CREATE UNIQUE INDEX arena_time_attack_one_active ON public.arena_time_attack_sessions(user_id) WHERE status='active';
CREATE INDEX arena_time_attack_records ON public.arena_time_attack_sessions(user_id,difficulty,rules_version,score DESC,completed_at,id) WHERE status IN ('completed','expired');
CREATE INDEX arena_time_attack_history ON public.arena_time_attack_sessions(user_id,started_at DESC,id);
CREATE TABLE public.arena_time_attack_answers (
  session_id uuid NOT NULL REFERENCES public.arena_time_attack_sessions(id) ON DELETE CASCADE,
  question_id uuid NOT NULL, request_id uuid NOT NULL, position integer NOT NULL CHECK(position>0), given_answer jsonb NOT NULL,
  FOREIGN KEY(session_id,question_id) REFERENCES public.arena_session_questions(session_id,question_id),
  question_started_at timestamptz NOT NULL, accepted_at timestamptz NOT NULL CHECK(accepted_at>=question_started_at),
  elapsed_ms integer NOT NULL CHECK(elapsed_ms>=0), correct boolean NOT NULL,
  combo integer NOT NULL CHECK(combo>=0), multiplier_bps integer NOT NULL CHECK(multiplier_bps IN (10000,12000,15000,20000)),
  speed_bonus integer NOT NULL CHECK(speed_bonus IN (0,10,30,50)), points integer NOT NULL CHECK(points>=0),
  PRIMARY KEY(session_id,question_id), UNIQUE(session_id,request_id), UNIQUE(session_id,position)
);
CREATE INDEX arena_time_attack_answer_question ON public.arena_time_attack_answers(question_id);
ALTER TABLE public.arena_time_attack_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arena_time_attack_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arena_time_attack_answers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.arena_time_attack_rules,public.arena_time_attack_sessions,public.arena_time_attack_answers FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.arena_time_attack_rules TO authenticated;
CREATE POLICY time_attack_rules_read ON public.arena_time_attack_rules FOR SELECT TO authenticated USING(enabled OR public.englify_is_admin());
CREATE POLICY time_attack_rules_editor ON public.arena_time_attack_rules FOR ALL TO authenticated USING(public.englify_is_admin()) WITH CHECK(public.englify_is_admin());
GRANT SELECT ON public.arena_time_attack_sessions TO authenticated;
CREATE POLICY time_attack_owner ON public.arena_time_attack_sessions FOR SELECT TO authenticated USING(user_id=auth.uid());
GRANT ALL ON public.arena_time_attack_rules,public.arena_time_attack_sessions,public.arena_time_attack_answers TO service_role;

CREATE FUNCTION public.englify_time_attack_rule_guard() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF ROW(NEW.question_count,NEW.time_limit_seconds,NEW.initial_lives,NEW.base_points) IS DISTINCT FROM ROW(OLD.question_count,OLD.time_limit_seconds,OLD.initial_lives,OLD.base_points)
    AND NEW.version<=OLD.version THEN RAISE EXCEPTION 'Increment the rule version when changing game configuration' USING ERRCODE='22023'; END IF;
  IF NEW.version<OLD.version THEN RAISE EXCEPTION 'Rule versions cannot decrease' USING ERRCODE='22023'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER time_attack_rule_guard BEFORE UPDATE ON public.arena_time_attack_rules FOR EACH ROW EXECUTE FUNCTION public.englify_time_attack_rule_guard();
REVOKE ALL ON FUNCTION public.englify_time_attack_rule_guard() FROM PUBLIC,anon,authenticated;

-- Scoring v1: integer ceiling for elapsed milliseconds; integer floor for base*multiplier.
CREATE FUNCTION public.englify_time_attack_points(p_correct boolean,p_combo integer,p_elapsed_ms integer,p_base integer) RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE v_multiplier integer; v_bonus integer;
BEGIN
  IF p_correct IS NULL OR p_combo IS NULL OR p_combo<0 OR p_elapsed_ms IS NULL OR p_elapsed_ms<0 OR p_base IS NULL OR p_base NOT BETWEEN 1 AND 1000 THEN
    RAISE EXCEPTION 'Invalid scoring input' USING ERRCODE='22023'; END IF;
  v_multiplier:=CASE WHEN p_combo>=7 THEN 20000 WHEN p_combo>=5 THEN 15000 WHEN p_combo>=3 THEN 12000 ELSE 10000 END;
  v_bonus:=CASE WHEN NOT p_correct THEN 0 WHEN p_elapsed_ms<=3000 THEN 50 WHEN p_elapsed_ms<=6000 THEN 30 WHEN p_elapsed_ms<=10000 THEN 10 ELSE 0 END;
  RETURN jsonb_build_object('multiplier_bps',v_multiplier,'speed_bonus',v_bonus,'points',CASE WHEN p_correct THEN p_base*v_multiplier/10000+v_bonus ELSE 0 END);
END $$;
REVOKE ALL ON FUNCTION public.englify_time_attack_points(boolean,integer,integer,integer) FROM PUBLIC,anon,authenticated;

-- Caller holds the user's advisory lock and the session row lock.
CREATE FUNCTION public.englify_time_attack_close(p_id uuid,p_reason text,p_now timestamptz) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_session public.arena_time_attack_sessions%ROWTYPE; v_end timestamptz; v_status text; v_best integer;
BEGIN
  SELECT * INTO v_session FROM public.arena_time_attack_sessions WHERE id=p_id FOR UPDATE;
  IF NOT FOUND OR v_session.status<>'active' THEN RETURN; END IF;
  IF p_reason NOT IN ('all_questions','time_expired','no_lives','abandoned') THEN RAISE EXCEPTION 'Invalid completion reason'; END IF;
  v_end:=least(greatest(p_now,v_session.started_at),v_session.expires_at);
  v_status:=CASE WHEN p_reason='time_expired' THEN 'expired' WHEN p_reason='abandoned' THEN 'abandoned' ELSE 'completed' END;
  SELECT max(score) INTO v_best FROM public.arena_time_attack_sessions WHERE user_id=v_session.user_id AND difficulty=v_session.difficulty
    AND rules_version=v_session.rules_version AND status IN ('completed','expired');
  UPDATE public.arena_time_attack_sessions SET status=v_status,completion_reason=p_reason,completed_at=v_end,
    duration_ms=least(time_limit_seconds*1000,greatest(0,ceil(extract(epoch FROM v_end-started_at)*1000)::integer)),
    is_personal_best=v_status<>'abandoned' AND score>coalesce(v_best,-1) WHERE id=p_id;
  UPDATE public.arena_sessions SET status=CASE WHEN v_status='abandoned' THEN 'abandoned' ELSE 'completed' END,
    completed_at=v_end,correct_count=v_session.correct_count,accuracy=round(v_session.correct_count*100.0/question_count,1),
    duration_seconds=greatest(0,floor(extract(epoch FROM v_end-started_at)))::integer WHERE id=p_id;
END $$;
REVOKE ALL ON FUNCTION public.englify_time_attack_close(uuid,text,timestamptz) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.englify_time_attack_view(p_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_session public.arena_time_attack_sessions%ROWTYPE; v_parent public.arena_sessions%ROWTYPE; v_review jsonb; v_last jsonb; v_question jsonb;
BEGIN
  SELECT * INTO v_session FROM public.arena_time_attack_sessions WHERE id=p_id AND user_id=auth.uid();
  IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Time Attack session not found'; END IF;
  SELECT * INTO v_parent FROM public.arena_sessions WHERE id=p_id;
  IF v_session.status='active' AND v_session.question_started_at IS NOT NULL THEN
    SELECT q.question INTO v_question FROM public.arena_session_questions q JOIN public.arena_questions bank ON bank.id=q.question_id
      WHERE q.session_id=p_id AND q.position=v_session.answered_count+1 AND bank.is_published AND bank.archived_at IS NULL;
  END IF;
  SELECT jsonb_build_object('request_id',request_id,'question_id',question_id,'correct',correct,'combo',combo,
    'multiplier_bps',multiplier_bps,'speed_bonus',speed_bonus,'points',points) INTO v_last FROM public.arena_time_attack_answers WHERE session_id=p_id ORDER BY position DESC LIMIT 1;
  IF v_session.status<>'active' THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object('question',q.question,'given_answer',a.given_answer,'correct_answer',q.answer,
      'correct',a.correct,'explanation_vi',q.explanation_vi,'points',a.points,'speed_bonus',a.speed_bonus,'elapsed_ms',a.elapsed_ms) ORDER BY q.position),'[]'::jsonb)
      INTO v_review FROM public.arena_time_attack_answers a JOIN public.arena_session_questions q ON q.session_id=a.session_id AND q.question_id=a.question_id WHERE a.session_id=p_id;
  END IF;
  RETURN to_jsonb(v_session)-'user_id'||jsonb_build_object('cefr_level',v_parent.cefr_level,'server_now',clock_timestamp(),
    'current_question',v_question,'last_answer',v_last,'review',v_review,'accuracy',round(v_session.correct_count*100.0/v_session.question_count,1),'earned_xp',0);
END $$;
REVOKE ALL ON FUNCTION public.englify_time_attack_view(uuid) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.englify_time_attack_session(p_session_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_session public.arena_time_attack_sessions%ROWTYPE; v_now timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text));
  SELECT * INTO v_session FROM public.arena_time_attack_sessions WHERE id=p_session_id AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Time Attack session not found'; END IF;
  v_now:=clock_timestamp();
  IF v_session.status='active' THEN
    IF v_now>=v_session.expires_at THEN PERFORM public.englify_time_attack_close(p_session_id,'time_expired',v_now);
    ELSE
      PERFORM q.id FROM public.arena_questions q JOIN public.arena_session_questions s ON s.question_id=q.id
        WHERE s.session_id=p_session_id AND s.position=v_session.answered_count+1 FOR SHARE OF q;
      v_now:=clock_timestamp();
      IF v_now>=v_session.expires_at THEN PERFORM public.englify_time_attack_close(p_session_id,'time_expired',v_now);
      ELSIF NOT EXISTS(SELECT 1 FROM public.arena_session_questions s JOIN public.arena_questions q ON q.id=s.question_id
        WHERE s.session_id=p_session_id AND s.position=v_session.answered_count+1 AND q.is_published AND q.archived_at IS NULL) THEN
        PERFORM public.englify_time_attack_close(p_session_id,'abandoned',v_now);
      ELSIF v_session.question_started_at IS NULL THEN
        UPDATE public.arena_time_attack_sessions SET question_started_at=clock_timestamp() WHERE id=p_session_id;
      END IF;
    END IF;
  END IF;
  RETURN public.englify_time_attack_view(p_session_id);
END $$;

CREATE FUNCTION public.englify_time_attack_start(p_request_id uuid,p_level text,p_difficulty text DEFAULT 'normal') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_rules public.arena_time_attack_rules%ROWTYPE; v_parent public.arena_sessions%ROWTYPE; v_old record; v_id uuid; v_now timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_request_id IS NULL OR p_level IS NULL OR p_level NOT IN ('A1','A2','B1','B2','C1') OR p_difficulty IS NULL OR p_difficulty NOT IN ('easy','normal','hard') THEN
    RAISE EXCEPTION 'Invalid Time Attack configuration' USING ERRCODE='22023'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text));
  SELECT * INTO v_parent FROM public.arena_sessions WHERE user_id=auth.uid() AND request_id=p_request_id;
  IF FOUND THEN
    IF v_parent.mode<>'time_attack' OR v_parent.cefr_level<>p_level OR NOT EXISTS(SELECT 1 FROM public.arena_time_attack_sessions WHERE id=v_parent.id AND difficulty=p_difficulty) THEN
      RAISE SQLSTATE 'PT409' USING MESSAGE='Request ID belongs to another game configuration'; END IF;
    RETURN public.englify_time_attack_session(v_parent.id);
  END IF;
  FOR v_old IN SELECT id,expires_at FROM public.arena_time_attack_sessions WHERE user_id=auth.uid() AND status='active' FOR UPDATE LOOP
    IF clock_timestamp()>=v_old.expires_at THEN PERFORM public.englify_time_attack_close(v_old.id,'time_expired',clock_timestamp());
    ELSE RAISE SQLSTATE 'PT409' USING MESSAGE='Resume or end your active Time Attack first'; END IF;
  END LOOP;
  SELECT * INTO v_rules FROM public.arena_time_attack_rules WHERE difficulty=p_difficulty AND enabled FOR SHARE;
  IF NOT FOUND THEN RAISE SQLSTATE 'PT422' USING MESSAGE='This Time Attack difficulty is unavailable'; END IF;
  v_id:=(public.englify_arena_start(p_request_id,p_level,NULL,NULL,v_rules.question_count,NULL)->>'id')::uuid;
  v_now:=clock_timestamp();
  UPDATE public.arena_sessions SET mode='time_attack',started_at=v_now WHERE id=v_id;
  INSERT INTO public.arena_time_attack_sessions(id,user_id,difficulty,rules_version,question_count,time_limit_seconds,initial_lives,base_points,remaining_lives,started_at,expires_at,question_started_at)
    VALUES(v_id,auth.uid(),v_rules.difficulty,v_rules.version,v_rules.question_count,v_rules.time_limit_seconds,v_rules.initial_lives,v_rules.base_points,v_rules.initial_lives,v_now,v_now+v_rules.time_limit_seconds*interval '1 second',v_now);
  RETURN public.englify_time_attack_view(v_id);
END $$;

CREATE FUNCTION public.englify_time_attack_answer(p_session_id uuid,p_question_id uuid,p_request_id uuid,p_answer jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_session public.arena_time_attack_sessions%ROWTYPE; v_old public.arena_time_attack_answers%ROWTYPE; v_q record;
  v_now timestamptz; v_correct boolean; v_combo integer; v_elapsed integer; v_points jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_request_id IS NULL OR p_question_id IS NULL OR p_answer IS NULL OR octet_length(p_answer::text)>10000 THEN
    RAISE EXCEPTION 'Provide a question, request ID and answer' USING ERRCODE='22023'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text));
  SELECT * INTO v_session FROM public.arena_time_attack_sessions WHERE id=p_session_id AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Time Attack session not found'; END IF;
  SELECT * INTO v_old FROM public.arena_time_attack_answers WHERE session_id=p_session_id AND request_id=p_request_id;
  IF FOUND THEN
    IF v_old.question_id<>p_question_id OR v_old.given_answer<>p_answer THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Request ID belongs to another answer'; END IF;
    IF v_session.status='active' AND clock_timestamp()>=v_session.expires_at THEN PERFORM public.englify_time_attack_close(p_session_id,'time_expired',clock_timestamp()); END IF;
    RETURN public.englify_time_attack_view(p_session_id);
  END IF;
  IF EXISTS(SELECT 1 FROM public.arena_time_attack_answers WHERE session_id=p_session_id AND question_id=p_question_id) THEN
    RAISE SQLSTATE 'PT409' USING MESSAGE='This question has already been answered'; END IF;
  IF v_session.status<>'active' THEN RAISE SQLSTATE 'PT409' USING MESSAGE='This Time Attack has ended'; END IF;
  v_now:=clock_timestamp();
  IF v_now>=v_session.expires_at THEN
    PERFORM public.englify_time_attack_close(p_session_id,'time_expired',v_now);
    RETURN public.englify_time_attack_view(p_session_id);
  END IF;
  SELECT * INTO v_q FROM public.arena_session_questions WHERE session_id=p_session_id AND position=v_session.answered_count+1;
  IF v_q.question_id<>p_question_id OR v_session.question_started_at IS NULL THEN
    RAISE SQLSTATE 'PT409' USING MESSAGE='Answer only the currently issued question'; END IF;
  PERFORM id FROM public.arena_questions WHERE id=p_question_id FOR SHARE;
  IF NOT EXISTS(SELECT 1 FROM public.arena_questions WHERE id=p_question_id AND is_published AND archived_at IS NULL) THEN
    PERFORM public.englify_time_attack_close(p_session_id,'abandoned',clock_timestamp());RETURN public.englify_time_attack_view(p_session_id); END IF;
  -- Receipt is observed after database locks; waiting for the server/network is not a client-reported reaction time.
  v_now:=clock_timestamp();
  IF v_now>=v_session.expires_at THEN PERFORM public.englify_time_attack_close(p_session_id,'time_expired',v_now);RETURN public.englify_time_attack_view(p_session_id); END IF;
  v_correct:=public.englify_arena_grade(v_q.question,v_q.answer,p_answer);
  v_combo:=CASE WHEN v_correct THEN v_session.combo+1 ELSE 0 END;
  v_elapsed:=greatest(0,ceil(extract(epoch FROM v_now-v_session.question_started_at)*1000)::integer);
  v_points:=public.englify_time_attack_points(v_correct,v_combo,v_elapsed,v_session.base_points);
  INSERT INTO public.arena_time_attack_answers(session_id,question_id,request_id,position,given_answer,question_started_at,accepted_at,elapsed_ms,correct,combo,multiplier_bps,speed_bonus,points)
    VALUES(p_session_id,p_question_id,p_request_id,v_q.position,p_answer,v_session.question_started_at,v_now,v_elapsed,v_correct,v_combo,
      (v_points->>'multiplier_bps')::integer,(v_points->>'speed_bonus')::integer,(v_points->>'points')::integer);
  UPDATE public.arena_time_attack_sessions SET answered_count=answered_count+1,correct_count=correct_count+CASE WHEN v_correct THEN 1 ELSE 0 END,
    remaining_lives=remaining_lives-CASE WHEN v_correct THEN 0 ELSE 1 END,combo=v_combo,max_combo=greatest(max_combo,v_combo),
    score=score+(v_points->>'points')::integer,question_started_at=NULL WHERE id=p_session_id RETURNING * INTO v_session;
  IF v_session.remaining_lives=0 THEN PERFORM public.englify_time_attack_close(p_session_id,'no_lives',v_now);
  ELSIF v_session.answered_count=v_session.question_count THEN PERFORM public.englify_time_attack_close(p_session_id,'all_questions',v_now); END IF;
  RETURN public.englify_time_attack_view(p_session_id);
END $$;

CREATE FUNCTION public.englify_time_attack_finish(p_session_id uuid,p_abandon boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_session public.arena_time_attack_sessions%ROWTYPE; v_now timestamptz;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_abandon IS NULL THEN RAISE EXCEPTION 'Invalid finish request' USING ERRCODE='22023'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text));
  SELECT * INTO v_session FROM public.arena_time_attack_sessions WHERE id=p_session_id AND user_id=auth.uid() FOR UPDATE;
  IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Time Attack session not found'; END IF;
  v_now:=clock_timestamp();
  IF v_session.status='active' THEN
    IF v_now>=v_session.expires_at THEN PERFORM public.englify_time_attack_close(p_session_id,'time_expired',v_now);
    ELSIF p_abandon THEN PERFORM public.englify_time_attack_close(p_session_id,'abandoned',v_now); END IF;
  END IF;
  RETURN public.englify_time_attack_view(p_session_id);
END $$;

CREATE FUNCTION public.englify_time_attack_history(p_page integer DEFAULT 1) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_old record;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_page IS NULL OR p_page NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'Invalid history page' USING ERRCODE='22023'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text));
  FOR v_old IN SELECT id FROM public.arena_time_attack_sessions WHERE user_id=auth.uid() AND status='active' AND expires_at<=clock_timestamp() FOR UPDATE LOOP
    PERFORM public.englify_time_attack_close(v_old.id,'time_expired',clock_timestamp()); END LOOP;
  RETURN jsonb_build_object('page',p_page,'total',(SELECT count(*) FROM public.arena_time_attack_sessions WHERE user_id=auth.uid()),'items',coalesce((
    SELECT jsonb_agg(to_jsonb(t) ORDER BY started_at DESC,id) FROM (
      SELECT s.id,s.difficulty,s.rules_version,s.status,s.completion_reason,s.score,s.max_combo,s.correct_count,s.answered_count,s.question_count,s.started_at,s.completed_at,s.duration_ms,p.cefr_level
      FROM public.arena_time_attack_sessions s JOIN public.arena_sessions p ON p.id=s.id WHERE s.user_id=auth.uid() ORDER BY s.started_at DESC,s.id LIMIT 10 OFFSET(p_page-1)*10) t),'[]'::jsonb));
END $$;
CREATE FUNCTION public.englify_time_attack_records() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  PERFORM public.englify_time_attack_history(1);
  RETURN jsonb_build_object('rules',(SELECT jsonb_agg(to_jsonb(r) ORDER BY time_limit_seconds DESC,initial_lives DESC) FROM public.arena_time_attack_rules r WHERE enabled),
    'total_sessions',(SELECT count(*) FROM public.arena_time_attack_sessions WHERE user_id=auth.uid()),
    'completed_sessions',(SELECT count(*) FROM public.arena_time_attack_sessions WHERE user_id=auth.uid() AND status IN ('completed','expired')),
    'highest_combo',(SELECT coalesce(max(max_combo),0) FROM public.arena_time_attack_sessions WHERE user_id=auth.uid() AND status IN ('completed','expired')),
    'records',coalesce((SELECT jsonb_agg(to_jsonb(b) ORDER BY difficulty) FROM (
      SELECT r.difficulty,r.version AS rules_version,count(s.id)::integer AS sessions,coalesce(max(s.score),0) AS highest_score,
        coalesce(max(round(s.correct_count*100.0/s.question_count,1)),0) AS best_accuracy,coalesce(max(s.max_combo),0) AS highest_combo,
        min(s.duration_ms) FILTER(WHERE s.completion_reason='all_questions' AND s.correct_count*100>=s.question_count*70) AS fastest_completion_ms,
        (array_agg(s.id ORDER BY s.score DESC,s.completed_at,s.id) FILTER(WHERE s.id IS NOT NULL))[1] AS best_session_id
      FROM public.arena_time_attack_rules r LEFT JOIN public.arena_time_attack_sessions s ON s.difficulty=r.difficulty AND s.rules_version=r.version
        AND s.user_id=auth.uid() AND s.status IN ('completed','expired') GROUP BY r.difficulty,r.version) b),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.englify_time_attack_session(uuid),public.englify_time_attack_start(uuid,text,text),
  public.englify_time_attack_answer(uuid,uuid,uuid,jsonb),public.englify_time_attack_finish(uuid,boolean),
  public.englify_time_attack_history(integer),public.englify_time_attack_records() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_time_attack_session(uuid),public.englify_time_attack_start(uuid,text,text),
  public.englify_time_attack_answer(uuid,uuid,uuid,jsonb),public.englify_time_attack_finish(uuid,boolean),
  public.englify_time_attack_history(integer),public.englify_time_attack_records() TO authenticated;
