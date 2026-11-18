-- Writing V2.2: additive CEFR catalog. Existing exercise IDs and submissions remain valid.
CREATE TABLE public.writing_topics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text NOT NULL UNIQUE,
  title text NOT NULL CHECK (length(title) BETWEEN 1 AND 100),
  description text NOT NULL CHECK (length(description) BETWEEN 1 AND 500),
  icon text, is_published boolean NOT NULL DEFAULT false,
  sort_order integer NOT NULL DEFAULT 0 CHECK (sort_order BETWEEN 0 AND 1000),
  archived_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.writing_topics ENABLE ROW LEVEL SECURITY;
CREATE POLICY writing_topics_read ON public.writing_topics FOR SELECT TO authenticated
  USING ((is_published AND archived_at IS NULL) OR public.englify_is_admin());
CREATE POLICY writing_topics_admin ON public.writing_topics FOR ALL TO authenticated
  USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin());
GRANT SELECT,INSERT,UPDATE,DELETE ON public.writing_topics TO authenticated;
GRANT ALL ON public.writing_topics TO service_role;
CREATE INDEX writing_topics_published_order_idx ON public.writing_topics(sort_order,id) WHERE is_published AND archived_at IS NULL;
CREATE TRIGGER trg_writing_topics_updated_at BEFORE UPDATE ON public.writing_topics
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

INSERT INTO public.writing_topics(id,slug,title,description,icon,is_published,sort_order) VALUES
('51000000-0000-4000-8000-000000000001','daily-life','Daily Life','Write about routines, plans, and everyday situations.','calendar_today',true,10),
('51000000-0000-4000-8000-000000000002','family-friends','Family & Friends','Describe relationships and communicate with people close to you.','groups',true,20),
('51000000-0000-4000-8000-000000000003','school-education','School & Education','Practice classroom, study, and education-related writing.','school',true,30),
('51000000-0000-4000-8000-000000000004','work-career','Work & Career','Build practical workplace and career communication skills.','work',true,40),
('51000000-0000-4000-8000-000000000005','travel-culture','Travel & Culture','Write about journeys, places, customs, and cultural experiences.','flight',true,50),
('51000000-0000-4000-8000-000000000006','technology','Technology','Explain how technology affects daily life, study, and work.','devices',true,60),
('51000000-0000-4000-8000-000000000007','health-lifestyle','Health & Lifestyle','Communicate about habits, wellbeing, and healthy choices.','favorite',true,70),
('51000000-0000-4000-8000-000000000008','business-english','Business English','Practice clear, professional business communication.','business_center',true,80),
('51000000-0000-4000-8000-000000000009','email-writing','Email Writing','Write purposeful informal, formal, and professional emails.','mail',true,90),
('51000000-0000-4000-8000-000000000010','ielts-writing','IELTS Writing Practice','Practice exam-style tasks without claiming an official IELTS score.','edit_note',true,100)
ON CONFLICT(slug) DO NOTHING;

ALTER TABLE public.writing_exercises
  ADD COLUMN topic_id uuid REFERENCES public.writing_topics(id) ON DELETE SET NULL,
  ADD COLUMN cefr_level text NOT NULL DEFAULT 'A1',
  ADD COLUMN title text NOT NULL DEFAULT 'Writing practice',
  ADD COLUMN instructions text,
  ADD COLUMN min_words integer,
  ADD COLUMN recommended_words integer,
  ADD COLUMN estimated_minutes integer,
  ADD COLUMN difficulty integer NOT NULL DEFAULT 1,
  ADD COLUMN archived_at timestamptz;
UPDATE public.writing_exercises SET title=left(prompt,160),instructions=nullif(hint,''),
  topic_id='51000000-0000-4000-8000-000000000001' WHERE title='Writing practice';
ALTER TABLE public.writing_exercises DROP CONSTRAINT writing_exercises_kind_check;
ALTER TABLE public.writing_exercises ADD CONSTRAINT writing_exercises_kind_check
  CHECK (kind IN ('sentence','fill_blank','sentence_order','paragraph','email','opinion','essay'));
ALTER TABLE public.writing_exercises ADD CONSTRAINT writing_exercises_cefr_check CHECK (cefr_level IN ('A1','A2','B1','B2','C1'));
ALTER TABLE public.writing_exercises ADD CONSTRAINT writing_exercises_title_check CHECK (length(title) BETWEEN 1 AND 160);
ALTER TABLE public.writing_exercises ADD CONSTRAINT writing_exercises_word_counts_check CHECK (
  (min_words IS NULL OR min_words BETWEEN 1 AND 5000) AND
  (recommended_words IS NULL OR recommended_words BETWEEN 1 AND 5000) AND
  (min_words IS NULL OR recommended_words IS NULL OR min_words<=recommended_words));
