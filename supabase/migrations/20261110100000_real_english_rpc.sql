GRANT INSERT, DELETE ON public.saved_expressions TO authenticated;
CREATE POLICY saved_expressions_own_insert ON public.saved_expressions
  FOR INSERT TO authenticated WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY saved_expressions_own_delete ON public.saved_expressions
  FOR DELETE TO authenticated USING ((select auth.uid()) = user_id);

-- Quiz answer_id remains server-only; clients receive options without the key.
CREATE FUNCTION public.englify_context_quiz(p_expression_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  SELECT jsonb_build_object('id', q.id, 'expression_id', q.expression_id,
                            'prompt', q.prompt, 'options', q.options)
  INTO result
  FROM public.real_english_quiz_questions q
  JOIN public.real_english_expressions e ON e.id = q.expression_id
  WHERE q.expression_id = p_expression_id AND e.is_published AND e.archived_at IS NULL;
  IF result IS NULL THEN
    RAISE EXCEPTION 'Context quiz not found' USING ERRCODE = 'P0002';
  END IF;
  RETURN result;
END $$;
REVOKE ALL ON FUNCTION public.englify_context_quiz(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_context_quiz(uuid) TO authenticated;

CREATE FUNCTION public.englify_submit_context_quiz(
  p_expression_id uuid,
  p_request_id uuid,
  p_selected_option text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_user_id uuid := auth.uid();
  old_attempt record;
  quiz record;
  attempt record;
  correct boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_request_id IS NULL OR p_selected_option IS NULL OR length(p_selected_option) NOT BETWEEN 1 AND 80 THEN
    RAISE EXCEPTION 'Invalid quiz submission' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('real-english:' || v_user_id::text || ':' || p_request_id::text));
  SELECT a.id, a.question_id, a.selected_option, a.is_correct, a.created_at,
         q.expression_id, q.answer_id, q.explanation
  INTO old_attempt
  FROM public.real_english_quiz_attempts a
  JOIN public.real_english_quiz_questions q ON q.id = a.question_id
  WHERE a.user_id = v_user_id AND a.request_id = p_request_id;
  IF FOUND THEN
    IF old_attempt.expression_id <> p_expression_id OR old_attempt.selected_option <> p_selected_option THEN
      RAISE EXCEPTION 'Submission ID belongs to another quiz answer' USING ERRCODE = '23505';
    END IF;
    RETURN jsonb_build_object(
      'attempt_id', old_attempt.id, 'question_id', old_attempt.question_id,
      'is_correct', old_attempt.is_correct, 'correct_option', old_attempt.answer_id,
      'explanation', old_attempt.explanation, 'created_at', old_attempt.created_at
    );
  END IF;
  SELECT q.id, q.options, q.answer_id, q.explanation INTO quiz
  FROM public.real_english_quiz_questions q
  JOIN public.real_english_expressions e ON e.id = q.expression_id
  WHERE q.expression_id = p_expression_id AND e.is_published AND e.archived_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Context quiz not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.jsonb_array_elements(quiz.options) AS option_row(item)
    WHERE option_row.item->>'id' = p_selected_option
  ) THEN
    RAISE EXCEPTION 'Choose an option from this quiz' USING ERRCODE = '22023';
  END IF;
  correct := p_selected_option = quiz.answer_id;
  INSERT INTO public.real_english_quiz_attempts
    (user_id, question_id, request_id, selected_option, is_correct)
  VALUES (v_user_id, quiz.id, p_request_id, p_selected_option, correct)
  RETURNING id, created_at INTO attempt;
  RETURN jsonb_build_object(
    'attempt_id', attempt.id, 'question_id', quiz.id, 'is_correct', correct,
    'correct_option', quiz.answer_id, 'explanation', quiz.explanation,
    'created_at', attempt.created_at
  );
END $$;
REVOKE ALL ON FUNCTION public.englify_submit_context_quiz(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_submit_context_quiz(uuid, uuid, text) TO authenticated;

