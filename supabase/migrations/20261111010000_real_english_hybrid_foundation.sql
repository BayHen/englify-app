-- Additive hybrid Real English schema. Existing expressions and saved items remain intact.
CREATE TABLE public.real_english_topics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  title text NOT NULL CHECK (length(btrim(title)) BETWEEN 2 AND 120),
  description text NOT NULL DEFAULT '',
  search_keyword text NOT NULL CHECK (length(btrim(search_keyword)) BETWEEN 1 AND 80),
  difficulty text NOT NULL CHECK (difficulty IN ('A1','A2','B1','B2','C1','C2')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.real_english_lessons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id uuid NOT NULL REFERENCES public.real_english_topics(id),
  title text NOT NULL CHECK (length(btrim(title)) BETWEEN 3 AND 160),
  description text NOT NULL DEFAULT '',
  content_type text NOT NULL CHECK (content_type IN ('expression','dialogue','scenario')),
  difficulty text NOT NULL CHECK (difficulty IN ('A1','A2','B1','B2','C1','C2')),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','approved','rejected','published','archived')),
  generation_source text NOT NULL DEFAULT 'human' CHECK (generation_source IN ('human','hybrid_ai')),
  validation_warnings jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(validation_warnings)='array'),
  created_by uuid REFERENCES auth.users(id),
  reviewed_by uuid REFERENCES auth.users(id),
  reviewed_at timestamptz,
  published_by uuid REFERENCES auth.users(id),
  published_at timestamptz,
  scheduled_publish_at timestamptz,
  rejection_reason text,
  content_version integer NOT NULL DEFAULT 1 CHECK (content_version > 0),
  normalized_hash text NOT NULL UNIQUE CHECK (normalized_hash ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT real_english_published_metadata CHECK (status <> 'published' OR (reviewed_by IS NOT NULL AND published_by IS NOT NULL AND published_at IS NOT NULL))
);
CREATE INDEX real_english_lessons_feed_idx ON public.real_english_lessons (published_at DESC, id) WHERE status='published';
CREATE INDEX real_english_lessons_review_idx ON public.real_english_lessons (status, created_at DESC);
CREATE INDEX real_english_lessons_topic_idx ON public.real_english_lessons (topic_id, status);

CREATE TABLE public.real_english_phrases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id uuid NOT NULL REFERENCES public.real_english_lessons(id) ON DELETE CASCADE,
  english_text text NOT NULL CHECK (length(btrim(english_text)) BETWEEN 1 AND 500),
  vietnamese_translation text NOT NULL CHECK (length(btrim(vietnamese_translation)) BETWEEN 1 AND 500),
  mymemory_candidate_vi text,
  ipa text,
  part_of_speech text,
  formality text NOT NULL DEFAULT 'neutral' CHECK (formality IN ('informal','neutral','formal')),
  usage_context text NOT NULL DEFAULT '',
  audio_url text CHECK (audio_url IS NULL OR audio_url LIKE 'https://%'),
  normalized_hash text NOT NULL UNIQUE CHECK (normalized_hash ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (lesson_id, normalized_hash)
);
CREATE INDEX real_english_phrases_lesson_idx ON public.real_english_phrases (lesson_id);

CREATE TABLE public.real_english_dialogues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id uuid NOT NULL UNIQUE REFERENCES public.real_english_lessons(id) ON DELETE CASCADE,
  title text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 160),
  context text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.real_english_dialogue_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dialogue_id uuid NOT NULL REFERENCES public.real_english_dialogues(id) ON DELETE CASCADE,
  speaker text NOT NULL CHECK (length(btrim(speaker)) BETWEEN 1 AND 80),
  english_text text NOT NULL CHECK (length(btrim(english_text)) BETWEEN 1 AND 500),
  vietnamese_translation text NOT NULL CHECK (length(btrim(vietnamese_translation)) BETWEEN 1 AND 500),
  sort_order integer NOT NULL CHECK (sort_order >= 0),
  UNIQUE (dialogue_id, sort_order)
);

