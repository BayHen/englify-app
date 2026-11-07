-- Original Englify Quest educational exercises. Content only; no user records.
BEGIN;
INSERT INTO public.writing_exercises(id,slug,kind,prompt,hint,tokens,is_published) VALUES
('44444444-4444-4444-8444-444444444401','daily-routine','sentence','Write: I practice English every day.','Use a capital letter and a period.','[]',true),
('44444444-4444-4444-8444-444444444402','fill-station','fill_blank','Complete: The train arrives at the ____.','Write only the missing word.','[]',true),
('44444444-4444-4444-8444-444444444403','order-friendly','sentence_order','Put the words in order to make a friendly question.','Tap each word in order.','["today?","you","How","are"]',true),
('44444444-4444-4444-8444-444444444404','weekend-paragraph','paragraph','Write a short paragraph about a place you enjoy visiting.','Aim for three clear sentences with examples.','[]',true)
ON CONFLICT(slug) DO UPDATE SET kind=EXCLUDED.kind,prompt=EXCLUDED.prompt,hint=EXCLUDED.hint,tokens=EXCLUDED.tokens,is_published=EXCLUDED.is_published,updated_at=now();
INSERT INTO public.writing_answer_keys(exercise_id,accepted_answers) VALUES
('44444444-4444-4444-8444-444444444401','["I practice English every day."]'),
('44444444-4444-4444-8444-444444444402','["station"]'),
('44444444-4444-4444-8444-444444444403','["How are you today?"]'),
('44444444-4444-4444-8444-444444444404','[]')
ON CONFLICT(exercise_id) DO UPDATE SET accepted_answers=EXCLUDED.accepted_answers;
COMMIT;
