-- Administrative membership is database-owned; ordinary users cannot grant it.
CREATE FUNCTION public.englify_is_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS(
    SELECT 1 FROM public.admin_members WHERE user_id=auth.uid())
$$;
REVOKE ALL ON FUNCTION public.englify_is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_is_admin() TO authenticated;

-- Baseline grants on these private tables were broader than the RLS policy.
-- Keep answer-bearing Real English quiz rows and admin membership inaccessible
-- even if a future policy is added inadvertently.
REVOKE ALL ON public.admin_members FROM anon,authenticated;
REVOKE ALL ON public.real_english_quiz_questions FROM anon,authenticated;

CREATE POLICY admin_audit_read ON public.admin_audit_logs FOR SELECT TO authenticated
  USING (public.englify_is_admin());
REVOKE ALL ON public.admin_audit_logs FROM anon,authenticated;
GRANT SELECT ON public.admin_audit_logs TO authenticated;

-- Editorial tables already have published-content read policies. The new policy
-- also allows admins to see drafts and edit content, while preserving learner RLS.
DO $$
DECLARE v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'dictionary_entries','courses','learning_units','lessons','lesson_items',
    'quiz_questions','quiz_options','quiz_answer_keys','real_english_expressions',
    'badges','badge_rules','writing_exercises','writing_answer_keys'
  ] LOOP
    EXECUTE pg_catalog.format('CREATE POLICY admin_editor ON public.%I FOR ALL TO authenticated USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin())',v_table);
    EXECUTE pg_catalog.format('GRANT SELECT,INSERT,UPDATE ON public.%I TO authenticated',v_table);
  END LOOP;
END $$;

-- This trigger applies only to user JWT writes through PostgREST. The existing
-- FastAPI service uses a database connection without auth.uid(), so it keeps
-- its current audit path until the Admin UI switches over.
CREATE FUNCTION public.englify_admin_audit_content()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_actor uuid := auth.uid(); v_action text; v_resource text; v_id uuid;
BEGIN
  IF v_actor IS NULL THEN RETURN coalesce(NEW,OLD); END IF;
  IF NOT EXISTS(SELECT 1 FROM public.admin_members WHERE user_id=v_actor) THEN
    RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';
  END IF;
  v_resource := CASE TG_TABLE_NAME
    WHEN 'dictionary_entries' THEN 'vocabulary' WHEN 'learning_units' THEN 'units'
    WHEN 'lesson_items' THEN 'lesson-items' WHEN 'quiz_questions' THEN 'quiz-questions'
    WHEN 'quiz_options' THEN 'quiz-options' WHEN 'quiz_answer_keys' THEN 'quiz-questions'
    WHEN 'real_english_expressions' THEN 'real-english' WHEN 'badge_rules' THEN 'badges'
    ELSE TG_TABLE_NAME END;
  v_id := CASE WHEN TG_TABLE_NAME='quiz_answer_keys' THEN coalesce(to_jsonb(NEW)->>'question_id',to_jsonb(OLD)->>'question_id')
    WHEN TG_TABLE_NAME='badge_rules' THEN coalesce(to_jsonb(NEW)->>'badge_id',to_jsonb(OLD)->>'badge_id')
    ELSE coalesce(to_jsonb(NEW)->>'id',to_jsonb(OLD)->>'id') END::uuid;
  IF TG_OP='INSERT' THEN v_action := 'create';
  ELSIF TG_OP='DELETE' THEN v_action := 'delete';
  ELSIF (to_jsonb(OLD)->>'archived_at') IS NULL AND (to_jsonb(NEW)->>'archived_at') IS NOT NULL THEN v_action := 'delete';
  ELSIF (to_jsonb(OLD)->>'is_published') IS DISTINCT FROM (to_jsonb(NEW)->>'is_published') THEN
    v_action := CASE WHEN (to_jsonb(NEW)->>'is_published')::boolean THEN 'publish' ELSE 'unpublish' END;
  ELSE v_action := 'update'; END IF;
  INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data)
    VALUES(v_actor,v_action,v_resource,v_id,
      CASE WHEN TG_OP='INSERT' THEN NULL ELSE to_jsonb(OLD) END,
      CASE WHEN TG_OP='DELETE' THEN NULL ELSE to_jsonb(NEW) END);
  RETURN coalesce(NEW,OLD);
END $$;
REVOKE ALL ON FUNCTION public.englify_admin_audit_content() FROM PUBLIC, anon, authenticated;

DO $$
DECLARE v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'dictionary_entries','courses','learning_units','lessons','lesson_items',
    'quiz_questions','quiz_options','quiz_answer_keys','real_english_expressions',
    'badges','badge_rules','writing_exercises','writing_answer_keys'
  ] LOOP
    EXECUTE pg_catalog.format('CREATE TRIGGER admin_content_audit AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.englify_admin_audit_content()',v_table);
  END LOOP;
END $$;

