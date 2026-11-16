-- Make dependent Admin writes atomic and retry-safe. This migration is
-- additive: existing content IDs, audit rows and learner history are retained.

CREATE TABLE public.admin_mutation_requests (
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  request_id uuid NOT NULL,
  resource text NOT NULL CHECK (resource IN ('quiz-questions', 'badges')),
  record_id uuid NOT NULL,
  response jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (actor_id, request_id)
);

ALTER TABLE public.admin_mutation_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_mutation_requests FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.admin_mutation_requests TO service_role;
CREATE INDEX admin_mutation_requests_created_idx
  ON public.admin_mutation_requests(created_at DESC);

-- Baseline writing grants were intentionally broad for early development.
-- Keep answer tables inaccessible to anonymous clients and remove destructive
-- table privileges from authenticated users. Admin reads/writes still require
-- the existing admin_editor RLS policy; learner queries return no rows.
REVOKE ALL ON public.quiz_answer_keys FROM anon, authenticated;
REVOKE ALL ON public.writing_answer_keys FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.quiz_answer_keys TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.writing_answer_keys TO authenticated;

CREATE FUNCTION public.englify_admin_upsert_quiz_question(
  p_request_id uuid,
  p_question_id uuid,
  p_data jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_existing public.quiz_questions%ROWTYPE;
  v_exists boolean;
  v_lesson_id uuid;
  v_position integer;
  v_kind text;
  v_prompt text;
  v_explanation text;
  v_payload jsonb;
  v_answer jsonb;
  v_response jsonb;
  v_resource text;
BEGIN
  IF v_actor IS NULL OR NOT public.englify_is_admin() THEN
    RAISE EXCEPTION 'Administrator access required' USING ERRCODE = '42501';
  END IF;
  IF p_request_id IS NULL OR p_question_id IS NULL OR p_data IS NULL
    OR pg_catalog.jsonb_typeof(p_data) <> 'object' THEN
    RAISE EXCEPTION 'Invalid quiz mutation request' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.jsonb_object_keys(p_data) AS field(name)
    WHERE field.name NOT IN ('lesson_id', 'position', 'kind', 'prompt', 'explanation', 'payload', 'answer')
  ) THEN
    RAISE EXCEPTION 'Unknown quiz question field' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.admin_mutation_requests(actor_id, request_id, resource, record_id)
  VALUES (v_actor, p_request_id, 'quiz-questions', p_question_id)
  ON CONFLICT (actor_id, request_id) DO NOTHING;
  IF NOT FOUND THEN
    SELECT resource, response INTO v_resource, v_response
    FROM public.admin_mutation_requests
    WHERE actor_id = v_actor AND request_id = p_request_id;
    IF v_resource <> 'quiz-questions' OR v_response = '{}'::jsonb THEN
      RAISE EXCEPTION 'Idempotency key already used' USING ERRCODE = '22023';
    END IF;
    RETURN v_response;
  END IF;

  SELECT * INTO v_existing
  FROM public.quiz_questions
  WHERE id = p_question_id
  FOR UPDATE;
  v_exists := FOUND;

  IF NOT v_exists AND NOT (p_data ?& ARRAY['lesson_id', 'position', 'kind', 'prompt']) THEN
    RAISE EXCEPTION 'New quiz question is incomplete' USING ERRCODE = '22023';
  END IF;

  v_lesson_id := CASE WHEN p_data ? 'lesson_id' THEN (p_data->>'lesson_id')::uuid ELSE v_existing.lesson_id END;
  v_position := CASE WHEN p_data ? 'position' THEN (p_data->>'position')::integer ELSE v_existing.position END;
  v_kind := CASE WHEN p_data ? 'kind' THEN pg_catalog.btrim(p_data->>'kind') ELSE v_existing.kind END;
  v_prompt := CASE WHEN p_data ? 'prompt' THEN pg_catalog.btrim(p_data->>'prompt') ELSE v_existing.prompt END;
  v_explanation := CASE WHEN p_data ? 'explanation' THEN pg_catalog.btrim(p_data->>'explanation') ELSE v_existing.explanation END;
  v_payload := CASE WHEN p_data ? 'payload' THEN p_data->'payload' ELSE v_existing.payload END;

  IF v_lesson_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.lessons WHERE id = v_lesson_id)
    OR v_position IS NULL OR v_position <= 0
    OR v_kind IS NULL OR v_kind NOT IN ('multiple_choice', 'fill_blank', 'matching', 'listening', 'grammar')
    OR v_prompt IS NULL OR v_prompt = ''
    OR v_payload IS NULL OR pg_catalog.jsonb_typeof(v_payload) <> 'object' THEN
    RAISE EXCEPTION 'Invalid quiz question data' USING ERRCODE = '22023';
  END IF;

  IF p_data ? 'answer' THEN
    v_answer := p_data->'answer';
    IF v_answer IS NULL OR v_answer = 'null'::jsonb
      OR (v_kind = 'matching' AND pg_catalog.jsonb_typeof(v_answer) <> 'object')
      OR (v_kind <> 'matching' AND pg_catalog.jsonb_typeof(v_answer) <> 'array') THEN
      RAISE EXCEPTION 'Invalid quiz answer data' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF v_exists THEN
    UPDATE public.quiz_questions
    SET lesson_id = v_lesson_id,
        position = v_position,
        kind = v_kind,
        prompt = v_prompt,
        explanation = coalesce(v_explanation, ''),
        payload = v_payload
    WHERE id = p_question_id;
  ELSE
    INSERT INTO public.quiz_questions(id, lesson_id, position, kind, prompt, explanation, payload)
    VALUES (p_question_id, v_lesson_id, v_position, v_kind, v_prompt, coalesce(v_explanation, ''), v_payload);
  END IF;

  IF p_data ? 'answer' THEN
    INSERT INTO public.quiz_answer_keys(question_id, answer)
    VALUES (p_question_id, v_answer)
    ON CONFLICT (question_id) DO UPDATE SET answer = EXCLUDED.answer;
  END IF;

  SELECT to_jsonb(q) || pg_catalog.jsonb_build_object('answer', a.answer)
  INTO v_response
  FROM public.quiz_questions AS q
  LEFT JOIN public.quiz_answer_keys AS a ON a.question_id = q.id
  WHERE q.id = p_question_id;

  UPDATE public.admin_mutation_requests
  SET response = v_response, record_id = p_question_id
  WHERE actor_id = v_actor AND request_id = p_request_id;
  RETURN v_response;
