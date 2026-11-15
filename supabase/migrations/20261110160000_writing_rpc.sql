-- Structured writing is checked and stored in a transaction. Grammar is optional.
CREATE FUNCTION public.englify_writing_submission(p_submission_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_row record;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT s.id,s.exercise_id,s.prompt,s.body,s.created_at,f.rule_result,f.suggestions,
    f.grammar_status,f.grammar_matches INTO v_row
    FROM public.writing_submissions s LEFT JOIN public.writing_feedback f ON f.submission_id=s.id
    WHERE s.id=p_submission_id AND s.user_id=auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Writing submission not found' USING ERRCODE='P0002'; END IF;
  RETURN jsonb_build_object('id',v_row.id,'exercise_id',v_row.exercise_id,'prompt',v_row.prompt,
    'body',v_row.body,'created_at',v_row.created_at,'feedback',CASE WHEN v_row.rule_result IS NULL THEN NULL
    ELSE jsonb_build_object('rule_result',v_row.rule_result,'suggestions',v_row.suggestions,
      'grammar_status',v_row.grammar_status,'grammar_matches',v_row.grammar_matches) END);
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_submission(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_submission(uuid) TO authenticated;

CREATE FUNCTION public.englify_writing_history(p_limit int DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Invalid history limit' USING ERRCODE='22023'; END IF;
  SELECT coalesce(jsonb_agg(public.englify_writing_submission(r.id) ORDER BY r.created_at DESC,r.id DESC),'[]'::jsonb)
    INTO v_result FROM (SELECT id,created_at FROM public.writing_submissions
      WHERE user_id=auth.uid() AND exercise_id IS NOT NULL ORDER BY created_at DESC,id DESC LIMIT p_limit) r;
  RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_history(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_history(int) TO authenticated;

CREATE FUNCTION public.englify_submit_writing(p_request_id uuid,p_exercise_id uuid,p_body text,p_grammar_check boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid(); v_original text := pg_catalog.btrim(p_body); v_old record; v_exercise record;
  v_normalized text; v_matched boolean; v_suggestions jsonb := '[]'::jsonb;
  v_rule_result text; v_submission_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_request_id IS NULL OR p_exercise_id IS NULL OR pg_catalog.length(v_original) NOT BETWEEN 1 AND 5000 THEN
    RAISE EXCEPTION 'Write 1–5000 characters before submitting' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('writing:'||v_uid::text||':'||p_request_id::text));
  SELECT id,exercise_id,body INTO v_old FROM public.writing_submissions
    WHERE user_id=v_uid AND request_id=p_request_id;
  IF FOUND THEN
    IF v_old.exercise_id<>p_exercise_id OR v_old.body<>v_original THEN
      RAISE SQLSTATE 'PT409' USING MESSAGE='Submission ID belongs to another response';
    END IF;
    RETURN public.englify_writing_submission(v_old.id);
  END IF;
  SELECT e.id,e.kind,e.prompt,k.accepted_answers INTO v_exercise
    FROM public.writing_exercises e LEFT JOIN public.writing_answer_keys k ON k.exercise_id=e.id
    WHERE e.id=p_exercise_id AND e.is_published;
  IF NOT FOUND THEN RAISE EXCEPTION 'Writing exercise not found' USING ERRCODE='P0002'; END IF;
  IF v_exercise.kind<>'paragraph' AND v_exercise.accepted_answers IS NULL THEN
    RAISE EXCEPTION 'Writing answer key is unavailable' USING ERRCODE='P0001';
  END IF;
  IF v_exercise.kind='paragraph' THEN
    v_rule_result := 'self_review';
    IF (SELECT count(*) FROM pg_catalog.regexp_split_to_table(v_original,'\s+') AS word)<20 THEN
      v_suggestions := v_suggestions||jsonb_build_array('Add more detail or an example to develop your paragraph.');
    END IF;
    IF pg_catalog.substr(v_original,1,1)<>pg_catalog.upper(pg_catalog.substr(v_original,1,1)) THEN
      v_suggestions := v_suggestions||jsonb_build_array('Start your paragraph with a capital letter.');
    END IF;
    IF pg_catalog.right(v_original,1) NOT IN ('.','!','?') THEN
      v_suggestions := v_suggestions||jsonb_build_array('End your paragraph with punctuation.');
    END IF;
  ELSE
    v_normalized := public.englify_normalize_answer(v_original);
    SELECT EXISTS(SELECT 1 FROM pg_catalog.jsonb_array_elements_text(v_exercise.accepted_answers) AS a(value)
      WHERE public.englify_normalize_answer(a.value)=v_normalized) INTO v_matched;
    IF v_matched THEN
      v_rule_result := 'matched';
      v_suggestions := jsonb_build_array('Your response matches an accepted example.');
    ELSE
      v_rule_result := 'needs_revision';
      v_suggestions := jsonb_build_array('Compare the word order and spelling with the prompt, then try again.');
      IF v_exercise.kind<>'fill_blank' AND pg_catalog.substr(v_original,1,1)<>pg_catalog.upper(pg_catalog.substr(v_original,1,1)) THEN
        v_suggestions := v_suggestions||jsonb_build_array('Start the sentence with a capital letter.');
      END IF;
    END IF;
  END IF;
  INSERT INTO public.writing_submissions(user_id,exercise_id,request_id,prompt,body)
    VALUES(v_uid,p_exercise_id,p_request_id,v_exercise.prompt,v_original) RETURNING id INTO v_submission_id;
  INSERT INTO public.writing_feedback(submission_id,rule_result,suggestions,grammar_status,grammar_matches)
    VALUES(v_submission_id,v_rule_result,v_suggestions,
      CASE WHEN p_grammar_check THEN 'unavailable' ELSE 'not_requested' END,'[]'::jsonb);
  RETURN public.englify_writing_submission(v_submission_id);
END $$;
REVOKE ALL ON FUNCTION public.englify_submit_writing(uuid,uuid,text,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_submit_writing(uuid,uuid,text,boolean) TO authenticated;

-- Only a trusted Edge Function holding the service role key can attach provider feedback.
CREATE FUNCTION public.englify_attach_grammar_feedback(p_submission_id uuid,p_matches jsonb)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF pg_catalog.jsonb_typeof(p_matches)<>'array' OR pg_catalog.jsonb_array_length(p_matches)>20 THEN
    RAISE EXCEPTION 'Invalid grammar feedback' USING ERRCODE='22023';
  END IF;
  UPDATE public.writing_feedback SET grammar_status='available',grammar_matches=p_matches
    WHERE submission_id=p_submission_id AND grammar_status='unavailable';
  RETURN FOUND;
END $$;
REVOKE ALL ON FUNCTION public.englify_attach_grammar_feedback(uuid,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.englify_attach_grammar_feedback(uuid,jsonb) TO service_role;
