-- Independent Practice adapter: Journey question semantics and records stay unchanged.
CREATE TABLE public.arena_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text NOT NULL UNIQUE,
  cefr_level text NOT NULL CHECK (cefr_level IN ('A1','A2','B1','B2','C1')),
  topic text NOT NULL CHECK (topic IN ('grammar','vocabulary','reading','everyday','business','travel','sentence_structure','phrasal_verbs','idioms')),
  kind text NOT NULL CHECK (kind IN ('multiple_choice','fill_blank','matching','grammar_correction','sentence_order','reading')),
  difficulty integer NOT NULL CHECK (difficulty BETWEEN 1 AND 3),
  prompt text NOT NULL CHECK (length(prompt) BETWEEN 1 AND 2000), passage text,
  options jsonb NOT NULL DEFAULT '[]', left_items jsonb NOT NULL DEFAULT '[]', right_items jsonb NOT NULL DEFAULT '[]',
  is_published boolean NOT NULL DEFAULT false, archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (jsonb_typeof(options)='array' AND jsonb_typeof(left_items)='array' AND jsonb_typeof(right_items)='array')
);
CREATE INDEX arena_questions_catalog ON public.arena_questions(cefr_level,topic,kind,difficulty) WHERE is_published AND archived_at IS NULL;
CREATE TABLE public.arena_answer_keys (
  question_id uuid PRIMARY KEY REFERENCES public.arena_questions(id) ON DELETE CASCADE,
  answer jsonb NOT NULL, explanation_vi text NOT NULL CHECK (length(btrim(explanation_vi)) BETWEEN 1 AND 3000)
);
CREATE TABLE public.arena_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  request_id uuid NOT NULL, cefr_level text NOT NULL CHECK (cefr_level IN ('A1','A2','B1','B2','C1')),
  topic text, kind text, difficulty integer, question_count integer NOT NULL CHECK (question_count IN (5,10,15,20)),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','abandoned')),
  started_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz,
  correct_count integer CHECK (correct_count BETWEEN 0 AND question_count), accuracy numeric,
  duration_seconds integer CHECK (duration_seconds>=0), earned_xp integer NOT NULL DEFAULT 0 CHECK (earned_xp IN (0,10)),
  result jsonb, UNIQUE(user_id,request_id)
);
CREATE INDEX arena_sessions_user_history ON public.arena_sessions(user_id,started_at DESC,id);
-- Public question snapshots and private keys are frozen together at session creation.
CREATE TABLE public.arena_session_questions (
  session_id uuid NOT NULL REFERENCES public.arena_sessions(id) ON DELETE CASCADE,
  question_id uuid NOT NULL REFERENCES public.arena_questions(id), position integer NOT NULL CHECK (position>0),
  question jsonb NOT NULL, answer jsonb NOT NULL, explanation_vi text NOT NULL,
  PRIMARY KEY(session_id,position), UNIQUE(session_id,question_id)
);
CREATE INDEX arena_session_questions_question ON public.arena_session_questions(question_id);
CREATE TABLE public.arena_reward_claims (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reward_day date NOT NULL, session_id uuid NOT NULL UNIQUE REFERENCES public.arena_sessions(id),
  PRIMARY KEY(user_id,reward_day)
);
ALTER TABLE public.xp_events DROP CONSTRAINT xp_events_source_type_check;
ALTER TABLE public.xp_events ADD CONSTRAINT xp_events_source_type_check CHECK (
  source_type IN ('lesson','quiz','review','speaking','writing','adjustment','quest','arena'));

ALTER TABLE public.arena_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arena_answer_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arena_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arena_session_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arena_reward_claims ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.arena_questions,public.arena_answer_keys,public.arena_sessions,
  public.arena_session_questions,public.arena_reward_claims FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.arena_questions,public.arena_answer_keys TO authenticated;
CREATE POLICY arena_editor ON public.arena_questions FOR ALL TO authenticated USING(public.englify_is_admin()) WITH CHECK(public.englify_is_admin());
CREATE POLICY arena_key_editor ON public.arena_answer_keys FOR ALL TO authenticated USING(public.englify_is_admin()) WITH CHECK(public.englify_is_admin());
GRANT SELECT ON public.arena_sessions,public.arena_reward_claims TO authenticated;
CREATE POLICY arena_session_owner ON public.arena_sessions FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE POLICY arena_claim_owner ON public.arena_reward_claims FOR SELECT TO authenticated USING(user_id=auth.uid());
GRANT ALL ON public.arena_questions,public.arena_answer_keys,public.arena_sessions,
  public.arena_session_questions,public.arena_reward_claims TO service_role;

