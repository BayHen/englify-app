-- Journey V2.1: versioned chapters, explicit prerequisites and checkpoint-ready lessons.
-- Existing course, unit, lesson, progress, attempt and XP identifiers remain unchanged.

CREATE TABLE public.journey_curriculum_versions (
  version integer PRIMARY KEY CHECK (version > 0),
  title text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 120),
  status text NOT NULL CHECK (status IN ('draft','active','retired')),
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((status = 'active') = (published_at IS NOT NULL))
);
CREATE UNIQUE INDEX journey_curriculum_one_active
  ON public.journey_curriculum_versions ((true)) WHERE status = 'active';
INSERT INTO public.journey_curriculum_versions(version,title,status,published_at)
VALUES (1,'Legacy-compatible curriculum','active',transaction_timestamp());

ALTER TABLE public.courses
  ADD COLUMN cefr_level text,
  ADD COLUMN curriculum_version integer NOT NULL DEFAULT 1
    REFERENCES public.journey_curriculum_versions(version),
  ADD CONSTRAINT courses_cefr_level_check
    CHECK (cefr_level IS NULL OR cefr_level IN ('A1','A2','B1','B2','C1','C2'));

CREATE TABLE public.journey_chapters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  slug text NOT NULL CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  title text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 120),
  description text NOT NULL DEFAULT '',
  position integer NOT NULL CHECK (position > 0),
  curriculum_version integer NOT NULL DEFAULT 1
    REFERENCES public.journey_curriculum_versions(version),
  is_published boolean NOT NULL DEFAULT false,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(course_id,slug), UNIQUE(course_id,position)
);

ALTER TABLE public.learning_units
  ADD COLUMN chapter_id uuid REFERENCES public.journey_chapters(id) ON DELETE SET NULL,
  ADD COLUMN is_required boolean NOT NULL DEFAULT true,
  ADD COLUMN curriculum_version integer NOT NULL DEFAULT 1
    REFERENCES public.journey_curriculum_versions(version);
CREATE INDEX learning_units_chapter_position_idx
  ON public.learning_units(chapter_id,position) WHERE archived_at IS NULL;

ALTER TABLE public.lessons
  ADD COLUMN is_required boolean NOT NULL DEFAULT true,
  ADD COLUMN estimated_minutes smallint NOT NULL DEFAULT 10
    CHECK (estimated_minutes BETWEEN 1 AND 180),
  ADD COLUMN lesson_kind text NOT NULL DEFAULT 'lesson'
    CHECK (lesson_kind IN ('lesson','checkpoint')),
  ADD COLUMN checkpoint_pass_percent smallint NOT NULL DEFAULT 70
    CHECK (checkpoint_pass_percent = 70),
  ADD COLUMN curriculum_version integer NOT NULL DEFAULT 1
    REFERENCES public.journey_curriculum_versions(version);

CREATE TABLE public.journey_lesson_prerequisites (
  lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  prerequisite_lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(lesson_id,prerequisite_lesson_id),
  CHECK (lesson_id <> prerequisite_lesson_id)
);
CREATE INDEX journey_prerequisites_reverse_idx
  ON public.journey_lesson_prerequisites(prerequisite_lesson_id,lesson_id);

-- Freeze the legacy sequential rule as explicit relationships without changing IDs.
INSERT INTO public.journey_lesson_prerequisites(lesson_id,prerequisite_lesson_id)
SELECT id,previous_id FROM (
  SELECT l.id,lag(l.id) OVER (PARTITION BY l.course_id ORDER BY u.position,l.position,l.id) previous_id
  FROM public.lessons l
  JOIN public.learning_units u ON u.id=l.unit_id
  WHERE l.is_published AND l.archived_at IS NULL
) ordered WHERE previous_id IS NOT NULL
ON CONFLICT DO NOTHING;

CREATE FUNCTION public.englify_journey_prerequisite_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE lesson_course uuid; prerequisite_course uuid;
BEGIN
  SELECT course_id INTO lesson_course FROM public.lessons WHERE id=NEW.lesson_id;
  SELECT course_id INTO prerequisite_course FROM public.lessons WHERE id=NEW.prerequisite_lesson_id;
  IF lesson_course IS NULL OR prerequisite_course IS NULL OR lesson_course<>prerequisite_course THEN
    RAISE EXCEPTION 'Journey prerequisites must belong to the same course' USING ERRCODE='23514';
  END IF;
  IF EXISTS (
    WITH RECURSIVE ancestors(id) AS (
      SELECT NEW.prerequisite_lesson_id
      UNION
      SELECT p.prerequisite_lesson_id FROM public.journey_lesson_prerequisites p
      JOIN ancestors a ON a.id=p.lesson_id
    ) SELECT 1 FROM ancestors WHERE id=NEW.lesson_id
  ) THEN RAISE EXCEPTION 'Journey prerequisite cycle detected' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_journey_prerequisite_guard() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER journey_prerequisite_guard BEFORE INSERT OR UPDATE
  ON public.journey_lesson_prerequisites FOR EACH ROW
  EXECUTE FUNCTION public.englify_journey_prerequisite_guard();

