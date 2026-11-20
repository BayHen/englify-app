-- Return learner-facing answer text after grading; never leak option UUIDs in review UI.
CREATE OR REPLACE FUNCTION public.englify_submit_lesson(p_lesson_id uuid,p_request_id uuid,p_answers jsonb,p_content_version text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb; attempt uuid; revision uuid; review jsonb;
BEGIN
 result:=public.englify_submit_lesson_v2(p_lesson_id,p_request_id,p_answers,p_content_version); attempt:=(result->>'attempt_id')::uuid;
 SELECT id INTO revision FROM public.journey_lesson_revisions WHERE lesson_id=p_lesson_id AND status='published';
 UPDATE public.lesson_attempts SET revision_id=revision WHERE id=attempt AND user_id=auth.uid() AND revision_id IS NULL;
 SELECT coalesce(jsonb_agg(jsonb_build_object('question_id',a.question_id,'is_correct',a.is_correct,
   'learner_answer',CASE WHEN q.kind='multiple_choice' THEN to_jsonb(selected.answer_text) ELSE a.answer END,
   'correct_answer',CASE WHEN q.kind='multiple_choice' THEN to_jsonb(correct.answer_text) ELSE k.answer END,
   'explanation_en',coalesce(q.explanation_en,q.explanation),'explanation_vi',q.explanation_vi) ORDER BY q.position),'[]'::jsonb) INTO review
 FROM public.lesson_answer_attempts a JOIN public.lesson_attempts la ON la.id=a.attempt_id
 JOIN public.quiz_questions q ON q.id=a.question_id LEFT JOIN public.quiz_answer_keys k ON k.question_id=q.id
 LEFT JOIN public.quiz_options selected ON selected.question_id=q.id AND selected.id::text=a.answer#>>'{}'
 LEFT JOIN public.quiz_options correct ON correct.question_id=q.id AND correct.is_correct
 WHERE a.attempt_id=attempt AND la.user_id=auth.uid();
 RETURN result||jsonb_build_object('revision_id',revision,'review',review);
END $$;
REVOKE ALL ON FUNCTION public.englify_submit_lesson(uuid,uuid,jsonb,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_submit_lesson(uuid,uuid,jsonb,text) TO authenticated;

