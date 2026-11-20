BEGIN;
DO $$
DECLARE report jsonb;
BEGIN
  SELECT public.englify_admin_journey_curriculum_quality() INTO report;
  IF report->>'ready' <> 'true' THEN
    RAISE EXCEPTION 'Curriculum quality report is not ready: %',report;
  END IF;
  IF (report#>>'{totals,levels}')::int <> 10
    OR (report#>>'{totals,chapters}')::int <> 30
    OR (report#>>'{totals,units}')::int <> 60
    OR (report#>>'{totals,lessons}')::int <> 180
    OR (report#>>'{totals,checkpoints}')::int <> 60
    OR (report#>>'{totals,assessments}')::int <> 10
    OR (report#>>'{totals,capstones}')::int <> 1 THEN
    RAISE EXCEPTION 'Unexpected curriculum totals: %',report->'totals';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.journey_lesson_prerequisites p
    JOIN public.lessons l ON l.id=p.lesson_id
    WHERE l.external_id LIKE 'journey-v27-%' AND p.lesson_id=p.prerequisite_lesson_id
  ) THEN RAISE EXCEPTION 'Self prerequisite detected'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.quiz_questions q JOIN public.lessons l ON l.id=q.lesson_id
    WHERE l.external_id LIKE 'journey-v27-%' AND q.is_published
      AND NOT EXISTS(SELECT 1 FROM public.quiz_options o WHERE o.question_id=q.id AND o.is_correct)
  ) THEN RAISE EXCEPTION 'Published question lacks a correct option'; END IF;
  IF (SELECT count(*) FROM public.journey_course_prerequisites cp
      JOIN public.courses c ON c.id=cp.course_id
      WHERE c.external_id LIKE 'journey-v27-level-%') <> 9 THEN
    RAISE EXCEPTION 'Expected nine sequential Level prerequisites';
  END IF;
END $$;
ROLLBACK;