CREATE TABLE public.real_english_source_references (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id uuid NOT NULL REFERENCES public.real_english_lessons(id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'tatoeba' CHECK (provider='tatoeba'),
  source_sentence_id bigint NOT NULL CHECK (source_sentence_id > 0),
  translation_sentence_id bigint NOT NULL CHECK (translation_sentence_id > 0),
  english_text text NOT NULL,
  vietnamese_text text NOT NULL,
  english_contributor text,
  vietnamese_contributor text,
  english_license text,
  vietnamese_license text,
  source_url text NOT NULL CHECK (source_url ~ '^https://api[.]tatoeba[.]org/v1/sentences/[0-9]+$'),
  translation_url text NOT NULL CHECK (translation_url ~ '^https://api[.]tatoeba[.]org/v1/sentences/[0-9]+$'),
  attribution_text text NOT NULL DEFAULT '',
  content_hash text NOT NULL CHECK (content_hash ~ '^[a-f0-9]{64}$'),
  validation_status text NOT NULL DEFAULT 'pending' CHECK (validation_status IN ('pending','eligible','blocked_license','blocked_content')),
  retrieved_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (lesson_id, source_sentence_id, translation_sentence_id),
  CONSTRAINT real_english_eligible_source CHECK (validation_status <> 'eligible' OR
    (english_license IN ('CC0 1.0','CC BY 2.0 FR') AND vietnamese_license IN ('CC0 1.0','CC BY 2.0 FR')
      AND (english_license='CC0 1.0' OR nullif(btrim(english_contributor),'') IS NOT NULL)
      AND (vietnamese_license='CC0 1.0' OR nullif(btrim(vietnamese_contributor),'') IS NOT NULL)
      AND nullif(btrim(attribution_text),'') IS NOT NULL))
);
CREATE INDEX real_english_sources_lesson_idx ON public.real_english_source_references (lesson_id);
CREATE INDEX real_english_sources_ids_idx ON public.real_english_source_references (source_sentence_id, translation_sentence_id);

CREATE TABLE public.real_english_generation_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  idempotency_key text NOT NULL UNIQUE CHECK (length(idempotency_key) BETWEEN 8 AND 160),
  provider text NOT NULL DEFAULT 'gemini' CHECK (provider='gemini'),
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','running','completed','failed','quota_blocked')),
  scheduled_for timestamptz NOT NULL,
  started_at timestamptz,
  completed_at timestamptz,
  lease_expires_at timestamptz,
  attempt_count integer NOT NULL DEFAULT 1 CHECK (attempt_count BETWEEN 1 AND 100),
  generated_count integer NOT NULL DEFAULT 0 CHECK (generated_count >= 0),
  rejected_count integer NOT NULL DEFAULT 0 CHECK (rejected_count >= 0),
  error_code text,
  error_message text,
  usage_metadata jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(usage_metadata)='object'),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX real_english_jobs_status_idx ON public.real_english_generation_jobs (status, scheduled_for);

CREATE TABLE public.real_english_review_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id uuid NOT NULL REFERENCES public.real_english_lessons(id),
  actor_id uuid NOT NULL REFERENCES auth.users(id),
  action text NOT NULL CHECK (action IN ('submit','approve','reject','publish','archive')),
  previous_status text NOT NULL,
  new_status text NOT NULL,
  content_version integer NOT NULL CHECK (content_version > 0),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX real_english_review_lesson_idx ON public.real_english_review_history (lesson_id, created_at DESC);