-- Explicit allowlist: editorial metadata must not accidentally expose a key in options.
CREATE FUNCTION public.englify_arena_items(p_items jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',v->>'id','text',v->>'text') ORDER BY n),'[]'::jsonb)
  FROM jsonb_array_elements(p_items) WITH ORDINALITY item(v,n)
$$;
REVOKE ALL ON FUNCTION public.englify_arena_items(jsonb) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.englify_arena_publish_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_key jsonb; v_items jsonb; v_answer text;
BEGIN
  IF NOT NEW.is_published OR NEW.archived_at IS NOT NULL THEN RETURN NEW; END IF;
  SELECT answer INTO v_key FROM public.arena_answer_keys WHERE question_id=NEW.id;
  IF v_key IS NULL THEN RAISE EXCEPTION 'Add an answer key before publishing' USING ERRCODE='22023'; END IF;
  FOREACH v_items IN ARRAY ARRAY[NEW.options,NEW.left_items,NEW.right_items] LOOP
    IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_items) v WHERE jsonb_typeof(v)<>'object' OR jsonb_typeof(v->'id')<>'string' OR jsonb_typeof(v->'text')<>'string'
      OR coalesce(length(v->>'id'),0)=0 OR coalesce(length(v->>'text'),0)=0)
      OR (SELECT count(*) FROM jsonb_array_elements(v_items))<>(SELECT count(DISTINCT v->>'id') FROM jsonb_array_elements(v_items) v) THEN
      RAISE EXCEPTION 'Question items require unique IDs and text' USING ERRCODE='22023'; END IF;
  END LOOP;
  IF NEW.kind IN ('multiple_choice','reading') THEN
    IF jsonb_typeof(v_key)<>'string' OR jsonb_array_length(NEW.options)<2
      OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.options) o WHERE o->>'id'=v_key#>>'{}')
      OR (NEW.kind='reading' AND coalesce(length(btrim(NEW.passage)),0)=0) THEN
      RAISE EXCEPTION 'Invalid choice or reading question' USING ERRCODE='22023'; END IF;
  ELSIF NEW.kind IN ('fill_blank','grammar_correction') THEN
    IF jsonb_typeof(v_key)<>'array' THEN RAISE EXCEPTION 'Expected accepted text answers' USING ERRCODE='22023'; END IF;
    IF jsonb_array_length(v_key)=0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(v_key) v WHERE jsonb_typeof(v)<>'string' OR length(btrim(v#>>'{}'))=0) THEN
      RAISE EXCEPTION 'Expected nonempty text answers' USING ERRCODE='22023'; END IF;
  ELSIF NEW.kind='sentence_order' THEN
    IF jsonb_typeof(v_key)<>'array' THEN RAISE EXCEPTION 'Expected ordered token IDs' USING ERRCODE='22023'; END IF;
    IF jsonb_array_length(v_key)<2 OR jsonb_array_length(v_key)<>jsonb_array_length(NEW.options)
      OR (SELECT count(DISTINCT v) FROM jsonb_array_elements(v_key) v)<>jsonb_array_length(v_key)
      OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(v_key) v WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.options) o WHERE o->>'id'=v)) THEN
      RAISE EXCEPTION 'Sentence order must contain each token once' USING ERRCODE='22023'; END IF;
  ELSIF NEW.kind='matching' THEN
    IF jsonb_typeof(v_key)<>'object' THEN RAISE EXCEPTION 'Expected matching pairs' USING ERRCODE='22023'; END IF;
    IF jsonb_array_length(NEW.left_items)<2 OR jsonb_array_length(NEW.left_items)<>jsonb_array_length(NEW.right_items)
      OR (SELECT count(*) FROM jsonb_object_keys(v_key))<>jsonb_array_length(NEW.left_items)
      OR (SELECT count(DISTINCT value) FROM jsonb_each_text(v_key))<>jsonb_array_length(NEW.right_items)
      OR EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.left_items) l WHERE NOT EXISTS(
        SELECT 1 FROM jsonb_array_elements(NEW.right_items) r WHERE r->>'id'=v_key->>(l->>'id'))) THEN
      RAISE EXCEPTION 'Matching key must map every item exactly once' USING ERRCODE='22023'; END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_arena_publish_guard() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER arena_publish_guard BEFORE INSERT OR UPDATE ON public.arena_questions FOR EACH ROW EXECUTE FUNCTION public.englify_arena_publish_guard();
