-- Keep lesson IDs and review history. Normalize new AI drafts into the editorial lifecycle.
ALTER TABLE public.real_english_lessons
  DROP CONSTRAINT real_english_lessons_status_check;
ALTER TABLE public.real_english_lessons
  ADD CONSTRAINT real_english_lessons_status_check CHECK (status IN
    ('draft','in_review','pending_review','needs_revision','approved','published','rejected','archived','publish_failed'));
ALTER TABLE public.real_english_lessons ADD COLUMN review_notes text NOT NULL DEFAULT '';
ALTER TABLE public.real_english_phrases ADD COLUMN is_active boolean NOT NULL DEFAULT true;
DROP POLICY phrases_read ON public.real_english_phrases;
CREATE POLICY phrases_read ON public.real_english_phrases FOR SELECT TO authenticated USING (
  (is_active AND EXISTS (SELECT 1 FROM public.real_english_lessons l
    WHERE l.id=lesson_id AND l.status='published')) OR public.englify_is_admin());

ALTER TABLE public.real_english_review_history
  DROP CONSTRAINT real_english_review_history_action_check;
ALTER TABLE public.real_english_review_history
  ADD CONSTRAINT real_english_review_history_action_check CHECK (action IN
    ('submit','approve','reject','publish','archive','restore','request_revision','publish_failed'));

CREATE FUNCTION public.englify_real_english_normalize_review() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF NEW.status='in_review' THEN NEW.status:='pending_review'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_real_english_normalize_review() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER real_english_normalize_review BEFORE INSERT OR UPDATE ON public.real_english_lessons
  FOR EACH ROW EXECUTE FUNCTION public.englify_real_english_normalize_review();

UPDATE public.real_english_lessons SET status='pending_review' WHERE status='in_review';