CREATE TABLE public.real_english_generation_settings (
  id boolean PRIMARY KEY DEFAULT true CHECK (id),
  ai_generation_enabled boolean NOT NULL DEFAULT false,
  source_import_enabled boolean NOT NULL DEFAULT false,
  daily_generation_target integer NOT NULL DEFAULT 5 CHECK (daily_generation_target BETWEEN 0 AND 20),
  enabled_topics text[] NOT NULL DEFAULT '{}'::text[],
  enabled_difficulty_levels text[] NOT NULL DEFAULT ARRAY['A1','A2','B1']::text[],
  generation_schedule text NOT NULL DEFAULT '0 0 * * *',
  maximum_daily_requests integer NOT NULL DEFAULT 5 CHECK (maximum_daily_requests BETWEEN 0 AND 20),
  maximum_output_tokens integer NOT NULL DEFAULT 1200 CHECK (maximum_output_tokens BETWEEN 128 AND 4096),
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.real_english_generation_settings (id) VALUES (true);

CREATE TABLE public.real_english_user_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id uuid NOT NULL REFERENCES public.real_english_lessons(id),
  status text NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress','completed')),
  is_bookmarked boolean NOT NULL DEFAULT false,
  last_accessed_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, lesson_id),
  CONSTRAINT real_english_progress_completed CHECK (status <> 'completed' OR completed_at IS NOT NULL)
);
CREATE INDEX real_english_progress_user_idx ON public.real_english_user_progress (user_id, last_accessed_at DESC);

-- Explicit privileges and RLS, including private job/settings/review tables.
DO $$ DECLARE v_table text; BEGIN
  FOREACH v_table IN ARRAY ARRAY['real_english_topics','real_english_lessons','real_english_phrases',
    'real_english_dialogues','real_english_dialogue_lines','real_english_source_references',
    'real_english_generation_jobs','real_english_review_history','real_english_generation_settings',
    'real_english_user_progress'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',v_table);
    EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated',v_table);
    EXECUTE format('GRANT ALL ON public.%I TO service_role',v_table);
  END LOOP;
END $$;

GRANT SELECT,INSERT,UPDATE ON public.real_english_topics,public.real_english_lessons,
  public.real_english_phrases,public.real_english_dialogues,public.real_english_dialogue_lines,
  public.real_english_source_references TO authenticated;
GRANT SELECT,UPDATE ON public.real_english_generation_settings TO authenticated;
GRANT SELECT ON public.real_english_review_history,public.real_english_generation_jobs TO authenticated;
GRANT SELECT,INSERT,UPDATE ON public.real_english_user_progress TO authenticated;

CREATE POLICY topics_read ON public.real_english_topics FOR SELECT TO authenticated USING (is_active OR public.englify_is_admin());
CREATE POLICY topics_admin ON public.real_english_topics FOR ALL TO authenticated USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin());
CREATE POLICY lessons_read ON public.real_english_lessons FOR SELECT TO authenticated USING (status='published' OR public.englify_is_admin());
CREATE POLICY lessons_admin ON public.real_english_lessons FOR ALL TO authenticated USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin());
CREATE POLICY phrases_read ON public.real_english_phrases FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.real_english_lessons l WHERE l.id=lesson_id AND (l.status='published' OR public.englify_is_admin())));
CREATE POLICY phrases_admin ON public.real_english_phrases FOR ALL TO authenticated USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin());
CREATE POLICY dialogues_read ON public.real_english_dialogues FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.real_english_lessons l WHERE l.id=lesson_id AND (l.status='published' OR public.englify_is_admin())));
CREATE POLICY dialogues_admin ON public.real_english_dialogues FOR ALL TO authenticated USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin());
CREATE POLICY dialogue_lines_read ON public.real_english_dialogue_lines FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.real_english_dialogues d JOIN public.real_english_lessons l ON l.id=d.lesson_id
    WHERE d.id=dialogue_id AND (l.status='published' OR public.englify_is_admin())));
CREATE POLICY dialogue_lines_admin ON public.real_english_dialogue_lines FOR ALL TO authenticated USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin());
CREATE POLICY references_read ON public.real_english_source_references FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.real_english_lessons l WHERE l.id=lesson_id AND (l.status='published' OR public.englify_is_admin())));
CREATE POLICY references_admin ON public.real_english_source_references FOR ALL TO authenticated USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin());
CREATE POLICY generation_jobs_admin_read ON public.real_english_generation_jobs FOR SELECT TO authenticated USING (public.englify_is_admin());
CREATE POLICY generation_settings_admin_read ON public.real_english_generation_settings FOR SELECT TO authenticated USING (public.englify_is_admin());
CREATE POLICY generation_settings_admin_update ON public.real_english_generation_settings FOR UPDATE TO authenticated
  USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin());