ALTER TABLE public.writing_exercises ADD CONSTRAINT writing_exercises_minutes_check CHECK (estimated_minutes IS NULL OR estimated_minutes BETWEEN 1 AND 180);
ALTER TABLE public.writing_exercises ADD CONSTRAINT writing_exercises_difficulty_check CHECK (difficulty BETWEEN 1 AND 5);
CREATE INDEX writing_exercises_library_idx ON public.writing_exercises(cefr_level,topic_id,kind,difficulty,id)
  WHERE is_published AND archived_at IS NULL;

-- Preserve deterministic grading when an answer key exists; open exercises use self-review.
CREATE OR REPLACE FUNCTION public.englify_submit_writing(p_request_id uuid,p_exercise_id uuid,p_body text,p_grammar_check boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_original text:=btrim(p_body); v_old record; v_exercise record;
  v_normalized text; v_matched boolean; v_suggestions jsonb:='[]'::jsonb; v_rule_result text; v_submission_id uuid; v_words integer;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_request_id IS NULL OR p_exercise_id IS NULL OR length(v_original) NOT BETWEEN 1 AND 5000 THEN
    RAISE EXCEPTION 'Write 1-5000 characters before submitting' USING ERRCODE='22023'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('writing:'||v_uid::text||':'||p_request_id::text));
  SELECT id,exercise_id,body INTO v_old FROM public.writing_submissions WHERE user_id=v_uid AND request_id=p_request_id;
  IF FOUND THEN
    IF v_old.exercise_id<>p_exercise_id OR v_old.body<>v_original THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Submission ID belongs to another response'; END IF;
    RETURN public.englify_writing_submission(v_old.id);
  END IF;
  SELECT e.id,e.kind,e.prompt,e.min_words,k.accepted_answers INTO v_exercise FROM public.writing_exercises e
    LEFT JOIN public.writing_answer_keys k ON k.exercise_id=e.id
    WHERE e.id=p_exercise_id AND e.is_published AND e.archived_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Writing exercise not found' USING ERRCODE='P0002'; END IF;
  IF v_exercise.kind IN ('fill_blank','sentence_order') AND coalesce(jsonb_array_length(v_exercise.accepted_answers),0)=0 THEN
    RAISE EXCEPTION 'Writing answer key is unavailable' USING ERRCODE='P0001'; END IF;
  IF coalesce(jsonb_array_length(v_exercise.accepted_answers),0)>0 THEN
    v_normalized:=public.englify_normalize_answer(v_original);
    SELECT EXISTS(SELECT 1 FROM jsonb_array_elements_text(v_exercise.accepted_answers) a(value)
      WHERE public.englify_normalize_answer(a.value)=v_normalized) INTO v_matched;
    v_rule_result:=CASE WHEN v_matched THEN 'matched' ELSE 'needs_revision' END;
    v_suggestions:=jsonb_build_array(CASE WHEN v_matched THEN 'Your response matches an accepted example.'
      ELSE 'Compare the word order and spelling with the prompt, then try again.' END);
  ELSE
    v_rule_result:='self_review';
    SELECT count(*) INTO v_words FROM regexp_split_to_table(v_original,'\s+') word;
    IF v_exercise.min_words IS NOT NULL AND v_words<v_exercise.min_words THEN
      v_suggestions:=v_suggestions||jsonb_build_array('Add more detail to reach the suggested minimum for this task.'); END IF;
    IF substr(v_original,1,1)<>upper(substr(v_original,1,1)) THEN
      v_suggestions:=v_suggestions||jsonb_build_array('Start your writing with a capital letter.'); END IF;
    IF right(v_original,1) NOT IN ('.','!','?') THEN
      v_suggestions:=v_suggestions||jsonb_build_array('End your writing with punctuation.'); END IF;
  END IF;
  INSERT INTO public.writing_submissions(user_id,exercise_id,request_id,prompt,body)
    VALUES(v_uid,p_exercise_id,p_request_id,v_exercise.prompt,v_original) RETURNING id INTO v_submission_id;
  INSERT INTO public.writing_feedback(submission_id,rule_result,suggestions,grammar_status,grammar_matches)
    VALUES(v_submission_id,v_rule_result,v_suggestions,CASE WHEN p_grammar_check THEN 'unavailable' ELSE 'not_requested' END,'[]');
  RETURN public.englify_writing_submission(v_submission_id);
END $$;

ALTER TABLE public.user_preferences ADD COLUMN writing_cefr_level text NOT NULL DEFAULT 'A1';
ALTER TABLE public.user_preferences ADD CONSTRAINT user_preferences_writing_cefr_check CHECK (writing_cefr_level IN ('A1','A2','B1','B2','C1'));

