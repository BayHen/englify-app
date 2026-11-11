-- Public lesson content, learner-specific locks, and answer-free offline packages.
CREATE FUNCTION public.englify_lesson_state(p_lesson_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  WITH ordered AS (
    SELECT l.id, p.status, row_number() OVER (PARTITION BY c.id ORDER BY u.position,l.position) AS ordinal,
      lag(coalesce(p.status IN ('completed','mastered'),false)) OVER (PARTITION BY c.id ORDER BY u.position,l.position) AS previous_done
    FROM public.courses c
    JOIN public.learning_units u ON u.course_id=c.id AND u.is_published AND u.archived_at IS NULL
    JOIN public.lessons l ON l.unit_id=u.id AND l.is_published AND l.archived_at IS NULL
    LEFT JOIN public.learning_progress p ON p.lesson_id=l.id AND p.user_id=auth.uid()
    WHERE c.is_published AND c.archived_at IS NULL
  )
  SELECT CASE WHEN status IN ('in_progress','completed','mastered') THEN status
    WHEN ordinal=1 OR previous_done THEN 'available' ELSE 'locked' END
  FROM ordered WHERE id=p_lesson_id
$$;
REVOKE ALL ON FUNCTION public.englify_lesson_state(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_lesson_state(uuid) TO authenticated;

CREATE FUNCTION public.englify_journey()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',c.id,'title',c.title,'units',
    coalesce((SELECT jsonb_agg(jsonb_build_object('id',u.id,'title',u.title,'position',u.position,'lessons',
      coalesce((SELECT jsonb_agg(jsonb_build_object('id',l.id,'title',l.title,'objective',l.objective,
        'position',l.position,'state',public.englify_lesson_state(l.id)) ORDER BY l.position)
        FROM public.lessons l WHERE l.unit_id=u.id AND l.is_published AND l.archived_at IS NULL),'[]'::jsonb)) ORDER BY u.position)
      FROM public.learning_units u WHERE u.course_id=c.id AND u.is_published AND u.archived_at IS NULL),'[]'::jsonb))
    ORDER BY c.level,c.id),'[]'::jsonb) INTO v_result
  FROM public.courses c WHERE c.is_published AND c.archived_at IS NULL;
  RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION public.englify_journey() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_journey() TO authenticated;

CREATE FUNCTION public.englify_lesson_detail(p_lesson_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_state text; v_lesson record; v_items jsonb; v_questions jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  v_state := public.englify_lesson_state(p_lesson_id);
  IF v_state IS NULL THEN RAISE EXCEPTION 'Published lesson not found' USING ERRCODE='P0002'; END IF;
  IF v_state='locked' THEN RAISE EXCEPTION 'Complete the previous lesson first' USING ERRCODE='42501'; END IF;
  SELECT id,title,objective INTO v_lesson FROM public.lessons WHERE id=p_lesson_id;
  SELECT coalesce(jsonb_agg(jsonb_build_object('kind',i.kind,'body',i.body) ORDER BY i.position),'[]'::jsonb)
    INTO v_items FROM public.lesson_items i
    WHERE i.lesson_id=p_lesson_id AND i.is_published AND i.archived_at IS NULL;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',q.id,'kind',q.kind,'prompt',q.prompt,'payload',q.payload,
    'options',CASE WHEN q.kind='multiple_choice' THEN
      coalesce((SELECT jsonb_agg(jsonb_build_object('id',o.id,'text',o.answer_text) ORDER BY o.position)
        FROM public.quiz_options o WHERE o.question_id=q.id),'[]'::jsonb)
      ELSE '[]'::jsonb END) ORDER BY q.position),'[]'::jsonb)
    INTO v_questions FROM public.quiz_questions q
    WHERE q.lesson_id=p_lesson_id AND q.is_published AND q.archived_at IS NULL;
  RETURN jsonb_build_object('id',v_lesson.id,'title',v_lesson.title,'objective',v_lesson.objective,
    'state',v_state,'items',v_items,'questions',v_questions);
END $$;
REVOKE ALL ON FUNCTION public.englify_lesson_detail(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_lesson_detail(uuid) TO authenticated;

-- Deliberately excludes quiz_answer_keys and quiz_options.is_correct.
CREATE FUNCTION public.englify_lesson_content_version(p_lesson_id uuid)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_snapshot jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF public.englify_lesson_state(p_lesson_id) IS NULL THEN
    RAISE EXCEPTION 'Published lesson not found' USING ERRCODE='P0002';
  END IF;
  SELECT jsonb_build_object('lesson',jsonb_build_object('id',l.id,'title',l.title,'objective',l.objective,
    'content',l.content,'updated_at',l.updated_at),
    'items',coalesce((SELECT jsonb_agg(jsonb_build_object('id',i.id,'position',i.position,'kind',i.kind,
      'body',i.body,'is_published',i.is_published) ORDER BY i.position,i.id)
      FROM public.lesson_items i WHERE i.lesson_id=l.id AND i.is_published AND i.archived_at IS NULL),'[]'::jsonb),
    'questions',coalesce((SELECT jsonb_agg(jsonb_build_object('id',q.id,'position',q.position,'kind',q.kind,
      'prompt',q.prompt,'explanation',q.explanation,'payload',q.payload,'updated_at',q.updated_at)
      ORDER BY q.position,q.id) FROM public.quiz_questions q
      WHERE q.lesson_id=l.id AND q.is_published AND q.archived_at IS NULL),'[]'::jsonb),
    'options',coalesce((SELECT jsonb_agg(jsonb_build_object('id',o.id,'question_id',o.question_id,
      'position',o.position,'answer_text',o.answer_text) ORDER BY o.question_id,o.position,o.id)
      FROM public.quiz_options o JOIN public.quiz_questions q ON q.id=o.question_id
      WHERE q.lesson_id=l.id AND q.is_published AND q.archived_at IS NULL),'[]'::jsonb))
  INTO v_snapshot FROM public.lessons l WHERE l.id=p_lesson_id;
  RETURN pg_catalog.encode(extensions.digest(v_snapshot::text,'sha256'),'hex');
END $$;
REVOKE ALL ON FUNCTION public.englify_lesson_content_version(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_lesson_content_version(uuid) TO authenticated;

CREATE FUNCTION public.englify_journey_summary()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_step int; v_total int; v_level int; v_journey jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT level_xp_step INTO v_step FROM public.gamification_config WHERE id=1;
  SELECT total_xp,level INTO v_total,v_level FROM public.user_levels WHERE user_id=auth.uid();
  IF NOT FOUND THEN
    SELECT greatest(0,coalesce(sum(amount),0)) INTO v_total FROM public.xp_events WHERE user_id=auth.uid();
    v_level := v_total/v_step+1;
  END IF;
  v_journey := public.englify_journey();
  RETURN jsonb_build_object('xp_total',v_total,'level',v_level,'xp_into_level',v_total%v_step,
    'xp_for_next_level',v_step,'completed_lessons',
      (SELECT count(*) FROM pg_catalog.jsonb_array_elements(v_journey) c,
        pg_catalog.jsonb_array_elements(c.value->'units') u,
        pg_catalog.jsonb_array_elements(u.value->'lessons') l
        WHERE l.value->>'state' IN ('completed','mastered')),
    'total_lessons',(SELECT count(*) FROM pg_catalog.jsonb_array_elements(v_journey) c,
      pg_catalog.jsonb_array_elements(c.value->'units') u,
      pg_catalog.jsonb_array_elements(u.value->'lessons') l));
END $$;
REVOKE ALL ON FUNCTION public.englify_journey_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_journey_summary() TO authenticated;