CREATE POLICY review_history_admin_read ON public.real_english_review_history FOR SELECT TO authenticated USING (public.englify_is_admin());
CREATE POLICY progress_own_read ON public.real_english_user_progress FOR SELECT TO authenticated USING ((SELECT auth.uid())=user_id);
CREATE POLICY progress_own_insert ON public.real_english_user_progress FOR INSERT TO authenticated WITH CHECK (
  (SELECT auth.uid())=user_id AND EXISTS (SELECT 1 FROM public.real_english_lessons l WHERE l.id=lesson_id AND l.status='published'));
CREATE POLICY progress_own_update ON public.real_english_user_progress FOR UPDATE TO authenticated
  USING ((SELECT auth.uid())=user_id) WITH CHECK ((SELECT auth.uid())=user_id);

-- Users cannot rewrite their completed learning history or point progress at drafts.
CREATE FUNCTION public.englify_real_english_progress_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.real_english_lessons l WHERE l.id=NEW.lesson_id AND l.status='published') THEN
    RAISE EXCEPTION 'Published lesson required' USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' THEN
    IF NEW.user_id<>OLD.user_id OR NEW.lesson_id<>OLD.lesson_id
      OR (OLD.status='completed' AND NEW.status<>'completed')
      OR (OLD.completed_at IS NOT NULL AND NEW.completed_at IS DISTINCT FROM OLD.completed_at) THEN
      RAISE EXCEPTION 'Learning history is immutable' USING ERRCODE='42501';
    END IF;
  END IF;
  IF NEW.status='completed' AND (TG_OP='INSERT' OR NEW.completed_at IS NULL) THEN
    NEW.completed_at:=now();
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_real_english_progress_guard() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER real_english_progress_guard BEFORE INSERT OR UPDATE ON public.real_english_user_progress
  FOR EACH ROW EXECUTE FUNCTION public.englify_real_english_progress_guard();

-- Publishing is guarded in the database even when an admin edits via PostgREST.
CREATE FUNCTION public.englify_real_english_publish_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF TG_OP='INSERT' AND NEW.status='published' THEN
    RAISE EXCEPTION 'Manual approval required before publishing' USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' AND OLD.status IN ('approved','published')
    AND NEW.status NOT IN ('in_review')
    AND (NEW.title,NEW.description,NEW.content_type,NEW.difficulty,NEW.topic_id)
      IS DISTINCT FROM (OLD.title,OLD.description,OLD.content_type,OLD.difficulty,OLD.topic_id) THEN
    RAISE EXCEPTION 'Return approved lesson to review before changing content' USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NOT ((OLD.status IN ('draft','rejected') AND NEW.status='in_review')
      OR (OLD.status='in_review' AND NEW.status IN ('approved','rejected'))
      OR (OLD.status='approved' AND NEW.status IN ('published','in_review'))
      OR (OLD.status='published' AND NEW.status='archived')) THEN
      RAISE EXCEPTION 'Invalid lesson status transition' USING ERRCODE='22023';
    END IF;
    IF NEW.status='approved' THEN
      IF OLD.status<>'in_review' OR auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Only an admin review can approve a lesson' USING ERRCODE='42501';
      END IF;
      NEW.reviewed_by:=auth.uid(); NEW.reviewed_at:=now();
    ELSIF NEW.status='rejected' AND (OLD.status<>'in_review' OR auth.uid() IS NULL) THEN
      RAISE EXCEPTION 'Only an admin review can reject a lesson' USING ERRCODE='42501';
    END IF;
  END IF;
  IF TG_OP='UPDATE' AND NEW.status='published' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF OLD.status<>'approved' OR auth.uid() IS NULL THEN
      RAISE EXCEPTION 'Manual approval required before publishing' USING ERRCODE='42501';
    END IF;
    NEW.published_by:=auth.uid();
    IF NEW.reviewed_by IS NULL
      OR NOT EXISTS (SELECT 1 FROM public.real_english_phrases p WHERE p.lesson_id=NEW.id)
      OR (NEW.generation_source='hybrid_ai' AND NOT EXISTS (
        SELECT 1 FROM public.real_english_source_references r WHERE r.lesson_id=NEW.id AND r.validation_status='eligible')) THEN
      RAISE EXCEPTION 'Lesson requires review, phrase and eligible source before publishing' USING ERRCODE='22023';
    END IF;
    NEW.published_at := now();
  END IF;
  IF TG_OP='UPDATE' THEN NEW.updated_at:=now(); END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_real_english_publish_guard() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER real_english_publish_guard BEFORE INSERT OR UPDATE ON public.real_english_lessons
  FOR EACH ROW EXECUTE FUNCTION public.englify_real_english_publish_guard();