CREATE FUNCTION public.englify_set_writing_level(p_level text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_level NOT IN ('A1','A2','B1','B2','C1') THEN RAISE EXCEPTION 'Invalid writing level' USING ERRCODE='22023'; END IF;
  INSERT INTO public.user_preferences(user_id,writing_cefr_level) VALUES(v_uid,p_level)
  ON CONFLICT(user_id) DO UPDATE SET writing_cefr_level=excluded.writing_cefr_level,updated_at=now();
  RETURN p_level;
END $$;
REVOKE ALL ON FUNCTION public.englify_set_writing_level(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_set_writing_level(text) TO authenticated;

CREATE FUNCTION public.englify_writing_library(p_query text DEFAULT '',p_level text DEFAULT NULL,p_topic_id uuid DEFAULT NULL,
  p_kind text DEFAULT NULL,p_page integer DEFAULT 1,p_page_size integer DEFAULT 20) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_query text:=btrim(coalesce(p_query,'')); v_items jsonb; v_total integer;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF length(v_query)>80 OR p_page<1 OR p_page_size NOT BETWEEN 1 AND 50
    OR (p_level IS NOT NULL AND p_level NOT IN ('A1','A2','B1','B2','C1'))
    OR (p_kind IS NOT NULL AND p_kind NOT IN ('sentence','fill_blank','sentence_order','paragraph','email','opinion','essay')) THEN
    RAISE EXCEPTION 'Invalid writing library filter' USING ERRCODE='22023';
  END IF;
  SELECT count(*) INTO v_total FROM public.writing_exercises e
    WHERE e.is_published AND e.archived_at IS NULL AND (p_level IS NULL OR e.cefr_level=p_level)
      AND (p_topic_id IS NULL OR e.topic_id=p_topic_id) AND (p_kind IS NULL OR e.kind=p_kind)
      AND (v_query='' OR e.title ILIKE '%'||v_query||'%' OR e.prompt ILIKE '%'||v_query||'%' OR coalesce(e.instructions,'') ILIKE '%'||v_query||'%');
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.difficulty,x.title,x.id),'[]'::jsonb) INTO v_items FROM (
    SELECT e.id,e.topic_id,e.cefr_level,e.kind,e.title,e.prompt,e.instructions,e.hint,e.tokens,e.min_words,
      e.recommended_words,e.estimated_minutes,e.difficulty,t.title AS topic_title
    FROM public.writing_exercises e LEFT JOIN public.writing_topics t ON t.id=e.topic_id
    WHERE e.is_published AND e.archived_at IS NULL AND (p_level IS NULL OR e.cefr_level=p_level)
      AND (p_topic_id IS NULL OR e.topic_id=p_topic_id) AND (p_kind IS NULL OR e.kind=p_kind)
      AND (v_query='' OR e.title ILIKE '%'||v_query||'%' OR e.prompt ILIKE '%'||v_query||'%' OR coalesce(e.instructions,'') ILIKE '%'||v_query||'%')
    ORDER BY e.difficulty,e.title,e.id OFFSET (p_page-1)*p_page_size LIMIT p_page_size) x;
  RETURN jsonb_build_object('items',v_items,'total',v_total,'page',p_page,'page_size',p_page_size);
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_library(text,text,uuid,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_library(text,text,uuid,text,integer,integer) TO authenticated;

CREATE FUNCTION public.englify_writing_topics(p_level text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_result jsonb; BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_level IS NOT NULL AND p_level NOT IN ('A1','A2','B1','B2','C1') THEN RAISE EXCEPTION 'Invalid writing level' USING ERRCODE='22023'; END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.sort_order,x.id),'[]'::jsonb) INTO v_result FROM (
    SELECT t.id,t.slug,t.title,t.description,t.icon,t.sort_order,count(e.id)::integer AS exercise_count
    FROM public.writing_topics t LEFT JOIN public.writing_exercises e ON e.topic_id=t.id AND e.is_published AND e.archived_at IS NULL
      AND (p_level IS NULL OR e.cefr_level=p_level)
    WHERE t.is_published AND t.archived_at IS NULL
    GROUP BY t.id ORDER BY t.sort_order,t.id) x
  ; RETURN v_result;
END
$$;
REVOKE ALL ON FUNCTION public.englify_writing_topics(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_topics(text) TO authenticated;

-- Include the new topic table in the existing admin audit trail.
CREATE TRIGGER admin_content_audit AFTER INSERT OR UPDATE OR DELETE ON public.writing_topics
  FOR EACH ROW EXECUTE FUNCTION public.englify_admin_audit_content();