ALTER TABLE public.journey_curriculum_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_lesson_prerequisites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.journey_curriculum_versions,public.journey_chapters,
  public.journey_lesson_prerequisites FROM anon,authenticated;
GRANT ALL ON public.journey_curriculum_versions,public.journey_chapters,
  public.journey_lesson_prerequisites TO service_role;
GRANT SELECT ON public.journey_curriculum_versions,public.journey_chapters TO authenticated;
CREATE POLICY journey_curriculum_read ON public.journey_curriculum_versions FOR SELECT TO authenticated
  USING(status='active');
CREATE POLICY journey_chapters_read ON public.journey_chapters FOR SELECT TO authenticated
  USING(is_published AND archived_at IS NULL);
GRANT INSERT,UPDATE,DELETE ON public.journey_chapters TO authenticated;
CREATE POLICY journey_chapters_admin_write ON public.journey_chapters FOR ALL TO authenticated
  USING(public.englify_is_admin()) WITH CHECK(public.englify_is_admin());

CREATE FUNCTION public.englify_admin_set_journey_prerequisites(p_lesson uuid,p_required uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE before_data jsonb; after_data jsonb;
BEGIN
  IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
  IF p_lesson IS NULL OR p_required IS NULL OR cardinality(p_required)>20 OR cardinality(p_required)<>cardinality(ARRAY(SELECT DISTINCT unnest(p_required))) THEN
    RAISE EXCEPTION 'Invalid prerequisite list' USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.lessons WHERE id=p_lesson) THEN RAISE EXCEPTION 'Lesson not found' USING ERRCODE='P0002'; END IF;
  SELECT coalesce(jsonb_agg(prerequisite_lesson_id ORDER BY prerequisite_lesson_id),'[]'::jsonb) INTO before_data
    FROM public.journey_lesson_prerequisites WHERE lesson_id=p_lesson;
  DELETE FROM public.journey_lesson_prerequisites WHERE lesson_id=p_lesson;
  INSERT INTO public.journey_lesson_prerequisites(lesson_id,prerequisite_lesson_id)
    SELECT p_lesson,id FROM unnest(p_required) id;
  SELECT coalesce(jsonb_agg(prerequisite_lesson_id ORDER BY prerequisite_lesson_id),'[]'::jsonb) INTO after_data
    FROM public.journey_lesson_prerequisites WHERE lesson_id=p_lesson;
  INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data)
    VALUES(auth.uid(),'update','journey-prerequisites',p_lesson,before_data,after_data);
  RETURN jsonb_build_object('lesson_id',p_lesson,'prerequisites',after_data);