CREATE FUNCTION public.englify_real_english_review_audit() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_actor uuid := auth.uid();
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status AND v_actor IS NOT NULL THEN
    INSERT INTO public.real_english_review_history
      (lesson_id,actor_id,action,previous_status,new_status,content_version,notes)
    VALUES (NEW.id,v_actor,CASE NEW.status
      WHEN 'in_review' THEN 'submit' WHEN 'approved' THEN 'approve'
      WHEN 'rejected' THEN 'reject' WHEN 'published' THEN 'publish'
      ELSE 'archive' END,OLD.status,NEW.status,NEW.content_version,coalesce(NEW.rejection_reason,''));
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_real_english_review_audit() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER real_english_review_audit AFTER UPDATE OF status ON public.real_english_lessons
  FOR EACH ROW EXECUTE FUNCTION public.englify_real_english_review_audit();

-- Published content remains stable for learners who have completed it.
CREATE FUNCTION public.englify_real_english_content_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_lesson_id uuid; v_old_lesson_id uuid;
BEGIN
  IF TG_TABLE_NAME='real_english_phrases' OR TG_TABLE_NAME='real_english_source_references' THEN
    IF TG_OP='DELETE' THEN v_lesson_id := OLD.lesson_id;
    ELSE v_lesson_id := NEW.lesson_id; END IF;
    IF TG_OP='UPDATE' THEN v_old_lesson_id := OLD.lesson_id; END IF;
  ELSIF TG_TABLE_NAME='real_english_dialogues' THEN
    IF TG_OP='DELETE' THEN v_lesson_id := OLD.lesson_id;
    ELSE v_lesson_id := NEW.lesson_id; END IF;
    IF TG_OP='UPDATE' THEN v_old_lesson_id := OLD.lesson_id; END IF;
  ELSE
    SELECT lesson_id INTO v_lesson_id FROM public.real_english_dialogues
      WHERE id=CASE WHEN TG_OP='DELETE' THEN OLD.dialogue_id ELSE NEW.dialogue_id END;
    IF TG_OP='UPDATE' THEN
      SELECT lesson_id INTO v_old_lesson_id FROM public.real_english_dialogues WHERE id=OLD.dialogue_id;
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM public.real_english_lessons WHERE id IN (v_lesson_id,v_old_lesson_id) AND status IN ('approved','published')) THEN
    RAISE EXCEPTION 'Return approved lesson to review before changing content' USING ERRCODE='42501';
  END IF;
  RETURN coalesce(NEW,OLD);
END $$;
REVOKE ALL ON FUNCTION public.englify_real_english_content_guard() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER real_english_phrases_guard BEFORE INSERT OR UPDATE OR DELETE ON public.real_english_phrases
  FOR EACH ROW EXECUTE FUNCTION public.englify_real_english_content_guard();
