-- Plan writes are serialized per user and never award XP or unlock lessons.
CREATE FUNCTION public.englify_plan_replace(p_tasks jsonb, p_force boolean DEFAULT false)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_pref record;
  v_existing uuid;
  v_plan uuid;
  v_task jsonb;
  v_day date;
  v_kind text;
  v_lesson uuid;
  v_minutes int;
  v_position int := 0;
  v_today date := (transaction_timestamp() AT TIME ZONE 'UTC')::date;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('plan:' || v_uid::text));
  SELECT learning_goal, initial_proficiency, daily_goal_minutes INTO v_pref
    FROM public.user_preferences WHERE user_id = v_uid AND onboarding_completed_at IS NOT NULL;
  IF NOT FOUND OR v_pref.learning_goal IS NULL OR v_pref.initial_proficiency IS NULL THEN
    RAISE EXCEPTION 'Complete onboarding before generating a plan' USING ERRCODE = 'P0001';
  END IF;
  SELECT id INTO v_existing FROM public.learning_plans
    WHERE user_id = v_uid AND status = 'active' AND starts_on IS NOT NULL FOR UPDATE;
  IF v_existing IS NOT NULL AND p_force IS NOT TRUE THEN RETURN v_existing; END IF;
  IF p_tasks IS NULL OR pg_catalog.jsonb_typeof(p_tasks) <> 'array' OR pg_catalog.jsonb_array_length(p_tasks) NOT BETWEEN 7 AND 60 THEN
    RAISE EXCEPTION 'Invalid weekly plan' USING ERRCODE = '22023';
  END IF;
  FOR v_task IN SELECT value FROM pg_catalog.jsonb_array_elements(p_tasks) LOOP
    IF pg_catalog.jsonb_typeof(v_task) <> 'object' OR (v_task->>'day') !~ '^\d{4}-\d{2}-\d{2}$'
       OR (v_task->>'minutes') !~ '^[0-9]{1,3}$' THEN
      RAISE EXCEPTION 'Invalid plan task' USING ERRCODE = '22023';
    END IF;
    v_day := (v_task->>'day')::date;
    v_kind := v_task->>'kind';
    v_minutes := (v_task->>'minutes')::int;
    IF v_day < v_today OR v_day > v_today + 6 OR v_kind NOT IN ('lesson','vocabulary','review','speaking','writing')
       OR v_minutes NOT BETWEEN 1 AND v_pref.daily_goal_minutes OR length(trim(v_task->>'title')) NOT BETWEEN 1 AND 120 THEN
      RAISE EXCEPTION 'Invalid plan task' USING ERRCODE = '22023';
    END IF;
    IF v_kind = 'lesson' THEN
      v_lesson := (v_task->>'lesson_id')::uuid;
      IF NOT EXISTS (
        SELECT 1 FROM public.lessons l JOIN public.learning_units u ON u.id=l.unit_id
        JOIN public.courses c ON c.id=u.course_id
        WHERE l.id=v_lesson AND l.is_published AND l.archived_at IS NULL
          AND u.is_published AND u.archived_at IS NULL AND c.is_published AND c.archived_at IS NULL
          AND NOT EXISTS (SELECT 1 FROM public.learning_progress p WHERE p.user_id=v_uid AND p.lesson_id=l.id
            AND p.status IN ('completed','mastered'))
      ) THEN RAISE EXCEPTION 'Plan lesson is unavailable' USING ERRCODE = '22023'; END IF;
    ELSIF v_task->>'lesson_id' IS NOT NULL THEN
      RAISE EXCEPTION 'Only lesson tasks may reference lessons' USING ERRCODE = '22023';
    END IF;
    IF v_task->>'target_count' IS NOT NULL AND ((v_task->>'target_count') !~ '^[0-9]{1,3}$'
       OR (v_task->>'target_count')::int NOT BETWEEN 1 AND 100) THEN
      RAISE EXCEPTION 'Invalid plan target' USING ERRCODE = '22023';
    END IF;
  END LOOP;
  IF (SELECT count(DISTINCT value->>'day') FROM pg_catalog.jsonb_array_elements(p_tasks)) <> 7 OR EXISTS (
    SELECT 1 FROM (SELECT value->>'day' AS day, sum((value->>'minutes')::int) AS minutes
      FROM pg_catalog.jsonb_array_elements(p_tasks) GROUP BY value->>'day') grouped
    WHERE grouped.minutes > v_pref.daily_goal_minutes
  ) THEN RAISE EXCEPTION 'Plan exceeds the daily schedule' USING ERRCODE = '22023'; END IF;
  UPDATE public.learning_plans SET status='paused', updated_at=now()
    WHERE user_id=v_uid AND status='active';
  INSERT INTO public.learning_plans(user_id,title,goal,status,starts_on,algorithm_version)
    VALUES (v_uid,'Weekly learning plan',v_pref.learning_goal,'active',v_today,1)
    RETURNING id INTO v_plan;
  FOR v_task IN SELECT value FROM pg_catalog.jsonb_array_elements(p_tasks) LOOP
    v_position := v_position + 1;
    INSERT INTO public.learning_plan_tasks(plan_id,user_id,lesson_id,kind,title,scheduled_on,original_date,
      duration_minutes,target_count,topic,position)
    VALUES (v_plan,v_uid,NULLIF(v_task->>'lesson_id','')::uuid,v_task->>'kind',v_task->>'title',
      (v_task->>'day')::date,(v_task->>'day')::date,(v_task->>'minutes')::int,
      NULLIF(v_task->>'target_count','')::int,v_task->>'topic',v_position);
  END LOOP;
  RETURN v_plan;