END $$;
REVOKE ALL ON FUNCTION public.englify_admin_set_journey_prerequisites(uuid,uuid[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_admin_set_journey_prerequisites(uuid,uuid[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.englify_lesson_state(p_lesson_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT CASE
    WHEN p.status IN ('in_progress','completed','mastered') THEN p.status
    WHEN NOT c.is_published OR c.archived_at IS NOT NULL OR NOT u.is_published OR u.archived_at IS NOT NULL
      OR NOT l.is_published OR l.archived_at IS NOT NULL
      OR (u.chapter_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.journey_chapters ch WHERE ch.id=u.chapter_id
          AND ch.is_published AND ch.archived_at IS NULL)) THEN NULL
    WHEN NOT EXISTS (
      SELECT 1 FROM public.journey_lesson_prerequisites r
      LEFT JOIN public.learning_progress required_progress
        ON required_progress.lesson_id=r.prerequisite_lesson_id AND required_progress.user_id=auth.uid()
      WHERE r.lesson_id=l.id AND coalesce(required_progress.status,'') NOT IN ('completed','mastered')
    ) THEN 'available' ELSE 'locked' END
  FROM public.lessons l
  JOIN public.learning_units u ON u.id=l.unit_id
  JOIN public.courses c ON c.id=l.course_id AND c.id=u.course_id
  LEFT JOIN public.learning_progress p ON p.lesson_id=l.id AND p.user_id=auth.uid()
  WHERE l.id=p_lesson_id
$$;

CREATE FUNCTION public.englify_journey_lesson_node(p_lesson_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT jsonb_build_object(
    'id',l.id,'title',l.title,'objective',l.objective,'position',l.position,
    'state',public.englify_lesson_state(l.id),'kind',l.lesson_kind,
    'is_required',l.is_required,'estimated_minutes',l.estimated_minutes,
    'exercise_count',(SELECT count(*) FROM public.quiz_questions q WHERE q.lesson_id=l.id AND q.is_published AND q.archived_at IS NULL),
    'xp_reward',l.xp_reward,'passing_percent',l.checkpoint_pass_percent,
    'prerequisites',coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id',required.id,'title',required.title,'completed',coalesce(progress.status,'') IN ('completed','mastered'))
      ORDER BY required.position,required.id)
      FROM public.journey_lesson_prerequisites r
      JOIN public.lessons required ON required.id=r.prerequisite_lesson_id
      LEFT JOIN public.learning_progress progress ON progress.lesson_id=required.id AND progress.user_id=auth.uid()
      WHERE r.lesson_id=l.id),'[]'::jsonb),
    'locked_reason',CASE WHEN public.englify_lesson_state(l.id)='locked' THEN
      coalesce((SELECT 'Complete '||string_agg(required.title,', ' ORDER BY required.position)
        FROM public.journey_lesson_prerequisites r JOIN public.lessons required ON required.id=r.prerequisite_lesson_id
        LEFT JOIN public.learning_progress progress ON progress.lesson_id=required.id AND progress.user_id=auth.uid()
        WHERE r.lesson_id=l.id AND coalesce(progress.status,'') NOT IN ('completed','mastered')),
        'Complete the required lessons first') ELSE NULL END)
  FROM public.lessons l WHERE l.id=p_lesson_id
$$;
REVOKE ALL ON FUNCTION public.englify_journey_lesson_node(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.englify_journey()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'title',c.title,'cefr_level',c.cefr_level,'curriculum_version',c.curriculum_version,
    'continue_lesson',(SELECT public.englify_journey_lesson_node(candidate.id) FROM public.lessons candidate
      JOIN public.learning_units cu ON cu.id=candidate.unit_id
      WHERE candidate.course_id=c.id AND candidate.is_published AND candidate.archived_at IS NULL
        AND cu.is_published AND cu.archived_at IS NULL AND public.englify_lesson_state(candidate.id)<>'locked'
      ORDER BY CASE public.englify_lesson_state(candidate.id)
        WHEN 'in_progress' THEN 0 WHEN 'available' THEN CASE candidate.lesson_kind WHEN 'lesson' THEN 1 ELSE 2 END
        WHEN 'completed' THEN 3 ELSE 4 END,cu.position,candidate.position,candidate.id LIMIT 1),
    'chapters',coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id',chapter.id,'title',chapter.title,'description',chapter.description,'position',chapter.position,
      'compatibility',chapter.compatibility,
      'units',coalesce((SELECT jsonb_agg(jsonb_build_object(
        'id',u.id,'title',u.title,'position',u.position,'is_required',u.is_required,
        'required_lessons',(SELECT count(*) FROM public.lessons x WHERE x.unit_id=u.id AND x.is_published AND x.archived_at IS NULL AND x.is_required),
        'completed_required_lessons',(SELECT count(*) FROM public.lessons x WHERE x.unit_id=u.id AND x.is_published AND x.archived_at IS NULL AND x.is_required AND public.englify_lesson_state(x.id) IN ('completed','mastered')),
        'progress_percent',coalesce((SELECT round(100.0*count(*) FILTER(WHERE public.englify_lesson_state(x.id) IN ('completed','mastered'))/nullif(count(*),0))::integer FROM public.lessons x WHERE x.unit_id=u.id AND x.is_published AND x.archived_at IS NULL AND x.is_required),0),
        'lessons',coalesce((SELECT jsonb_agg(public.englify_journey_lesson_node(l.id) ORDER BY l.position,l.id) FROM public.lessons l WHERE l.unit_id=u.id AND l.is_published AND l.archived_at IS NULL),'[]'::jsonb)
      ) ORDER BY u.position,u.id) FROM public.learning_units u
      WHERE u.course_id=c.id AND u.is_published AND u.archived_at IS NULL
        AND ((chapter.compatibility AND u.chapter_id IS NULL) OR u.chapter_id=chapter.id)),'[]'::jsonb)
    ) ORDER BY chapter.position,chapter.id) FROM (
      SELECT ch.id,ch.title,ch.description,ch.position,false compatibility FROM public.journey_chapters ch
        WHERE ch.course_id=c.id AND ch.is_published AND ch.archived_at IS NULL
      UNION ALL
      SELECT pg_catalog.md5('journey-legacy-chapter:'||c.id::text)::uuid,'Existing learning path',
        'Compatibility group for units created before Journey V2.1',2147483647,true
        WHERE EXISTS(SELECT 1 FROM public.learning_units legacy WHERE legacy.course_id=c.id AND legacy.chapter_id IS NULL AND legacy.is_published AND legacy.archived_at IS NULL)
    ) chapter),'[]'::jsonb),
    -- Kept for older mobile clients while V2.1 rolls out.
    'units',coalesce((SELECT jsonb_agg(jsonb_build_object('id',u.id,'title',u.title,'position',u.position,
      'lessons',coalesce((SELECT jsonb_agg(public.englify_journey_lesson_node(l.id) ORDER BY l.position,l.id)
        FROM public.lessons l WHERE l.unit_id=u.id AND l.is_published AND l.archived_at IS NULL),'[]'::jsonb)) ORDER BY u.position,u.id)
      FROM public.learning_units u WHERE u.course_id=c.id AND u.is_published AND u.archived_at IS NULL),'[]'::jsonb)
  ) ORDER BY c.level,c.id),'[]'::jsonb) INTO result
  FROM public.courses c WHERE c.is_published AND c.archived_at IS NULL;
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.englify_lesson_detail(p_lesson_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE state text; lesson record; items jsonb; questions jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  state:=public.englify_lesson_state(p_lesson_id);
  IF state IS NULL THEN RAISE EXCEPTION 'Published lesson not found' USING ERRCODE='P0002'; END IF;
  IF state='locked' THEN RAISE EXCEPTION 'Complete the required lessons first' USING ERRCODE='42501'; END IF;
  SELECT l.*,c.cefr_level,u.title unit_title INTO lesson FROM public.lessons l
    JOIN public.courses c ON c.id=l.course_id JOIN public.learning_units u ON u.id=l.unit_id WHERE l.id=p_lesson_id;
  SELECT coalesce(jsonb_agg(jsonb_build_object('kind',i.kind,'body',i.body) ORDER BY i.position),'[]'::jsonb)
    INTO items FROM public.lesson_items i WHERE i.lesson_id=p_lesson_id AND i.is_published AND i.archived_at IS NULL;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',q.id,'kind',q.kind,'prompt',q.prompt,'payload',q.payload,
    'options',CASE WHEN q.kind='multiple_choice' THEN coalesce((SELECT jsonb_agg(jsonb_build_object('id',o.id,'text',o.answer_text) ORDER BY o.position) FROM public.quiz_options o WHERE o.question_id=q.id),'[]'::jsonb) ELSE '[]'::jsonb END) ORDER BY q.position),'[]'::jsonb)
    INTO questions FROM public.quiz_questions q WHERE q.lesson_id=p_lesson_id AND q.is_published AND q.archived_at IS NULL;
  RETURN public.englify_journey_lesson_node(p_lesson_id)||jsonb_build_object(
    'state',state,'cefr_level',lesson.cefr_level,'topic',lesson.unit_title,'items',items,'questions',questions);