-- Published keys cannot be edited independently of their validated question.
CREATE FUNCTION public.englify_arena_key_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF TG_OP='INSERT' AND EXISTS(SELECT 1 FROM public.arena_answer_keys WHERE question_id=NEW.question_id AND answer=NEW.answer AND explanation_vi=NEW.explanation_vi) THEN RETURN NEW; END IF;
  IF EXISTS(SELECT 1 FROM public.arena_questions WHERE id=coalesce(NEW.question_id,OLD.question_id) AND is_published AND archived_at IS NULL) THEN
    RAISE EXCEPTION 'Unpublish the Arena question before changing its key' USING ERRCODE='22023'; END IF;
  RETURN coalesce(NEW,OLD);
END $$;
REVOKE ALL ON FUNCTION public.englify_arena_key_guard() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER arena_key_guard BEFORE INSERT OR UPDATE OR DELETE ON public.arena_answer_keys FOR EACH ROW EXECUTE FUNCTION public.englify_arena_key_guard();

CREATE FUNCTION public.englify_arena_catalog() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  RETURN jsonb_build_object('groups',coalesce((SELECT jsonb_agg(to_jsonb(g) ORDER BY cefr_level,topic,kind,difficulty) FROM (
    SELECT cefr_level,topic,kind,difficulty,count(*)::integer AS available FROM public.arena_questions
    WHERE is_published AND archived_at IS NULL GROUP BY cefr_level,topic,kind,difficulty) g),'[]'::jsonb),
    'daily_reward_xp',10,'reward_threshold',70);
END $$;

