-- Replace generated distractors while preserving historical questions and answers.
DO $$
DECLARE
  item record;
  target_lesson uuid;
  new_question uuid;
BEGIN
  FOR item IN SELECT * FROM (VALUES
    (1, 1, 'It is 9 a.m. You arrive at class. What do you say to greet your teacher?',
      ARRAY['Good night!', 'Good morning!', 'See you tomorrow!'], 2,
      'Good morning is a greeting. The other expressions are used when leaving.'),
    (1, 2, 'Mai says, “My name is Mai.” What has she told you?',
      ARRAY['Where she lives.', 'Where she is from.', 'What her name is.'], 3,
      'My name is introduces a name. To talk about origin, Mai could say I am from Hanoi.'),
    (1, 3, 'Leo says, “I am from Canada.” Which question did he answer?',
      ARRAY['Where are you from?', 'What is your name?', 'How are you?'], 1,
      'From Canada tells you Leo''s origin. It does not tell you his name or how he feels.'),
    (2, 1, 'Complete both sentences: “I ___ Linh. You ___ Alex.”',
      ARRAY['am / am', 'are / am', 'am / are'], 3,
      'Use am with I and are with you.'),
    (2, 2, 'You want to tell a classmate your name. Which sentence is correct?',
      ARRAY['My name is An.', 'My name are An.', 'My name am An.'], 1,
      'The subject is my name, so use is. Use am when the subject is I.'),
    (2, 3, 'Choose the correct question to check whether the person is Ben.',
      ARRAY['Am you Ben?', 'Are you Ben?', 'Is you Ben?'], 2,
      'Use are with you. Put are first in this yes/no question.'),
    (3, 1, 'Nina says, “Hi, I’m Nina. Nice to meet you.” What is the best reply?',
      ARRAY['Hi, Nina. I’m Sam. Nice to meet you, too.', 'Hi, Nina. I’m from Sam. Nice to meet you.', 'Hi, Nina. You’re Sam. Nice to meet you.'], 1,
      'Use I’m Sam to introduce yourself. You’re Sam identifies the person you are speaking to.'),
    (3, 2, 'You meet Jo for the first time and want to know Jo’s country. What do you ask?',
      ARRAY['Are you Jo?', 'How are you, Jo?', 'Where are you from, Jo?'], 3,
      'Where are you from asks about origin. How are you asks how someone feels.'),
    (3, 3, 'At a class introduction, the teacher asks, “What’s your name, and where are you from?”',
      ARRAY['I’m from Da Nang. Nice to meet you.', 'I’m Kim, and I’m from Da Nang.', 'I’m Kim. How are you?'], 2,
      'The teacher asked for two details. This reply gives both your name and where you are from.')
  ) AS content(lesson_number, question_number, prompt, choices, correct_position, explanation)
  LOOP
    SELECT id INTO target_lesson FROM public.lessons
      WHERE external_id = 'journey-v27-l01-u02-lesson-' || item.lesson_number;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Missing Meet and greet lesson %', item.lesson_number;
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