END $$;

-- Keep the proven grading/XP transaction and wrap it with an authoritative unlock delta.
ALTER FUNCTION public.englify_submit_lesson(uuid,uuid,jsonb,text) RENAME TO englify_submit_lesson_v1;
REVOKE ALL ON FUNCTION public.englify_submit_lesson_v1(uuid,uuid,jsonb,text) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.englify_submit_lesson(p_lesson_id uuid,p_request_id uuid,p_answers jsonb,p_content_version text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE before_ids uuid[]; after_ids uuid[]; result jsonb;
BEGIN
  SELECT coalesce(array_agg(l.id ORDER BY l.id),'{}') INTO before_ids FROM public.lessons l
    WHERE public.englify_lesson_state(l.id)='available';
  result:=public.englify_submit_lesson_v1(p_lesson_id,p_request_id,p_answers,p_content_version);
  SELECT coalesce(array_agg(l.id ORDER BY l.id),'{}') INTO after_ids FROM public.lessons l
    WHERE public.englify_lesson_state(l.id)='available';
  RETURN result||jsonb_build_object('newly_unlocked',coalesce((SELECT jsonb_agg(public.englify_journey_lesson_node(id)) FROM unnest(after_ids) id WHERE NOT id=ANY(before_ids)),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.englify_submit_lesson(uuid,uuid,jsonb,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_submit_lesson(uuid,uuid,jsonb,text) TO authenticated;

-- No learner may mutate curriculum structure or explicit prerequisites.
REVOKE INSERT,UPDATE,DELETE ON public.journey_curriculum_versions,public.journey_chapters,
  public.journey_lesson_prerequisites FROM authenticated;