-- Reject public quiz content without a complete private key and valid choices.
CREATE FUNCTION public.englify_admin_validate_question()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_count int; v_correct int; v_key jsonb;
BEGIN
  IF NEW.is_published AND (TG_OP='INSERT' OR NOT OLD.is_published) THEN
    IF NEW.kind='multiple_choice' THEN
      SELECT count(*),count(*) FILTER (WHERE is_correct) INTO v_count,v_correct
        FROM public.quiz_options WHERE question_id=NEW.id;
      IF v_count<2 OR v_correct<>1 THEN RAISE EXCEPTION 'Multiple choice needs two options and one correct answer' USING ERRCODE='22023'; END IF;
    ELSE
      SELECT answer INTO v_key FROM public.quiz_answer_keys WHERE question_id=NEW.id;
      IF v_key IS NULL OR (NEW.kind='matching' AND pg_catalog.jsonb_typeof(v_key)<>'object')
        OR (NEW.kind<>'matching' AND (pg_catalog.jsonb_typeof(v_key)<>'array' OR pg_catalog.jsonb_array_length(v_key)=0)) THEN
        RAISE EXCEPTION 'Quiz answer key is incomplete' USING ERRCODE='22023';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_admin_validate_question() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER admin_quiz_publish_guard BEFORE INSERT OR UPDATE OF is_published ON public.quiz_questions
  FOR EACH ROW EXECUTE FUNCTION public.englify_admin_validate_question();

CREATE FUNCTION public.englify_admin_protect_attempted_quiz()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_question_id uuid; v_lesson_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RETURN coalesce(NEW,OLD); END IF;
  IF TG_TABLE_NAME='quiz_questions' THEN
    IF TG_OP='UPDATE' AND OLD.kind=NEW.kind AND OLD.prompt=NEW.prompt AND OLD.payload=NEW.payload
      AND OLD.explanation=NEW.explanation THEN RETURN NEW; END IF;
    v_lesson_id := coalesce(NEW.lesson_id,OLD.lesson_id);
  ELSE
    v_question_id := coalesce(to_jsonb(NEW)->>'question_id',to_jsonb(OLD)->>'question_id')::uuid;
    IF EXISTS(SELECT 1 FROM public.quiz_questions WHERE id=v_question_id AND is_published) THEN
      RAISE SQLSTATE 'PT409' USING MESSAGE='Move the question to draft before editing answers';
    END IF;
    SELECT lesson_id INTO v_lesson_id FROM public.quiz_questions WHERE id=v_question_id;
  END IF;
  IF EXISTS(SELECT 1 FROM public.lesson_attempts WHERE lesson_id=v_lesson_id) THEN
    RAISE SQLSTATE 'PT409' USING MESSAGE='Quiz content with attempts cannot be edited';
  END IF;
  RETURN coalesce(NEW,OLD);
END $$;
REVOKE ALL ON FUNCTION public.englify_admin_protect_attempted_quiz() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER admin_question_history_guard BEFORE INSERT OR UPDATE OR DELETE ON public.quiz_questions
  FOR EACH ROW EXECUTE FUNCTION public.englify_admin_protect_attempted_quiz();
CREATE TRIGGER admin_option_history_guard BEFORE INSERT OR UPDATE OR DELETE ON public.quiz_options
  FOR EACH ROW EXECUTE FUNCTION public.englify_admin_protect_attempted_quiz();
CREATE TRIGGER admin_answer_history_guard BEFORE INSERT OR UPDATE OR DELETE ON public.quiz_answer_keys
  FOR EACH ROW EXECUTE FUNCTION public.englify_admin_protect_attempted_quiz();

CREATE FUNCTION public.englify_admin_validate_lesson_parent()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NEW.unit_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.learning_units WHERE id=NEW.unit_id AND course_id=NEW.course_id) THEN
    RAISE EXCEPTION 'Lesson unit must belong to its course' USING ERRCODE='22023';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_admin_validate_lesson_parent() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER admin_lesson_parent_guard BEFORE INSERT OR UPDATE OF unit_id,course_id ON public.lessons
  FOR EACH ROW EXECUTE FUNCTION public.englify_admin_validate_lesson_parent();

CREATE FUNCTION public.englify_admin_metrics(p_view text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_result jsonb := '{}'::jsonb; v_resource text; v_table text; v_count int;
BEGIN
  IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
  IF p_view='analytics' THEN
    RETURN jsonb_build_object(
      'learners',(SELECT count(*) FROM public.profiles),
      'lesson_attempts',(SELECT count(*) FROM public.lesson_attempts),
      'saved_words',(SELECT count(*) FROM public.saved_vocabulary),
      'writing_submissions',(SELECT count(*) FROM public.writing_submissions),
      'completed_lessons',(SELECT count(*) FROM public.learning_progress WHERE status IN ('completed','mastered')));
  END IF;
  IF p_view NOT IN ('overview','publishing') THEN RAISE EXCEPTION 'Unknown admin view' USING ERRCODE='22023'; END IF;
  FOR v_resource,v_table IN SELECT * FROM (VALUES
    ('vocabulary','dictionary_entries'),('courses','courses'),('units','learning_units'),
    ('lessons','lessons'),('lesson-items','lesson_items'),('quiz-questions','quiz_questions'),
    ('real-english','real_english_expressions'),('badges','badges')) AS m(resource,table_name)
  LOOP
    EXECUTE pg_catalog.format('SELECT count(*) FROM public.%I WHERE is_published=%L AND archived_at IS NULL',
      v_table,p_view='overview') INTO v_count;
    v_result := v_result||jsonb_build_object(v_resource,v_count);
  END LOOP;
  RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION public.englify_admin_metrics(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_admin_metrics(text) TO authenticated;
