-- Writing V2.1 adds server-authored AI feedback, rewrites, revisions and quota accounting.
-- Existing submissions, deterministic feedback and LanguageTool data remain unchanged.

CREATE TABLE public.writing_ai_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES public.writing_submissions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  request_id uuid NOT NULL,
  overall_score smallint NOT NULL CHECK (overall_score BETWEEN 0 AND 100),
  grammar_score smallint NOT NULL CHECK (grammar_score BETWEEN 0 AND 100),
  vocabulary_score smallint NOT NULL CHECK (vocabulary_score BETWEEN 0 AND 100),
  sentence_structure_score smallint NOT NULL CHECK (sentence_structure_score BETWEEN 0 AND 100),
  coherence_score smallint NOT NULL CHECK (coherence_score BETWEEN 0 AND 100),
  task_score smallint NOT NULL CHECK (task_score BETWEEN 0 AND 100),
  assessment_vi text NOT NULL CHECK (length(assessment_vi) BETWEEN 1 AND 1000),
  strengths jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(strengths) = 'array'),
  improvements jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(improvements) = 'array'),
  errors jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(errors) = 'array'),
  next_steps jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(next_steps) = 'array'),
  model text NOT NULL CHECK (length(model) BETWEEN 1 AND 100),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, request_id)
);

CREATE TABLE public.writing_ai_rewrites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES public.writing_submissions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  request_id uuid NOT NULL,
  mode text NOT NULL CHECK (mode IN ('grammar','natural','vocabulary','formal','simple')),
  original_text text NOT NULL CHECK (length(original_text) BETWEEN 1 AND 5000),
  improved_text text NOT NULL CHECK (length(improved_text) BETWEEN 1 AND 5000),
  key_changes jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(key_changes) = 'array'),
  explanations_vi jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(explanations_vi) = 'array'),
  vocabulary_suggestions jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(vocabulary_suggestions) = 'array'),
  model text NOT NULL CHECK (length(model) BETWEEN 1 AND 100),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, request_id)
);

CREATE TABLE public.writing_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid NOT NULL REFERENCES public.writing_submissions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  request_id uuid NOT NULL,
  revision_number integer NOT NULL CHECK (revision_number > 0),
  revised_text text NOT NULL CHECK (length(revised_text) BETWEEN 1 AND 5000),
  rewrite_id uuid REFERENCES public.writing_ai_rewrites(id) ON DELETE SET NULL,
  ai_feedback_id uuid REFERENCES public.writing_ai_feedback(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, request_id),
  UNIQUE (submission_id, revision_number)
);

CREATE TABLE public.writing_ai_usage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  request_kind text NOT NULL CHECK (request_kind IN ('coach','rewrite')),
  request_id uuid NOT NULL,
  usage_date date NOT NULL DEFAULT (timezone('utc', now())::date),
  status text NOT NULL DEFAULT 'processing' CHECK (status IN ('processing','completed','failed')),
  input_tokens integer NOT NULL DEFAULT 0 CHECK (input_tokens >= 0),
  output_tokens integer NOT NULL DEFAULT 0 CHECK (output_tokens >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  UNIQUE (user_id, request_kind, request_id)
);

CREATE INDEX writing_ai_feedback_submission_recent_idx ON public.writing_ai_feedback(submission_id, created_at DESC);
CREATE INDEX writing_ai_rewrites_submission_recent_idx ON public.writing_ai_rewrites(submission_id, created_at DESC);
CREATE INDEX writing_revisions_submission_number_idx ON public.writing_revisions(submission_id, revision_number DESC);
CREATE INDEX writing_ai_usage_daily_idx ON public.writing_ai_usage(user_id, request_kind, usage_date);

ALTER TABLE public.writing_ai_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.writing_ai_rewrites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.writing_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.writing_ai_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY writing_ai_feedback_own_read ON public.writing_ai_feedback
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);
CREATE POLICY writing_ai_rewrites_own_read ON public.writing_ai_rewrites
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);
CREATE POLICY writing_revisions_own_read ON public.writing_revisions
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);

REVOKE ALL ON public.writing_ai_feedback, public.writing_ai_rewrites,
  public.writing_revisions, public.writing_ai_usage FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.writing_ai_feedback, public.writing_ai_rewrites, public.writing_revisions TO authenticated;
GRANT ALL ON public.writing_ai_feedback, public.writing_ai_rewrites,
  public.writing_revisions, public.writing_ai_usage TO service_role;