END;
$$;

REVOKE ALL ON FUNCTION public.englify_admin_upsert_quiz_question(uuid, uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_admin_upsert_quiz_question(uuid, uuid, jsonb)
  TO authenticated;

CREATE FUNCTION public.englify_admin_upsert_badge(
  p_request_id uuid,
  p_badge_id uuid,
  p_data jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_existing public.badges%ROWTYPE;
  v_exists boolean;
  v_code text;
  v_title text;
  v_description text;
  v_metric text;
  v_target integer;
  v_response jsonb;
  v_resource text;
BEGIN
  IF v_actor IS NULL OR NOT public.englify_is_admin() THEN
    RAISE EXCEPTION 'Administrator access required' USING ERRCODE = '42501';
  END IF;
  IF p_request_id IS NULL OR p_badge_id IS NULL OR p_data IS NULL
    OR pg_catalog.jsonb_typeof(p_data) <> 'object' THEN
    RAISE EXCEPTION 'Invalid badge mutation request' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.jsonb_object_keys(p_data) AS field(name)
    WHERE field.name NOT IN ('code', 'title', 'description', 'metric', 'target')
  ) THEN
    RAISE EXCEPTION 'Unknown badge field' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.admin_mutation_requests(actor_id, request_id, resource, record_id)
  VALUES (v_actor, p_request_id, 'badges', p_badge_id)
  ON CONFLICT (actor_id, request_id) DO NOTHING;
  IF NOT FOUND THEN
    SELECT resource, response INTO v_resource, v_response
    FROM public.admin_mutation_requests
    WHERE actor_id = v_actor AND request_id = p_request_id;
    IF v_resource <> 'badges' OR v_response = '{}'::jsonb THEN
      RAISE EXCEPTION 'Idempotency key already used' USING ERRCODE = '22023';
    END IF;
    RETURN v_response;
  END IF;

  SELECT * INTO v_existing FROM public.badges WHERE id = p_badge_id FOR UPDATE;
  v_exists := FOUND;
  IF NOT v_exists AND NOT (p_data ?& ARRAY['code', 'title', 'metric', 'target']) THEN
    RAISE EXCEPTION 'New badge is incomplete' USING ERRCODE = '22023';
  END IF;

  v_code := CASE WHEN p_data ? 'code' THEN pg_catalog.lower(pg_catalog.btrim(p_data->>'code')) ELSE v_existing.code END;
  v_title := CASE WHEN p_data ? 'title' THEN pg_catalog.btrim(p_data->>'title') ELSE v_existing.title END;
  v_description := CASE WHEN p_data ? 'description' THEN pg_catalog.btrim(p_data->>'description') ELSE v_existing.description END;
  SELECT metric, target INTO v_metric, v_target FROM public.badge_rules WHERE badge_id = p_badge_id;
  v_metric := CASE WHEN p_data ? 'metric' THEN pg_catalog.btrim(p_data->>'metric') ELSE v_metric END;
  v_target := CASE WHEN p_data ? 'target' THEN (p_data->>'target')::integer ELSE v_target END;

  IF v_code IS NULL OR v_code !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    OR v_title IS NULL OR v_title = '' OR pg_catalog.length(v_title) > 120
    OR v_metric IS NULL OR v_metric NOT IN ('completed_lessons', 'total_xp')
    OR v_target IS NULL OR v_target <= 0 THEN
    RAISE EXCEPTION 'Invalid badge data' USING ERRCODE = '22023';
  END IF;

  IF v_exists THEN
    UPDATE public.badges
    SET code = v_code, title = v_title, description = coalesce(v_description, '')
    WHERE id = p_badge_id;
  ELSE
    INSERT INTO public.badges(id, code, title, description)
    VALUES (p_badge_id, v_code, v_title, coalesce(v_description, ''));
  END IF;

  INSERT INTO public.badge_rules(badge_id, metric, target)
  VALUES (p_badge_id, v_metric, v_target)
  ON CONFLICT (badge_id) DO UPDATE SET metric = EXCLUDED.metric, target = EXCLUDED.target;

  SELECT to_jsonb(b) || pg_catalog.jsonb_build_object('metric', r.metric, 'target', r.target)
  INTO v_response
  FROM public.badges AS b
  JOIN public.badge_rules AS r ON r.badge_id = b.id
  WHERE b.id = p_badge_id;

  UPDATE public.admin_mutation_requests
  SET response = v_response, record_id = p_badge_id
  WHERE actor_id = v_actor AND request_id = p_request_id;
  RETURN v_response;
END;
$$;

REVOKE ALL ON FUNCTION public.englify_admin_upsert_badge(uuid, uuid, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_admin_upsert_badge(uuid, uuid, jsonb)
  TO authenticated;