CREATE TRIGGER real_english_dialogues_guard BEFORE INSERT OR UPDATE OR DELETE ON public.real_english_dialogues
  FOR EACH ROW EXECUTE FUNCTION public.englify_real_english_content_guard();
CREATE TRIGGER real_english_lines_guard BEFORE INSERT OR UPDATE OR DELETE ON public.real_english_dialogue_lines
  FOR EACH ROW EXECUTE FUNCTION public.englify_real_english_content_guard();
CREATE TRIGGER real_english_refs_guard BEFORE INSERT OR UPDATE OR DELETE ON public.real_english_source_references
  FOR EACH ROW EXECUTE FUNCTION public.englify_real_english_content_guard();

-- One short transaction claims each slot; external requests happen after commit.
CREATE FUNCTION public.englify_claim_real_english_job(p_key text, p_scheduled_for timestamptz)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_settings public.real_english_generation_settings%ROWTYPE;
  v_job public.real_english_generation_jobs%ROWTYPE;
  v_today date := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
BEGIN
  SELECT * INTO v_settings FROM public.real_english_generation_settings WHERE id=true FOR UPDATE;
  IF NOT v_settings.ai_generation_enabled OR NOT v_settings.source_import_enabled THEN
    RAISE EXCEPTION 'Generation disabled' USING ERRCODE='42501';
  END IF;
  IF p_key IS NULL OR length(p_key) NOT BETWEEN 8 AND 160 OR p_scheduled_for IS NULL THEN
    RAISE EXCEPTION 'Invalid generation job' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_job FROM public.real_english_generation_jobs WHERE idempotency_key=p_key FOR UPDATE;
  IF FOUND THEN
    IF v_job.status='failed' OR (v_job.status='running' AND v_job.lease_expires_at < now()) THEN
      IF (SELECT coalesce(sum(attempt_count),0) FROM public.real_english_generation_jobs
          WHERE (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=v_today) >= v_settings.maximum_daily_requests THEN
        RAISE EXCEPTION 'Daily generation request limit reached' USING ERRCODE='P0001';
      END IF;
      UPDATE public.real_english_generation_jobs SET status='running',started_at=now(),lease_expires_at=now()+interval '2 minutes',
        attempt_count=attempt_count+1,error_code=NULL,error_message=NULL WHERE id=v_job.id;
      RETURN v_job.id;
    END IF;
    RETURN NULL;
  END IF;
  IF (SELECT coalesce(sum(attempt_count),0) FROM public.real_english_generation_jobs
      WHERE (created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=v_today) >= v_settings.maximum_daily_requests THEN
    RAISE EXCEPTION 'Daily generation request limit reached' USING ERRCODE='P0001';
  END IF;
  INSERT INTO public.real_english_generation_jobs
    (idempotency_key,scheduled_for,status,started_at,lease_expires_at)
  VALUES (p_key,p_scheduled_for,'running',now(),now()+interval '2 minutes') RETURNING id INTO v_job.id;
  RETURN v_job.id;
END $$;
REVOKE ALL ON FUNCTION public.englify_claim_real_english_job(text,timestamptz) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.englify_claim_real_english_job(text,timestamptz) TO service_role;

-- Atomic draft insertion: no half-written lesson, references, or dialogue.
CREATE FUNCTION public.englify_store_real_english_draft(p_job_id uuid,p_topic_id uuid,p_content jsonb,p_source jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_id uuid; v_dialogue_id uuid; v_line jsonb; v_index integer := 0;
  v_source_hash text; v_lesson_hash text; v_phrase_hash text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.real_english_generation_jobs
    WHERE id=p_job_id AND status='running' AND lease_expires_at>now() FOR UPDATE) THEN
    RAISE EXCEPTION 'Generation lease expired' USING ERRCODE='42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.real_english_topics WHERE id=p_topic_id AND is_active) THEN
    RAISE EXCEPTION 'Topic unavailable' USING ERRCODE='22023';
  END IF;
  IF p_content->>'title' IS NULL OR p_content->>'expression' IS NULL
    OR p_content->>'meaningVi' IS NULL OR coalesce(jsonb_typeof(p_content->'dialogue'),'')<>'array'
    OR coalesce(jsonb_array_length(p_content->'dialogue'),0)<2
    OR coalesce(p_source->>'validationStatus','')<>'eligible' THEN
    RAISE EXCEPTION 'Incomplete lesson or unverified reference' USING ERRCODE='22023';
  END IF;
  v_lesson_hash := pg_catalog.encode(extensions.digest(lower(btrim(p_content->>'expression')) || ':' || p_topic_id::text,'sha256'),'hex');
  v_phrase_hash := pg_catalog.encode(extensions.digest(lower(pg_catalog.regexp_replace(btrim(p_content->>'expression'),'[^[:alnum:]]+','','g')),'sha256'),'hex');
  v_source_hash := pg_catalog.encode(extensions.digest((p_source->>'englishId') || ':' || (p_source->>'vietnameseId'),'sha256'),'hex');
  INSERT INTO public.real_english_lessons
    (topic_id,title,description,content_type,difficulty,status,generation_source,normalized_hash,validation_warnings)
  VALUES (p_topic_id,p_content->>'title',p_content->>'description',p_content->>'contentType',
    p_content->>'difficulty','in_review','hybrid_ai',v_lesson_hash,
    coalesce(p_content->'enrichment'->'warnings','[]'::jsonb)) RETURNING id INTO v_id;
  INSERT INTO public.real_english_phrases
    (lesson_id,english_text,vietnamese_translation,mymemory_candidate_vi,ipa,part_of_speech,formality,usage_context,normalized_hash)
  VALUES (v_id,p_content->>'expression',p_content->>'meaningVi',
    nullif(p_content->'enrichment'->>'myMemoryTranslation',''),
    nullif(p_content->'enrichment'->>'ipa',''),nullif(p_content->'enrichment'->>'partOfSpeech',''),
    p_content->>'formality',
    p_content->>'usageContext',v_phrase_hash);
  INSERT INTO public.real_english_dialogues (lesson_id,title,context)
  VALUES (v_id,p_content->>'title',p_content->>'usageContext') RETURNING id INTO v_dialogue_id;
  FOR v_line IN SELECT value FROM jsonb_array_elements(p_content->'dialogue') LOOP
    INSERT INTO public.real_english_dialogue_lines
      (dialogue_id,speaker,english_text,vietnamese_translation,sort_order)
    VALUES (v_dialogue_id,v_line->>'speaker',v_line->>'englishText',v_line->>'vietnameseTranslation',v_index);
    v_index := v_index+1;
  END LOOP;
  INSERT INTO public.real_english_source_references
    (lesson_id,source_sentence_id,translation_sentence_id,english_text,vietnamese_text,
     english_contributor,vietnamese_contributor,english_license,vietnamese_license,
     source_url,translation_url,attribution_text,content_hash,validation_status)
  VALUES (v_id,(p_source->>'englishId')::bigint,(p_source->>'vietnameseId')::bigint,
    p_source->>'englishText',p_source->>'vietnameseText',p_source->>'englishContributor',
    p_source->>'vietnameseContributor',p_source->>'englishLicense',p_source->>'vietnameseLicense',
    p_source->>'sourceUrl',p_source->>'translationUrl',
    concat('Tatoeba: ',p_source->>'englishContributor',' / ',p_source->>'vietnameseContributor',
      ' (',p_source->>'englishLicense',' / ',p_source->>'vietnameseLicense',')'),
    v_source_hash,'eligible');
  UPDATE public.real_english_generation_jobs SET status='completed',completed_at=now(),
    generated_count=generated_count+1,lease_expires_at=NULL WHERE id=p_job_id;
  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.englify_store_real_english_draft(uuid,uuid,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.englify_store_real_english_draft(uuid,uuid,jsonb,jsonb) TO service_role;
