BEGIN;
DO $$
DECLARE
  unit_count integer;
  exercise_count integer;
BEGIN
  SELECT count(DISTINCT unit_id), count(*) INTO unit_count, exercise_count
  FROM public.lessons
  WHERE external_id ~ '^journey-v27-l[0-9]{2}-u[0-9]{2}-(lesson-[123]|checkpoint)$';

  IF unit_count <> 60 OR exercise_count <> 240 THEN
    RAISE EXCEPTION 'Expected 60 Units and 240 exercises, received %, %', unit_count, exercise_count;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.lessons l
    LEFT JOIN public.quiz_questions q
      ON q.lesson_id=l.id AND q.is_published AND q.archived_at IS NULL
    WHERE l.external_id ~ '^journey-v27-l[0-9]{2}-u[0-9]{2}-(lesson-[123]|checkpoint)$'
    GROUP BY l.id, l.lesson_kind
    HAVING count(q.id) <> CASE WHEN l.lesson_kind='checkpoint' THEN 6 ELSE 3 END
      OR bool_or(q.prompt ~* 'Which answer best fits the objective|Select the language that belongs to')
  ) THEN
    RAISE EXCEPTION 'Some Unit exercises are incomplete or still contain generated placeholders';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.lessons l
    JOIN public.quiz_questions q ON q.lesson_id=l.id AND q.is_published AND q.archived_at IS NULL
    LEFT JOIN public.quiz_options o ON o.question_id=q.id
    WHERE l.external_id ~ '^journey-v27-l[0-9]{2}-u[0-9]{2}-(lesson-[123]|checkpoint)$'
    GROUP BY q.id
    HAVING count(o.id) <> 3 OR count(o.id) FILTER (WHERE o.is_correct) <> 1
      OR count(DISTINCT lower(btrim(o.answer_text))) <> 3
  ) THEN
    RAISE EXCEPTION 'Invalid choices or answer key in Unit bank';
  END IF;
END $$;
ROLLBACK;