CREATE FUNCTION public.englify_claim_writing_ai_request(
  p_user_id uuid, p_request_kind text, p_request_id uuid, p_daily_limit integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_existing public.writing_ai_usage%ROWTYPE; v_id uuid; v_used integer;
BEGIN
  IF p_user_id IS NULL OR p_request_id IS NULL OR p_request_kind NOT IN ('coach','rewrite')
    OR p_daily_limit NOT BETWEEN 1 AND 20 THEN
    RAISE EXCEPTION 'Invalid AI quota request' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('writing-ai:' || p_user_id::text || ':' || p_request_kind));
  SELECT * INTO v_existing FROM public.writing_ai_usage
    WHERE user_id=p_user_id AND request_kind=p_request_kind AND request_id=p_request_id;
  IF FOUND THEN
    RETURN jsonb_build_object('usage_id',v_existing.id,'duplicate',true,'status',v_existing.status);
  END IF;
  SELECT count(*) INTO v_used FROM public.writing_ai_usage
    WHERE user_id=p_user_id AND request_kind=p_request_kind
      AND usage_date=pg_catalog.timezone('utc',pg_catalog.now())::date;
  IF v_used >= p_daily_limit THEN
    RAISE SQLSTATE 'PT429' USING MESSAGE='Daily AI writing limit reached';
  END IF;
  INSERT INTO public.writing_ai_usage(user_id,request_kind,request_id)
    VALUES(p_user_id,p_request_kind,p_request_id) RETURNING id INTO v_id;
  RETURN jsonb_build_object('usage_id',v_id,'duplicate',false,'status','processing');
END $$;
REVOKE ALL ON FUNCTION public.englify_claim_writing_ai_request(uuid,text,uuid,integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.englify_claim_writing_ai_request(uuid,text,uuid,integer) TO service_role;

CREATE FUNCTION public.englify_create_writing_revision(
  p_request_id uuid, p_submission_id uuid, p_revised_text text,
  p_rewrite_id uuid DEFAULT NULL, p_ai_feedback_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid uuid := auth.uid(); v_text text := pg_catalog.btrim(p_revised_text);
  v_existing public.writing_revisions%ROWTYPE; v_number integer; v_row public.writing_revisions%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_request_id IS NULL OR p_submission_id IS NULL OR pg_catalog.length(v_text) NOT BETWEEN 1 AND 5000 THEN
    RAISE EXCEPTION 'Revision must contain 1-5000 characters' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('writing-revision:'||v_uid::text||':'||p_submission_id::text));
  SELECT * INTO v_existing FROM public.writing_revisions WHERE user_id=v_uid AND request_id=p_request_id;
  IF FOUND THEN
    IF v_existing.submission_id<>p_submission_id OR v_existing.revised_text<>v_text THEN
      RAISE SQLSTATE 'PT409' USING MESSAGE='Revision ID belongs to another response';
    END IF;
    RETURN to_jsonb(v_existing);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.writing_submissions WHERE id=p_submission_id AND user_id=v_uid) THEN
    RAISE EXCEPTION 'Writing submission not found' USING ERRCODE='P0002';
  END IF;
  IF p_rewrite_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.writing_ai_rewrites
    WHERE id=p_rewrite_id AND submission_id=p_submission_id AND user_id=v_uid) THEN
    RAISE EXCEPTION 'AI rewrite not found' USING ERRCODE='P0002';
  END IF;
  IF p_ai_feedback_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.writing_ai_feedback
    WHERE id=p_ai_feedback_id AND submission_id=p_submission_id AND user_id=v_uid) THEN
    RAISE EXCEPTION 'AI feedback not found' USING ERRCODE='P0002';
  END IF;
  SELECT coalesce(max(revision_number),0)+1 INTO v_number FROM public.writing_revisions WHERE submission_id=p_submission_id;
  INSERT INTO public.writing_revisions(submission_id,user_id,request_id,revision_number,revised_text,rewrite_id,ai_feedback_id)
    VALUES(p_submission_id,v_uid,p_request_id,v_number,v_text,p_rewrite_id,p_ai_feedback_id) RETURNING * INTO v_row;
  RETURN to_jsonb(v_row);
END $$;
REVOKE ALL ON FUNCTION public.englify_create_writing_revision(uuid,uuid,text,uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_create_writing_revision(uuid,uuid,text,uuid,uuid) TO authenticated;