END $$;
REVOKE ALL ON FUNCTION public.englify_plan_replace(jsonb,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_plan_replace(jsonb,boolean) TO authenticated;

CREATE FUNCTION public.englify_plan_complete_task(p_task_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid uuid := auth.uid(); v_kind text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('plan:' || v_uid::text));
  SELECT t.kind INTO v_kind FROM public.learning_plan_tasks t JOIN public.learning_plans p ON p.id=t.plan_id
    WHERE t.id=p_task_id AND t.user_id=v_uid AND p.user_id=v_uid AND p.status='active' FOR UPDATE OF t;
  IF NOT FOUND THEN RAISE EXCEPTION 'Plan task not found' USING ERRCODE='P0002'; END IF;
  IF v_kind='lesson' THEN RAISE EXCEPTION 'Complete the lesson quiz instead' USING ERRCODE='22023'; END IF;
  UPDATE public.learning_plan_tasks SET status='completed',completed_at=coalesce(completed_at,now()),updated_at=now()
    WHERE id=p_task_id AND user_id=v_uid;
  RETURN true;
END $$;
REVOKE ALL ON FUNCTION public.englify_plan_complete_task(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_plan_complete_task(uuid) TO authenticated;

CREATE FUNCTION public.englify_plan_reschedule()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid(); v_plan uuid; v_limit int; v_today date := (transaction_timestamp() AT TIME ZONE 'UTC')::date;
  v_task record; v_day date; v_used int; v_count int := 0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('plan:' || v_uid::text));
  SELECT id INTO v_plan FROM public.learning_plans WHERE user_id=v_uid AND status='active' FOR UPDATE;
  IF v_plan IS NULL THEN RAISE EXCEPTION 'Generate a plan first' USING ERRCODE='P0002'; END IF;
  SELECT daily_goal_minutes INTO v_limit FROM public.user_preferences WHERE user_id=v_uid;
  FOR v_task IN SELECT t.id,t.duration_minutes,t.scheduled_on FROM public.learning_plan_tasks t
    LEFT JOIN public.learning_progress p ON p.lesson_id=t.lesson_id AND p.user_id=v_uid
    WHERE t.plan_id=v_plan AND t.user_id=v_uid AND t.status='pending' AND t.scheduled_on<v_today
      AND (p.status IS NULL OR p.status NOT IN ('completed','mastered'))
    ORDER BY t.scheduled_on,t.position FOR UPDATE OF t LOOP
    IF v_task.duration_minutes > v_limit THEN
      RAISE EXCEPTION 'Plan task exceeds daily goal; regenerate plan' USING ERRCODE='22023';
    END IF;
    v_day := v_today;
    LOOP
      SELECT coalesce(sum(t.duration_minutes),0) INTO v_used FROM public.learning_plan_tasks t
        LEFT JOIN public.learning_progress p ON p.lesson_id=t.lesson_id AND p.user_id=v_uid
        WHERE t.plan_id=v_plan AND t.user_id=v_uid AND t.status='pending' AND t.scheduled_on=v_day
          AND (p.status IS NULL OR p.status NOT IN ('completed','mastered'));
      EXIT WHEN v_used + v_task.duration_minutes <= v_limit;
      v_day := v_day + 1;
    END LOOP;
    UPDATE public.learning_plan_tasks SET scheduled_on=v_day,updated_at=now() WHERE id=v_task.id AND user_id=v_uid;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END $$;
REVOKE ALL ON FUNCTION public.englify_plan_reschedule() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_plan_reschedule() TO authenticated;