CREATE OR REPLACE FUNCTION public.englify_real_english_publish_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF TG_OP='INSERT' AND NEW.status='published' THEN
    RAISE EXCEPTION 'Manual approval required before publishing' USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' AND OLD.status IN ('approved','published')
    AND NEW.status NOT IN ('pending_review')
    AND (NEW.title,NEW.description,NEW.content_type,NEW.difficulty,NEW.topic_id)
      IS DISTINCT FROM (OLD.title,OLD.description,OLD.content_type,OLD.difficulty,OLD.topic_id) THEN
    RAISE EXCEPTION 'Return approved lesson to review before changing content' USING ERRCODE='42501';
  END IF;
  IF TG_OP='UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NOT ((OLD.status IN ('draft','in_review','needs_revision','rejected') AND NEW.status='pending_review')
      OR (OLD.status='pending_review' AND NEW.status IN ('approved','needs_revision','rejected','archived'))
      OR (OLD.status='approved' AND NEW.status IN ('published','pending_review','archived','publish_failed'))
      OR (OLD.status='publish_failed' AND NEW.status IN ('approved','pending_review','archived'))
      OR (OLD.status='published' AND NEW.status='archived')
      OR (OLD.status='archived' AND NEW.status='pending_review')
      OR (OLD.status IN ('draft','needs_revision','rejected') AND NEW.status='archived')) THEN
      RAISE EXCEPTION 'Invalid lesson status transition' USING ERRCODE='22023';
    END IF;
    IF NEW.status='approved' THEN
      IF OLD.status NOT IN ('pending_review','publish_failed') OR auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Only an admin review can approve a lesson' USING ERRCODE='42501';
      END IF;
      NEW.reviewed_by:=auth.uid(); NEW.reviewed_at:=now();
    ELSIF NEW.status IN ('rejected','needs_revision') AND (OLD.status<>'pending_review' OR auth.uid() IS NULL) THEN
      RAISE EXCEPTION 'Only an admin review can return a lesson' USING ERRCODE='42501';
    END IF;
  END IF;
  IF TG_OP='UPDATE' AND NEW.status='published' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF OLD.status<>'approved' OR auth.uid() IS NULL THEN
      RAISE EXCEPTION 'Manual approval required before publishing' USING ERRCODE='42501';
    END IF;
    IF nullif(btrim(NEW.title),'') IS NULL OR nullif(btrim(NEW.description),'') IS NULL
      OR NEW.difficulty NOT IN ('A1','A2','B1','B2','C1','C2')
      OR NEW.reviewed_by IS NULL
      OR NOT EXISTS (SELECT 1 FROM public.real_english_phrases p WHERE p.lesson_id=NEW.id AND p.is_active
        AND nullif(btrim(p.english_text),'') IS NOT NULL AND nullif(btrim(p.vietnamese_translation),'') IS NOT NULL)
      OR NOT EXISTS (SELECT 1 FROM public.real_english_dialogues d
        JOIN public.real_english_dialogue_lines line ON line.dialogue_id=d.id
        WHERE d.lesson_id=NEW.id GROUP BY d.id HAVING count(*)>=2)
      OR (NEW.generation_source='hybrid_ai' AND NOT EXISTS (
        SELECT 1 FROM public.real_english_source_references r WHERE r.lesson_id=NEW.id
          AND r.validation_status='eligible' AND r.provider='tatoeba'
          AND r.source_url ~ '^https://api[.]tatoeba[.]org/v1/sentences/[0-9]+$'
          AND r.translation_url ~ '^https://api[.]tatoeba[.]org/v1/sentences/[0-9]+$'
          AND nullif(btrim(r.attribution_text),'') IS NOT NULL)) THEN
      RAISE EXCEPTION 'Lesson needs title, description, expressions, dialogue and eligible source before publishing' USING ERRCODE='22023';
    END IF;
    NEW.published_by:=auth.uid(); NEW.published_at:=now();
  END IF;
  IF TG_OP='UPDATE' THEN NEW.updated_at:=now(); END IF;
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.englify_real_english_review_audit() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_actor uuid := auth.uid();
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status AND v_actor IS NOT NULL THEN
    INSERT INTO public.real_english_review_history
      (lesson_id,actor_id,action,previous_status,new_status,content_version,notes)
    VALUES (NEW.id,v_actor,CASE NEW.status
      WHEN 'pending_review' THEN CASE WHEN OLD.status='archived' THEN 'restore' ELSE 'submit' END
      WHEN 'approved' THEN 'approve' WHEN 'needs_revision' THEN 'request_revision'
      WHEN 'rejected' THEN 'reject' WHEN 'published' THEN 'publish'
      WHEN 'publish_failed' THEN 'publish_failed' ELSE 'archive' END,
      OLD.status,NEW.status,NEW.content_version,coalesce(NEW.review_notes,''));
  END IF;
  RETURN NEW;
END $$;

CREATE FUNCTION public.englify_review_real_english_lesson(p_lesson_id uuid,p_action text,p_note text DEFAULT '')
RETURNS public.real_english_lessons LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_lesson public.real_english_lessons%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT public.englify_is_admin() THEN
    RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';
  END IF;
  IF p_lesson_id IS NULL OR p_action NOT IN
    ('submit','approve','approve_publish','publish','request_revision','reject','archive','restore') THEN
    RAISE EXCEPTION 'Invalid review action' USING ERRCODE='22023';
  END IF;
  IF p_action IN ('request_revision','reject') AND nullif(btrim(coalesce(p_note,'')),'') IS NULL THEN
    RAISE EXCEPTION 'A review reason is required' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_lesson FROM public.real_english_lessons WHERE id=p_lesson_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lesson not found' USING ERRCODE='P0002'; END IF;
  IF p_action='approve_publish' THEN
    IF v_lesson.status<>'pending_review' THEN RAISE EXCEPTION 'Lesson must await review' USING ERRCODE='22023'; END IF;
    UPDATE public.real_english_lessons SET status='approved',review_notes=left(coalesce(p_note,''),2000)
      WHERE id=p_lesson_id;
    UPDATE public.real_english_lessons SET status='published' WHERE id=p_lesson_id RETURNING * INTO v_lesson;
  ELSE
    UPDATE public.real_english_lessons SET
      status=CASE p_action
        WHEN 'submit' THEN 'pending_review' WHEN 'restore' THEN 'pending_review'
        WHEN 'approve' THEN 'approved' WHEN 'publish' THEN 'published'
        WHEN 'request_revision' THEN 'needs_revision' WHEN 'reject' THEN 'rejected'
        ELSE 'archived' END,
      review_notes=CASE WHEN p_action IN ('approve','request_revision','reject')
        THEN left(coalesce(p_note,''),2000) ELSE review_notes END,
      rejection_reason=CASE WHEN p_action='reject' THEN left(coalesce(p_note,''),2000) ELSE NULL END
      WHERE id=p_lesson_id RETURNING * INTO v_lesson;
  END IF;
  RETURN v_lesson;
