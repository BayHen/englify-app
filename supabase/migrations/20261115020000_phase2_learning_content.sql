-- Phase 2: scalable content discovery, reading progress and vocabulary review.
-- Additive migration: existing content IDs and user history are preserved.
CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.englify_normalize_search(p_value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = ''
AS $$ SELECT lower(extensions.unaccent(coalesce(p_value, ''))) $$;
REVOKE ALL ON FUNCTION public.englify_normalize_search(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_normalize_search(text) TO authenticated, service_role;

ALTER TABLE public.dictionary_entries
  ADD COLUMN cefr_level text,
  ADD COLUMN topic text,
  ADD COLUMN example_vi text,
  ADD COLUMN usage_notes text NOT NULL DEFAULT '',
  ADD COLUMN source_url text,
  ADD COLUMN quality_status text NOT NULL DEFAULT 'draft';
ALTER TABLE public.dictionary_entries
  ADD CONSTRAINT dictionary_entries_cefr_check CHECK (cefr_level IS NULL OR cefr_level IN ('A1','A2','B1','B2','C1','C2')),
  ADD CONSTRAINT dictionary_entries_quality_check CHECK (quality_status IN ('draft','validated','in_review','approved','published','rejected','archived')),
  ADD CONSTRAINT dictionary_entries_source_url_check CHECK (source_url IS NULL OR source_url LIKE 'https://%');
UPDATE public.dictionary_entries
SET quality_status = CASE WHEN is_published AND archived_at IS NULL THEN 'published' ELSE 'draft' END
WHERE quality_status = 'draft';
CREATE INDEX dictionary_entries_cefr_topic_idx ON public.dictionary_entries (cefr_level, topic, normalized_term)
  WHERE is_published AND archived_at IS NULL;
CREATE INDEX dictionary_entries_search_trgm_idx ON public.dictionary_entries
  USING gin (public.englify_normalize_search(term || ' ' || coalesce(translation,'') || ' ' || definition) extensions.gin_trgm_ops)
  WHERE is_published AND archived_at IS NULL;

ALTER TABLE public.real_english_expressions
  ADD COLUMN cefr_level text,
  ADD COLUMN topic_slug text;
ALTER TABLE public.real_english_expressions
  ADD CONSTRAINT real_english_expressions_cefr_check CHECK (cefr_level IS NULL OR cefr_level IN ('A1','A2','B1','B2','C1','C2'));
CREATE INDEX real_english_expressions_filter_idx ON public.real_english_expressions (cefr_level, topic_slug, kind, expression)
  WHERE is_published AND archived_at IS NULL;
CREATE INDEX real_english_expressions_search_trgm_idx ON public.real_english_expressions
  USING gin (public.englify_normalize_search(expression || ' ' || meaning_vi || ' ' || context_explanation || ' ' || example_en || ' ' || example_vi) extensions.gin_trgm_ops)
  WHERE is_published AND archived_at IS NULL;
CREATE INDEX real_english_lessons_title_search_idx ON public.real_english_lessons
  USING gin (public.englify_normalize_search(title || ' ' || description) extensions.gin_trgm_ops)
  WHERE status = 'published';
CREATE INDEX real_english_phrases_search_idx ON public.real_english_phrases
  USING gin (public.englify_normalize_search(english_text || ' ' || vietnamese_translation || ' ' || usage_context) extensions.gin_trgm_ops);
ALTER TABLE public.real_english_phrases
  ADD COLUMN dictionary_entry_id uuid REFERENCES public.dictionary_entries(id) ON DELETE SET NULL;
CREATE INDEX real_english_phrases_dictionary_idx ON public.real_english_phrases(dictionary_entry_id) WHERE dictionary_entry_id IS NOT NULL;
UPDATE public.real_english_phrases p SET dictionary_entry_id=d.id
FROM public.dictionary_entries d
WHERE d.language='en' AND d.is_published AND d.archived_at IS NULL
  AND d.normalized_term=public.englify_normalize_search(p.english_text);
CREATE INDEX real_english_dialogue_lines_search_idx ON public.real_english_dialogue_lines
  USING gin (public.englify_normalize_search(english_text || ' ' || vietnamese_translation) extensions.gin_trgm_ops);

ALTER TABLE public.real_english_user_progress DROP CONSTRAINT real_english_user_progress_status_check;
ALTER TABLE public.real_english_user_progress DROP CONSTRAINT real_english_progress_completed;
-- The V1 guard correctly prevents learners from rewriting completed history,
-- but this one-time status vocabulary migration must translate that history.
-- Drop only the guard trigger inside this migration transaction and recreate it
-- immediately after installing the monotonic Phase 2 guard below.
DROP TRIGGER IF EXISTS real_english_progress_guard ON public.real_english_user_progress;
UPDATE public.real_english_user_progress SET status = CASE status WHEN 'completed' THEN 'read' ELSE 'reading' END;
ALTER TABLE public.real_english_user_progress
  ADD COLUMN reading_percent smallint NOT NULL DEFAULT 0,
  ADD COLUMN practiced_at timestamptz,
  ADD COLUMN passed_at timestamptz,
  ADD COLUMN mastered_at timestamptz,
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now(),
  ADD CONSTRAINT real_english_progress_status_check CHECK (status IN ('reading','read','practiced','passed','mastered')),
  ADD CONSTRAINT real_english_progress_percent_check CHECK (reading_percent BETWEEN 0 AND 100),
  ADD CONSTRAINT real_english_progress_read_check CHECK (status = 'reading' OR completed_at IS NOT NULL);

CREATE OR REPLACE FUNCTION public.englify_real_english_progress_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_old_rank integer; v_new_rank integer;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.real_english_lessons l WHERE l.id=NEW.lesson_id AND l.status='published') THEN
    RAISE EXCEPTION 'Published lesson required' USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' THEN
    IF NEW.user_id<>OLD.user_id OR NEW.lesson_id<>OLD.lesson_id THEN
      RAISE EXCEPTION 'Learning ownership is immutable' USING ERRCODE='42501';
    END IF;
    v_old_rank := array_position(ARRAY['reading','read','practiced','passed','mastered'], OLD.status);
    v_new_rank := array_position(ARRAY['reading','read','practiced','passed','mastered'], NEW.status);
    IF v_new_rank < v_old_rank OR NEW.reading_percent < OLD.reading_percent THEN
      RAISE EXCEPTION 'Learning history cannot move backwards' USING ERRCODE='42501';
    END IF;
  END IF;
  IF NEW.status <> 'reading' THEN
    IF TG_OP='UPDATE' THEN NEW.completed_at := coalesce(OLD.completed_at, NEW.completed_at, now());
    ELSE NEW.completed_at := coalesce(NEW.completed_at, now()); END IF;
    NEW.reading_percent := 100;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_real_english_progress_guard() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER real_english_progress_guard BEFORE INSERT OR UPDATE ON public.real_english_user_progress
  FOR EACH ROW EXECUTE FUNCTION public.englify_real_english_progress_guard();

REVOKE INSERT, UPDATE ON public.real_english_user_progress FROM authenticated;
CREATE OR REPLACE FUNCTION public.englify_record_real_english_reading(
  p_lesson_id uuid, p_action text, p_reading_percent integer DEFAULT NULL, p_bookmarked boolean DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid := auth.uid(); v_row public.real_english_user_progress%ROWTYPE; v_status text;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_action NOT IN ('open','read','bookmark') THEN RAISE EXCEPTION 'Invalid progress action' USING ERRCODE='22023'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.real_english_lessons WHERE id=p_lesson_id AND status='published') THEN
    RAISE EXCEPTION 'Published lesson not found' USING ERRCODE='P0002';
  END IF;
  SELECT * INTO v_row FROM public.real_english_user_progress WHERE user_id=v_uid AND lesson_id=p_lesson_id FOR UPDATE;
  v_status := CASE WHEN p_action='read' THEN 'read' ELSE coalesce(v_row.status,'reading') END;
  INSERT INTO public.real_english_user_progress(user_id,lesson_id,status,is_bookmarked,last_accessed_at,completed_at,reading_percent)
  VALUES (v_uid,p_lesson_id,v_status,coalesce(p_bookmarked,false),now(),CASE WHEN v_status='read' THEN now() END,
    CASE WHEN v_status='read' THEN 100 ELSE least(99,greatest(0,coalesce(p_reading_percent,0))) END)
  ON CONFLICT (user_id,lesson_id) DO UPDATE SET
    status=CASE WHEN public.real_english_user_progress.status IN ('practiced','passed','mastered') THEN public.real_english_user_progress.status ELSE excluded.status END,
    is_bookmarked=coalesce(p_bookmarked,public.real_english_user_progress.is_bookmarked),
    last_accessed_at=now(),
    completed_at=coalesce(public.real_english_user_progress.completed_at,excluded.completed_at),
    reading_percent=greatest(public.real_english_user_progress.reading_percent,excluded.reading_percent)
  RETURNING * INTO v_row;
  RETURN to_jsonb(v_row);
END $$;
REVOKE ALL ON FUNCTION public.englify_record_real_english_reading(uuid,text,integer,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_record_real_english_reading(uuid,text,integer,boolean) TO authenticated,service_role;

CREATE TABLE public.real_english_comprehension_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id uuid NOT NULL REFERENCES public.real_english_lessons(id) ON DELETE CASCADE,
  position integer NOT NULL CHECK (position > 0),
  prompt text NOT NULL CHECK (length(btrim(prompt)) BETWEEN 3 AND 500),
  options jsonb NOT NULL CHECK (jsonb_typeof(options)='array' AND jsonb_array_length(options) BETWEEN 2 AND 6),
  explanation text NOT NULL DEFAULT '',
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (lesson_id,position)
);
CREATE TABLE public.real_english_comprehension_keys (
  question_id uuid PRIMARY KEY REFERENCES public.real_english_comprehension_questions(id) ON DELETE CASCADE,
  answer_id text NOT NULL
);
CREATE TABLE public.real_english_comprehension_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id uuid NOT NULL REFERENCES public.real_english_lessons(id),
  question_id uuid NOT NULL REFERENCES public.real_english_comprehension_questions(id),
  request_id uuid NOT NULL,
  selected_option text NOT NULL,
  is_correct boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id,request_id)
);
ALTER TABLE public.real_english_comprehension_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.real_english_comprehension_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.real_english_comprehension_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.real_english_comprehension_questions,public.real_english_comprehension_keys,public.real_english_comprehension_attempts FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.real_english_comprehension_questions,public.real_english_comprehension_keys TO authenticated;
GRANT SELECT ON public.real_english_comprehension_attempts TO authenticated;
GRANT ALL ON public.real_english_comprehension_questions,public.real_english_comprehension_keys,public.real_english_comprehension_attempts TO service_role;
CREATE POLICY comprehension_questions_read ON public.real_english_comprehension_questions FOR SELECT TO authenticated USING (
  is_published AND EXISTS (SELECT 1 FROM public.real_english_lessons l WHERE l.id=lesson_id AND l.status='published') OR public.englify_is_admin());