CREATE FUNCTION public.englify_arena_session(p_session_id uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_session public.arena_sessions%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT * INTO v_session FROM public.arena_sessions WHERE id=p_session_id AND user_id=auth.uid();
  IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Practice session not found'; END IF;
  IF v_session.status='active' AND EXISTS(SELECT 1 FROM public.arena_session_questions s JOIN public.arena_questions q ON q.id=s.question_id
      WHERE s.session_id=v_session.id AND (NOT q.is_published OR q.archived_at IS NOT NULL)) THEN
    RAISE SQLSTATE 'PT409' USING MESSAGE='A question was withdrawn. Start a new practice quiz.'; END IF;
  RETURN to_jsonb(v_session)-'user_id'-'request_id'||jsonb_build_object('questions',coalesce((
    SELECT jsonb_agg(question ORDER BY position) FROM public.arena_session_questions WHERE session_id=v_session.id AND v_session.status<>'abandoned'),'[]'::jsonb));
END $$;

CREATE FUNCTION public.englify_arena_start(p_request_id uuid,p_level text,p_topic text DEFAULT NULL,
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

CREATE FUNCTION public.englify_arena_submit(p_session_id uuid,p_answers jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_session public.arena_sessions%ROWTYPE; v_question record; v_given jsonb; v_correct boolean;
  v_count integer:=0; v_review jsonb:='[]'; v_xp integer:=0; v_claim uuid; v_total integer; v_step integer; v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(v_uid::text));
  SELECT * INTO v_session FROM public.arena_sessions WHERE id=p_session_id AND user_id=v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Practice session not found'; END IF;
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
    IF v_question.question->>'kind' IN ('fill_blank','grammar_correction') THEN
      IF jsonb_typeof(v_given)<>'string' OR length(btrim(v_given#>>'{}')) NOT BETWEEN 1 AND 2000 THEN
        RAISE EXCEPTION 'Provide a nonempty text answer' USING ERRCODE='22023'; END IF;
      SELECT EXISTS(SELECT 1 FROM jsonb_array_elements_text(v_question.answer) k WHERE public.englify_normalize_answer(v_given#>>'{}')=public.englify_normalize_answer(k)) INTO v_correct;
    ELSE
      IF v_question.question->>'kind' IN ('multiple_choice','reading') AND (jsonb_typeof(v_given)<>'string'
        OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_question.question->'options') o WHERE o->>'id'=v_given#>>'{}')) THEN
        RAISE EXCEPTION 'Choose an option from this question' USING ERRCODE='22023'; END IF;
      IF v_question.question->>'kind'='sentence_order' THEN
        IF jsonb_typeof(v_given)<>'array' THEN RAISE EXCEPTION 'Expected ordered token IDs' USING ERRCODE='22023'; END IF;
        IF jsonb_array_length(v_given)<>jsonb_array_length(v_question.question->'options')
          OR (SELECT count(DISTINCT v) FROM jsonb_array_elements(v_given) v)<>jsonb_array_length(v_given)
          OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(v_given) v WHERE NOT EXISTS(
            SELECT 1 FROM jsonb_array_elements(v_question.question->'options') o WHERE o->>'id'=v)) THEN
          RAISE EXCEPTION 'Use every sentence token exactly once' USING ERRCODE='22023'; END IF;
      END IF;
      IF v_question.question->>'kind'='matching' THEN
        IF jsonb_typeof(v_given)<>'object' THEN RAISE EXCEPTION 'Expected matching pairs' USING ERRCODE='22023'; END IF;
        IF (SELECT count(*) FROM jsonb_object_keys(v_given))<>jsonb_array_length(v_question.question->'left_items')
          OR (SELECT count(DISTINCT value) FROM jsonb_each_text(v_given))<>jsonb_array_length(v_question.question->'right_items')
          OR EXISTS(SELECT 1 FROM jsonb_array_elements(v_question.question->'left_items') l WHERE NOT EXISTS(
            SELECT 1 FROM jsonb_array_elements(v_question.question->'right_items') r WHERE r->>'id'=v_given->>(l->>'id'))) THEN
          RAISE EXCEPTION 'Match every item exactly once using the provided choices' USING ERRCODE='22023'; END IF;
      END IF;
      IF jsonb_typeof(v_given)<>jsonb_typeof(v_question.answer) OR v_given='null'::jsonb THEN
        RAISE EXCEPTION 'Invalid answer type' USING ERRCODE='22023'; END IF;
      IF v_question.question->>'kind'='sentence_order' THEN
        -- Identical words have interchangeable IDs; grade the visible token sequence.
        v_correct:=(SELECT jsonb_agg(o->>'text' ORDER BY t.n) FROM jsonb_array_elements_text(v_given) WITH ORDINALITY t(id,n)
          JOIN jsonb_array_elements(v_question.question->'options') o ON o->>'id'=t.id)
          =(SELECT jsonb_agg(o->>'text' ORDER BY t.n) FROM jsonb_array_elements_text(v_question.answer) WITH ORDINALITY t(id,n)
          JOIN jsonb_array_elements(v_question.question->'options') o ON o->>'id'=t.id);
      ELSE v_correct:=v_given=v_question.answer; END IF;
    END IF;
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

CREATE FUNCTION public.englify_arena_end(p_session_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text));
  UPDATE public.arena_sessions SET status='abandoned' WHERE id=p_session_id AND user_id=auth.uid() AND status='active';
  IF NOT FOUND AND NOT EXISTS(SELECT 1 FROM public.arena_sessions WHERE id=p_session_id AND user_id=auth.uid()) THEN
    RAISE SQLSTATE 'PT404' USING MESSAGE='Practice session not found'; END IF;
END $$;
CREATE FUNCTION public.englify_arena_history(p_page integer DEFAULT 1) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_page IS NULL OR p_page NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'Invalid history page' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('page',p_page,'total',(SELECT count(*) FROM public.arena_sessions WHERE user_id=auth.uid()),
    'items',coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY started_at DESC,id) FROM (
      SELECT id,cefr_level,topic,kind,difficulty,question_count,status,started_at,completed_at,correct_count,accuracy,duration_seconds,earned_xp
      FROM public.arena_sessions WHERE user_id=auth.uid() ORDER BY started_at DESC,id LIMIT 10 OFFSET (p_page-1)*10) h),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.englify_arena_catalog(),public.englify_arena_session(uuid),
  public.englify_arena_start(uuid,text,text,text,integer,integer),public.englify_arena_submit(uuid,jsonb),
  public.englify_arena_end(uuid),public.englify_arena_history(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_arena_catalog(),public.englify_arena_session(uuid),
  public.englify_arena_start(uuid,text,text,text,integer,integer),public.englify_arena_submit(uuid,jsonb),
  public.englify_arena_end(uuid),public.englify_arena_history(integer) TO authenticated;