END $$;
REVOKE ALL ON FUNCTION public.englify_review_real_english_lesson(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_review_real_english_lesson(uuid,text,text) TO authenticated;

-- Editor changes are atomic and keep removed expressions for audit/history. A
-- previously approved lesson returns to review before content changes.
CREATE FUNCTION public.englify_save_real_english_lesson(
  p_lesson_id uuid,p_title text,p_description text,p_phrases jsonb)
RETURNS public.real_english_lessons LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_lesson public.real_english_lessons%ROWTYPE; v_phrase jsonb;
  v_id uuid; v_english text; v_vi text; v_formality text; v_hash text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.englify_is_admin() THEN
    RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';
  END IF;
  IF nullif(btrim(coalesce(p_title,'')),'') IS NULL OR length(p_title)>160
    OR length(btrim(coalesce(p_description,'')))<5 OR length(p_description)>5000
    OR coalesce(jsonb_typeof(p_phrases),'')<>'array' THEN
    RAISE EXCEPTION 'Invalid lesson content' USING ERRCODE='22023';
  END IF;
  IF jsonb_array_length(p_phrases)>20 THEN RAISE EXCEPTION 'Too many expressions' USING ERRCODE='22023'; END IF;
  SELECT * INTO v_lesson FROM public.real_english_lessons WHERE id=p_lesson_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lesson not found' USING ERRCODE='P0002'; END IF;
  IF v_lesson.status NOT IN ('draft','pending_review','needs_revision','rejected','approved') THEN
    RAISE EXCEPTION 'Lesson cannot be edited in this status' USING ERRCODE='42501';
  END IF;
  UPDATE public.real_english_lessons SET title=btrim(p_title),description=btrim(p_description),
    status=CASE WHEN status='approved' THEN 'pending_review' ELSE status END,
    content_version=content_version+1 WHERE id=p_lesson_id RETURNING * INTO v_lesson;
  FOR v_phrase IN SELECT value FROM jsonb_array_elements(p_phrases) LOOP
    IF jsonb_typeof(v_phrase)<>'object' THEN RAISE EXCEPTION 'Invalid expression' USING ERRCODE='22023'; END IF;
    v_english:=btrim(coalesce(v_phrase->>'englishText',''));
    v_vi:=btrim(coalesce(v_phrase->>'vietnameseTranslation',''));
    v_formality:=coalesce(v_phrase->>'formality','neutral');
    IF length(v_english) NOT BETWEEN 1 AND 500 OR length(v_vi) NOT BETWEEN 1 AND 500
      OR v_formality NOT IN ('informal','neutral','formal') THEN
      RAISE EXCEPTION 'Invalid expression or translation' USING ERRCODE='22023';
    END IF;
    v_hash:=pg_catalog.encode(extensions.digest(lower(pg_catalog.regexp_replace(v_english,'[^[:alnum:]]+','','g')),'sha256'),'hex');
    IF nullif(v_phrase->>'id','') IS NULL THEN
      INSERT INTO public.real_english_phrases
        (lesson_id,english_text,vietnamese_translation,formality,usage_context,normalized_hash,is_active)
      VALUES (p_lesson_id,v_english,v_vi,v_formality,left(coalesce(v_phrase->>'usageContext',''),2000),v_hash,
        coalesce((v_phrase->>'isActive')::boolean,true));
    ELSE
      BEGIN v_id:=(v_phrase->>'id')::uuid;
      EXCEPTION WHEN invalid_text_representation THEN RAISE EXCEPTION 'Invalid expression ID' USING ERRCODE='22023'; END;
      UPDATE public.real_english_phrases SET english_text=v_english,vietnamese_translation=v_vi,
        formality=v_formality,usage_context=left(coalesce(v_phrase->>'usageContext',''),2000),
        normalized_hash=v_hash,is_active=coalesce((v_phrase->>'isActive')::boolean,true),updated_at=now()
      WHERE id=v_id AND lesson_id=p_lesson_id;
      IF NOT FOUND THEN RAISE EXCEPTION 'Expression not found in lesson' USING ERRCODE='P0002'; END IF;
    END IF;
  END LOOP;
  RETURN v_lesson;
END $$;
REVOKE ALL ON FUNCTION public.englify_save_real_english_lesson(uuid,text,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_save_real_english_lesson(uuid,text,text,jsonb) TO authenticated;

-- A daily batch counts successfully stored lessons, not provider calls. Jobs remain the
-- idempotency ledger; this table is an inspectable daily summary for the editor.
CREATE TABLE public.real_english_generation_batches (
  generation_date date PRIMARY KEY,
  target_count integer NOT NULL CHECK (target_count BETWEEN 0 AND 20),
  success_count integer NOT NULL DEFAULT 0 CHECK (success_count >= 0),
  failure_count integer NOT NULL DEFAULT 0 CHECK (failure_count >= 0),
  pending_count integer NOT NULL DEFAULT 0 CHECK (pending_count >= 0),
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  latest_error text,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.real_english_generation_batches ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.real_english_generation_batches TO authenticated,service_role;
CREATE POLICY real_english_batches_admin_read ON public.real_english_generation_batches
  FOR SELECT TO authenticated USING (public.englify_is_admin());

CREATE FUNCTION public.englify_refresh_real_english_batch(p_date date) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_target integer;
BEGIN
  SELECT daily_generation_target INTO v_target FROM public.real_english_generation_settings WHERE id=true;
  INSERT INTO public.real_english_generation_batches (generation_date,target_count)
  VALUES (p_date,coalesce(v_target,5)) ON CONFLICT (generation_date) DO NOTHING;
  UPDATE public.real_english_generation_batches b SET
    target_count=coalesce(v_target,5),
    success_count=(SELECT coalesce(sum(j.generated_count),0)::integer FROM public.real_english_generation_jobs j
      WHERE (j.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date AND j.status='completed'),
    failure_count=(SELECT count(*)::integer FROM public.real_english_generation_jobs j
      WHERE (j.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date AND j.status IN ('failed','quota_blocked')),
    pending_count=(SELECT count(*)::integer FROM public.real_english_generation_jobs j
      WHERE (j.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date AND j.status IN ('queued','running')),
    latest_error=(SELECT j.error_message FROM public.real_english_generation_jobs j
      WHERE (j.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date
        AND j.error_message IS NOT NULL ORDER BY j.created_at DESC LIMIT 1),
    completed_at=CASE WHEN (SELECT coalesce(sum(j.generated_count),0) FROM public.real_english_generation_jobs j
      WHERE (j.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date AND j.status='completed') >= coalesce(v_target,5)
      THEN coalesce(b.completed_at,now()) ELSE NULL END,
    updated_at=now()
  WHERE b.generation_date=p_date;
END $$;
REVOKE ALL ON FUNCTION public.englify_refresh_real_english_batch(date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.englify_refresh_real_english_batch(date) TO service_role;

CREATE FUNCTION public.englify_real_english_batch_job_trigger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.englify_refresh_real_english_batch((NEW.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date);
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_real_english_batch_job_trigger() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER real_english_batch_job AFTER INSERT OR UPDATE OF status,generated_count,error_message
  ON public.real_english_generation_jobs FOR EACH ROW
  EXECUTE FUNCTION public.englify_real_english_batch_job_trigger();

SELECT public.englify_refresh_real_english_batch((now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date);