CREATE POLICY comprehension_questions_admin ON public.real_english_comprehension_questions FOR ALL TO authenticated USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin());
CREATE POLICY comprehension_keys_admin ON public.real_english_comprehension_keys FOR ALL TO authenticated USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin());
CREATE POLICY comprehension_attempts_own ON public.real_english_comprehension_attempts FOR SELECT TO authenticated USING (user_id=(SELECT auth.uid()));

CREATE OR REPLACE FUNCTION public.englify_real_english_questions(p_lesson_id uuid) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' STABLE AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',q.id,'prompt',q.prompt,'options',q.options,'position',q.position) ORDER BY q.position),'[]'::jsonb)
  FROM public.real_english_comprehension_questions q
  JOIN public.real_english_lessons l ON l.id=q.lesson_id
  WHERE q.lesson_id=p_lesson_id AND q.is_published AND l.status='published' AND auth.uid() IS NOT NULL
$$;
REVOKE ALL ON FUNCTION public.englify_real_english_questions(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_real_english_questions(uuid) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.englify_submit_real_english_comprehension(
  p_lesson_id uuid,p_question_id uuid,p_request_id uuid,p_selected_option text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_question public.real_english_comprehension_questions%ROWTYPE;
  v_answer text; v_attempt public.real_english_comprehension_attempts%ROWTYPE; v_correct boolean; v_progress public.real_english_user_progress%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_attempt FROM public.real_english_comprehension_attempts WHERE user_id=v_uid AND request_id=p_request_id;
  IF FOUND THEN RETURN jsonb_build_object('attempt_id',v_attempt.id,'is_correct',v_attempt.is_correct); END IF;
  SELECT q.* INTO v_question FROM public.real_english_comprehension_questions q JOIN public.real_english_lessons l ON l.id=q.lesson_id
    WHERE q.id=p_question_id AND q.lesson_id=p_lesson_id AND q.is_published AND l.status='published';
  IF NOT FOUND THEN RAISE EXCEPTION 'Published question not found' USING ERRCODE='P0002'; END IF;
  SELECT answer_id INTO v_answer FROM public.real_english_comprehension_keys WHERE question_id=p_question_id;
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_question.options) o WHERE o->>'id'=p_selected_option) THEN
    RAISE EXCEPTION 'Invalid answer option' USING ERRCODE='22023';
  END IF;
  v_correct := p_selected_option=v_answer;
  INSERT INTO public.real_english_comprehension_attempts(user_id,lesson_id,question_id,request_id,selected_option,is_correct)
    VALUES(v_uid,p_lesson_id,p_question_id,p_request_id,p_selected_option,v_correct) RETURNING * INTO v_attempt;
  INSERT INTO public.real_english_user_progress(user_id,lesson_id,status,reading_percent,completed_at,practiced_at,passed_at)
    VALUES(v_uid,p_lesson_id,CASE WHEN v_correct THEN 'passed' ELSE 'practiced' END,100,now(),now(),CASE WHEN v_correct THEN now() END)
  ON CONFLICT(user_id,lesson_id) DO UPDATE SET status=CASE
      WHEN public.real_english_user_progress.status='mastered' THEN 'mastered'
      WHEN v_correct THEN 'passed'
      WHEN public.real_english_user_progress.status='passed' THEN 'passed' ELSE 'practiced' END,
    reading_percent=100,completed_at=coalesce(public.real_english_user_progress.completed_at,now()),practiced_at=coalesce(public.real_english_user_progress.practiced_at,now()),
    passed_at=CASE WHEN v_correct THEN coalesce(public.real_english_user_progress.passed_at,now()) ELSE public.real_english_user_progress.passed_at END
  RETURNING * INTO v_progress;
  RETURN jsonb_build_object('attempt_id',v_attempt.id,'is_correct',v_correct,'correct_option',v_answer,
    'explanation',v_question.explanation,'progress_status',v_progress.status);
