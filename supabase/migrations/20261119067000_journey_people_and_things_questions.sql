-- Replace generated distractors while preserving historical questions and answers.
DO $$
DECLARE
  item record;
  target_lesson uuid;
  new_question uuid;
BEGIN
  FOR item IN SELECT * FROM (VALUES
    (1, 1, 'Which sentence names a person?', ARRAY['The key is here.', 'The nurse is here.', 'The station is here.'], 2, 'A nurse is a person. A key is an object, and a station is a place.'),
    (1, 2, 'Which word names a place in “The students are at the library”?', ARRAY['students', 'at', 'library'], 3, 'The library is where the students are.'),
    (1, 3, 'Nam puts his bag on a chair. What does he put on the chair?', ARRAY['His bag.', 'His chair.', 'Nam.'], 1, 'The bag is the object Nam moves. The chair is where he puts it.'),
    (2, 1, 'Mai and I are in the same class. ___ are classmates.', ARRAY['They', 'You', 'We'], 3, 'Use we for a group that includes the speaker.'),
    (2, 2, 'The book is on the table. ___ is blue.', ARRAY['It', 'They', 'We'], 1, 'Use it for one thing.'),
    (2, 3, 'Linh and Bao are at school. ___ are in the library.', ARRAY['We', 'They', 'She'], 2, 'They refers to Linh and Bao.'),
    (3, 1, 'You say to Ana, “___ are in my class.” Which pronoun addresses Ana directly?', ARRAY['You', 'We', 'They'], 1, 'You refers to the person you are speaking to.'),
    (3, 2, 'Sam asks, “Where are the keys?” Which reply is correct?', ARRAY['It is on the desk.', 'We are on the desk.', 'They are on the desk.'], 3, 'Use they to replace the plural noun keys.'),
    (3, 3, '“Are you and Minh ready?” You are both ready. How do you reply?', ARRAY['Yes, they are.', 'Yes, we are.', 'Yes, you are.'], 2, 'Use we because the answer includes you and Minh.')
  ) AS content(lesson_number, question_number, prompt, choices, correct_position, explanation)
  LOOP
    SELECT id INTO target_lesson FROM public.lessons
      WHERE external_id = 'journey-v27-l01-u03-lesson-' || item.lesson_number;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Missing People and things lesson %', item.lesson_number;
    END IF;

    UPDATE public.quiz_questions
      SET is_published = false, archived_at = transaction_timestamp()
      WHERE lesson_id = target_lesson AND position = item.question_number
        AND kind = 'multiple_choice' AND prompt LIKE '%Which answer best fits the objective%'
        AND archived_at IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Expected generated question missing for lesson %, question %',
        item.lesson_number, item.question_number;
    END IF;

    INSERT INTO public.quiz_questions(lesson_id, position, kind, prompt, explanation, explanation_en, is_published)
      VALUES (target_lesson, item.question_number + 10, 'multiple_choice', item.prompt, item.explanation, item.explanation, false)
      RETURNING id INTO new_question;

    INSERT INTO public.quiz_options(question_id, position, answer_text, is_correct)
      SELECT new_question, choice.position::integer, choice.answer_text, choice.position = item.correct_position
      FROM unnest(item.choices) WITH ORDINALITY AS choice(answer_text, position);

    UPDATE public.quiz_questions SET is_published = true WHERE id = new_question;
  END LOOP;
END $$;
