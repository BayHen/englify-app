-- Journey V2.7 extension: metadata and deterministic quality reporting for the
-- prebuilt Level 1-10 curriculum. Content is loaded by the local/staging seed.
ALTER TABLE public.courses
  ADD COLUMN IF NOT EXISTS external_id text,
  ADD COLUMN IF NOT EXISTS cefr_guidance text,
  ADD COLUMN IF NOT EXISTS learning_objectives jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS vocabulary_focus jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS grammar_focus jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS skill_focus jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS courses_external_id_unique
  ON public.courses(external_id) WHERE external_id IS NOT NULL;

ALTER TABLE public.journey_chapters
  ADD COLUMN IF NOT EXISTS vocabulary_focus jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS grammar_focus jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS skill_focus jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.learning_units
  ADD COLUMN IF NOT EXISTS vocabulary_focus jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS grammar_focus jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.lessons
  ADD COLUMN IF NOT EXISTS assessment_scope text NOT NULL DEFAULT 'lesson'
    CHECK (assessment_scope IN ('lesson','unit_checkpoint','level_assessment','capstone'));

CREATE TABLE public.journey_course_prerequisites (
  course_id uuid PRIMARY KEY REFERENCES public.courses(id) ON DELETE CASCADE,
  prerequisite_course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK(course_id<>prerequisite_course_id)
);
ALTER TABLE public.journey_course_prerequisites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.journey_course_prerequisites FROM anon,authenticated;
GRANT ALL ON public.journey_course_prerequisites TO service_role;
GRANT SELECT ON public.journey_course_prerequisites TO authenticated;
CREATE POLICY journey_course_prerequisites_read ON public.journey_course_prerequisites
  FOR SELECT TO authenticated USING(true);

CREATE OR REPLACE FUNCTION public.englify_lesson_state(p_lesson_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT CASE
    WHEN p.status IN ('in_progress','completed','mastered') THEN p.status
    WHEN NOT c.is_published OR c.archived_at IS NOT NULL OR NOT u.is_published OR u.archived_at IS NOT NULL
      OR NOT l.is_published OR l.archived_at IS NOT NULL
      OR (u.chapter_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.journey_chapters ch WHERE ch.id=u.chapter_id
          AND ch.is_published AND ch.archived_at IS NULL)) THEN NULL
    WHEN EXISTS (
      SELECT 1 FROM public.journey_course_prerequisites cp
      WHERE cp.course_id=c.id AND NOT EXISTS (
        SELECT 1 FROM public.lessons final
        JOIN public.learning_progress fp ON fp.lesson_id=final.id AND fp.user_id=auth.uid()
        WHERE final.course_id=cp.prerequisite_course_id
          AND final.assessment_scope='level_assessment'
          AND fp.status IN ('completed','mastered')
      )
    ) THEN 'locked'
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

CREATE OR REPLACE FUNCTION public.englify_admin_journey_curriculum_quality()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
WITH levels AS (
  SELECT c.id,c.level,c.title,c.cefr_guidance,
    count(DISTINCT ch.id) FILTER (WHERE ch.archived_at IS NULL) AS chapters,
    count(DISTINCT u.id) FILTER (WHERE u.archived_at IS NULL) AS units,
    count(DISTINCT l.id) FILTER (WHERE l.archived_at IS NULL AND l.assessment_scope='lesson') AS lessons,
    count(DISTINCT l.id) FILTER (WHERE l.archived_at IS NULL AND l.assessment_scope='unit_checkpoint') AS checkpoints,
    count(DISTINCT l.id) FILTER (WHERE l.archived_at IS NULL AND l.assessment_scope='level_assessment') AS assessments,
    count(DISTINCT l.id) FILTER (WHERE l.archived_at IS NULL AND l.assessment_scope='capstone') AS capstones
  FROM public.courses c
  LEFT JOIN public.journey_chapters ch ON ch.course_id=c.id
  LEFT JOIN public.learning_units u ON u.chapter_id=ch.id
  LEFT JOIN public.lessons l ON l.course_id=c.id
  WHERE c.external_id LIKE 'journey-v27-level-%' AND c.archived_at IS NULL
  GROUP BY c.id,c.level,c.title,c.cefr_guidance
), invalid_lessons AS (
  SELECT l.id,l.external_id,'missing published revision or blocks' reason
  FROM public.lessons l
  LEFT JOIN public.journey_lesson_revisions r ON r.lesson_id=l.id AND r.status='published'
  WHERE l.external_id LIKE 'journey-v27-%' AND l.archived_at IS NULL
    AND (r.id IS NULL OR NOT EXISTS (SELECT 1 FROM public.journey_lesson_blocks b WHERE b.revision_id=r.id))
  UNION ALL
  SELECT l.id,l.external_id,'missing published questions or answer key'
  FROM public.lessons l
  WHERE l.external_id LIKE 'journey-v27-%' AND l.archived_at IS NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.quiz_questions q
      WHERE q.lesson_id=l.id AND q.is_published AND q.archived_at IS NULL
        AND (EXISTS (SELECT 1 FROM public.quiz_options o WHERE o.question_id=q.id AND o.is_correct)
          OR EXISTS (SELECT 1 FROM public.quiz_answer_keys k WHERE k.question_id=q.id))
    )
), duplicate_prompts AS (
  SELECT lower(btrim(q.prompt)) prompt,count(*) occurrences
  FROM public.quiz_questions q JOIN public.lessons l ON l.id=q.lesson_id
  WHERE l.external_id LIKE 'journey-v27-%' AND q.archived_at IS NULL
  GROUP BY lower(btrim(q.prompt)) HAVING count(*)>1
)
SELECT jsonb_build_object(
  'ready', (SELECT count(*)=10 AND bool_and(chapters=3 AND units=6 AND lessons=18 AND checkpoints=6 AND assessments=1 AND (level<>10 OR capstones=1)) FROM levels)
    AND NOT EXISTS(SELECT 1 FROM invalid_lessons) AND NOT EXISTS(SELECT 1 FROM duplicate_prompts),
  'totals', jsonb_build_object(
    'levels',(SELECT count(*) FROM levels),'chapters',(SELECT coalesce(sum(chapters),0) FROM levels),
    'units',(SELECT coalesce(sum(units),0) FROM levels),'lessons',(SELECT coalesce(sum(lessons),0) FROM levels),
    'checkpoints',(SELECT coalesce(sum(checkpoints),0) FROM levels),'assessments',(SELECT coalesce(sum(assessments),0) FROM levels),
    'capstones',(SELECT coalesce(sum(capstones),0) FROM levels)),
  'levels',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY level),'[]'::jsonb) FROM levels x),
  'invalid_content',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) FROM invalid_lessons x),
  'duplicate_questions',(SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) FROM duplicate_prompts x)
);
$$;

REVOKE ALL ON FUNCTION public.englify_admin_journey_curriculum_quality() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_admin_journey_curriculum_quality() TO authenticated,service_role;