END $$;
REVOKE ALL ON FUNCTION public.englify_submit_real_english_comprehension(uuid,uuid,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_submit_real_english_comprehension(uuid,uuid,uuid,text) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.englify_search_real_english(
  p_query text DEFAULT '',p_cefr text DEFAULT NULL,p_topic text DEFAULT NULL,p_category text DEFAULT NULL,
  p_saved_only boolean DEFAULT false,p_page integer DEFAULT 1,p_page_size integer DEFAULT 5
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' STABLE AS $$
DECLARE v_uid uuid:=auth.uid(); v_query text:=public.englify_normalize_search(left(btrim(coalesce(p_query,'')),80));
  v_page integer:=greatest(1,coalesce(p_page,1)); v_size integer:=least(20,greatest(1,coalesce(p_page_size,5))); v_total bigint; v_items jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF length(btrim(coalesce(p_query,'')))>80 THEN RAISE EXCEPTION 'Search term is too long' USING ERRCODE='22023'; END IF;
  IF p_cefr IS NOT NULL AND p_cefr NOT IN ('A1','A2','B1','B2','C1','C2') THEN RAISE EXCEPTION 'Invalid CEFR level' USING ERRCODE='22023'; END IF;
  WITH library AS (
    SELECT 'expression'::text item_type,e.id,e.expression title,e.meaning_vi subtitle,e.cefr_level,e.topic_slug,
      e.kind category,e.formality,e.created_at sort_at,
      EXISTS(SELECT 1 FROM public.saved_expressions s WHERE s.user_id=v_uid AND s.expression_id=e.id) saved,
      NULL::text progress_status
    FROM public.real_english_expressions e
    WHERE e.is_published AND e.archived_at IS NULL
      AND (v_query='' OR public.englify_normalize_search(e.expression||' '||e.meaning_vi||' '||e.context_explanation||' '||e.example_en||' '||e.example_vi||' '||e.dialogue::text) LIKE '%'||v_query||'%')
    UNION ALL
    SELECT 'lesson',l.id,l.title,l.description,l.difficulty,t.slug,l.content_type,NULL,l.published_at,
      coalesce(p.is_bookmarked,false),p.status
    FROM public.real_english_lessons l JOIN public.real_english_topics t ON t.id=l.topic_id
    LEFT JOIN public.real_english_user_progress p ON p.lesson_id=l.id AND p.user_id=v_uid
    WHERE l.status='published'
      AND (v_query='' OR public.englify_normalize_search(l.title||' '||l.description||' '||t.title) LIKE '%'||v_query||'%'
        OR EXISTS(SELECT 1 FROM public.real_english_phrases ph WHERE ph.lesson_id=l.id AND public.englify_normalize_search(ph.english_text||' '||ph.vietnamese_translation||' '||ph.usage_context) LIKE '%'||v_query||'%')
        OR EXISTS(SELECT 1 FROM public.real_english_dialogues d JOIN public.real_english_dialogue_lines dl ON dl.dialogue_id=d.id WHERE d.lesson_id=l.id AND public.englify_normalize_search(dl.english_text||' '||dl.vietnamese_translation) LIKE '%'||v_query||'%'))
  ), filtered AS (
    SELECT * FROM library WHERE (p_cefr IS NULL OR cefr_level=p_cefr) AND (p_topic IS NULL OR topic_slug=p_topic)
      AND (p_category IS NULL OR category=p_category) AND (NOT p_saved_only OR saved)
  )
  SELECT (SELECT count(*) FROM filtered),
    (SELECT coalesce(jsonb_agg(to_jsonb(page_rows)-'sort_at' ORDER BY sort_at DESC,id),'[]'::jsonb)
      FROM (SELECT * FROM filtered ORDER BY sort_at DESC,id OFFSET (v_page-1)*v_size LIMIT v_size) page_rows)
  INTO v_total,v_items;
  RETURN jsonb_build_object('items',v_items,'total',v_total,'page',v_page,'page_size',v_size,
    'page_count',greatest(1,ceil(v_total::numeric/v_size)::integer));
END $$;
REVOKE ALL ON FUNCTION public.englify_search_real_english(text,text,text,text,boolean,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_search_real_english(text,text,text,text,boolean,integer,integer) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.englify_save_real_english_phrase(p_phrase_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_entry uuid; v_saved public.saved_vocabulary%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  SELECT p.dictionary_entry_id INTO v_entry FROM public.real_english_phrases p
    JOIN public.real_english_lessons l ON l.id=p.lesson_id
    WHERE p.id=p_phrase_id AND l.status='published';
  IF v_entry IS NULL THEN RAISE EXCEPTION 'This phrase is not linked to reviewed vocabulary' USING ERRCODE='P0002'; END IF;
  INSERT INTO public.saved_vocabulary(user_id,entry_id,next_review_at)
    VALUES(v_uid,v_entry,now()) ON CONFLICT(user_id,entry_id) DO UPDATE SET updated_at=now()
    RETURNING * INTO v_saved;
  RETURN to_jsonb(v_saved);
END $$;
REVOKE ALL ON FUNCTION public.englify_save_real_english_phrase(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_save_real_english_phrase(uuid) TO authenticated,service_role;

CREATE TABLE public.content_import_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), actor_id uuid NOT NULL REFERENCES auth.users(id),
  content_type text NOT NULL CHECK(content_type IN ('vocabulary','lesson','quiz','real_english')),
  source_name text NOT NULL,license_id text NOT NULL,source_url text,
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','validated','in_review','approved','published','rejected')),
  idempotency_key text NOT NULL UNIQUE,record_count integer NOT NULL DEFAULT 0 CHECK(record_count>=0),
  validation_errors jsonb NOT NULL DEFAULT '[]'::jsonb CHECK(jsonb_typeof(validation_errors)='array'),
  created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.content_import_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),batch_id uuid NOT NULL REFERENCES public.content_import_batches(id) ON DELETE CASCADE,
  external_id text NOT NULL,payload jsonb NOT NULL CHECK(jsonb_typeof(payload)='object'),normalized_hash text NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','validated','rejected','imported')),
  validation_errors jsonb NOT NULL DEFAULT '[]'::jsonb CHECK(jsonb_typeof(validation_errors)='array'),
  created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(batch_id,external_id),UNIQUE(batch_id,normalized_hash)
);
ALTER TABLE public.content_import_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_import_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.content_import_batches,public.content_import_items FROM anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.content_import_batches,public.content_import_items TO authenticated;
GRANT ALL ON public.content_import_batches,public.content_import_items TO service_role;
CREATE POLICY content_import_batches_admin ON public.content_import_batches FOR ALL TO authenticated USING(public.englify_is_admin()) WITH CHECK(public.englify_is_admin() AND actor_id=auth.uid());
CREATE POLICY content_import_items_admin ON public.content_import_items FOR ALL TO authenticated USING(public.englify_is_admin()) WITH CHECK(public.englify_is_admin());

