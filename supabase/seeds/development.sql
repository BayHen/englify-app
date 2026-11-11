-- Idempotent, content-only development seed. No Auth users or personal progress.
-- Run with a database owner after `alembic upgrade head`.
BEGIN;
-- Original editorial sample entries authored for this project; no third-party dataset.
INSERT INTO public.dictionary_entries (id, language, term, normalized_term, definition, translation, part_of_speech, example, ipa, source_name, license_id)
VALUES
  ('11111111-1111-4111-8111-111111111101', 'en', 'curious', 'curious', 'Eager to learn or find out more.', 'tò mò', 'adjective', 'I am curious about this story.', '/ˈkjʊriəs/', 'Englify Quest editorial', 'project-owned'),
  ('11111111-1111-4111-8111-111111111102', 'en', 'journey', 'journey', 'A trip from one place to another.', 'hành trình', 'noun', 'Every journey starts with one step.', '/ˈdʒɜːrni/', 'Englify Quest editorial', 'project-owned'),
  ('11111111-1111-4111-8111-111111111103', 'en', 'practice', 'practice', 'To do an activity repeatedly to improve.', 'luyện tập', 'verb', 'I practice English every day.', '/ˈpræktɪs/', 'Englify Quest editorial', 'project-owned'),
  ('11111111-1111-4111-8111-111111111104', 'en', 'reward', 'reward', 'Something received for effort or achievement.', 'phần thưởng', 'noun', 'Finishing the lesson was its own reward.', '/rɪˈwɔːrd/', 'Englify Quest editorial', 'project-owned'),
  ('11111111-1111-4111-8111-111111111105', 'en', 'explore', 'explore', 'To travel through or study something new.', 'khám phá', 'verb', 'We explore a new neighborhood on weekends.', '/ɪkˈsplɔːr/', 'Englify Quest editorial', 'project-owned'),
  ('11111111-1111-4111-8111-111111111106', 'en', 'confident', 'confident', 'Feeling sure about your ability to do something.', 'tự tin', 'adjective', 'She feels confident speaking English.', '/ˈkɒnfɪdənt/', 'Englify Quest editorial', 'project-owned'),
  ('11111111-1111-4111-8111-111111111107', 'en', 'listen', 'listen', 'To pay attention to a sound or speaker.', 'lắng nghe', 'verb', 'Listen carefully to the question.', '/ˈlɪsən/', 'Englify Quest editorial', 'project-owned'),
  ('11111111-1111-4111-8111-111111111108', 'en', 'improve', 'improve', 'To become better or make something better.', 'cải thiện', 'verb', 'Reading every day can improve your vocabulary.', '/ɪmˈpruːv/', 'Englify Quest editorial', 'project-owned'),
  ('11111111-1111-4111-8111-111111111109', 'en', 'conversation', 'conversation', 'A talk between two or more people.', 'cuộc trò chuyện', 'noun', 'We had a short conversation after class.', '/ˌkɒnvəˈseɪʃən/', 'Englify Quest editorial', 'project-owned'),
  ('11111111-1111-4111-8111-111111111110', 'en', 'remember', 'remember', 'To keep something in your mind or recall it.', 'ghi nhớ', 'verb', 'I remember the new word by using it in a sentence.', '/rɪˈmembər/', 'Englify Quest editorial', 'project-owned')
ON CONFLICT (id) DO UPDATE SET term = EXCLUDED.term, normalized_term = EXCLUDED.normalized_term, definition = EXCLUDED.definition, translation = EXCLUDED.translation, part_of_speech = EXCLUDED.part_of_speech, example = EXCLUDED.example, ipa = EXCLUDED.ipa, source_name = EXCLUDED.source_name, license_id = EXCLUDED.license_id;
INSERT INTO public.courses (id, slug, title, description, level, is_published)
VALUES ('22222222-2222-4222-8222-222222222201', 'everyday-english', 'Everyday English', 'Short conversations for beginners.', 1, true)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description, level = EXCLUDED.level, is_published = EXCLUDED.is_published;
INSERT INTO public.lessons (id, course_id, slug, position, title, objective, content, xp_reward, is_published)
VALUES
  ('33333333-3333-4333-8333-333333333301', '22222222-2222-4222-8222-222222222201', 'say-hello', 1, 'Say hello', 'Greet someone and introduce yourself.', '{"phrases":["Hello!","How is it going?"]}'::jsonb, 20, true),
  ('33333333-3333-4333-8333-333333333302', '22222222-2222-4222-8222-222222222201', 'keep-it-going', 2, 'Keep it going', 'Ask a friendly follow-up question.', '{"phrases":["What have you been up to?"]}'::jsonb, 25, true)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, objective = EXCLUDED.objective, content = EXCLUDED.content, xp_reward = EXCLUDED.xp_reward, is_published = EXCLUDED.is_published;
INSERT INTO public.quiz_questions (id, lesson_id, position, prompt, explanation)
VALUES ('44444444-4444-4444-8444-444444444401', '33333333-3333-4333-8333-333333333301', 1, 'Which phrase is a friendly greeting?', 'How is it going? is a casual greeting.')
ON CONFLICT (id) DO UPDATE SET prompt = EXCLUDED.prompt, explanation = EXCLUDED.explanation;
INSERT INTO public.quiz_options (id, question_id, position, answer_text, is_correct)
VALUES
  ('55555555-5555-4555-8555-555555555501', '44444444-4444-4444-8444-444444444401', 1, 'How is it going?', true),
  ('55555555-5555-4555-8555-555555555502', '44444444-4444-4444-8444-444444444401', 2, 'Close the door.', false),
  ('55555555-5555-4555-8555-555555555503', '44444444-4444-4444-8444-444444444401', 3, 'I have a pen.', false)
ON CONFLICT (id) DO UPDATE SET answer_text = EXCLUDED.answer_text, is_correct = EXCLUDED.is_correct;
INSERT INTO public.badges (id, code, title, description)
VALUES ('66666666-6666-4666-8666-666666666601', 'first-step', 'First step', 'Complete your first lesson.')
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description;
INSERT INTO public.reward_items (id, code, title, description, xp_cost, is_active)
VALUES ('77777777-7777-4777-8777-777777777701', 'starlight-frame', 'Starlight frame', 'A playful profile frame.', 120, true)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, description = EXCLUDED.description, xp_cost = EXCLUDED.xp_cost, is_active = EXCLUDED.is_active;
-- Complete first unit: four lessons and all five supported question formats.
INSERT INTO public.learning_units(id, course_id, slug, title, position)
VALUES ('88888888-8888-4888-8888-888888888810', '22222222-2222-4222-8222-222222222201', 'first-conversations', 'First conversations', 1)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;
UPDATE public.lessons SET unit_id = '88888888-8888-4888-8888-888888888810'
WHERE id IN ('33333333-3333-4333-8333-333333333301', '33333333-3333-4333-8333-333333333302');
INSERT INTO public.lessons(id, course_id, unit_id, slug, position, title, objective, content, xp_reward, is_published)
VALUES
  ('33333333-3333-4333-8333-333333333303', '22222222-2222-4222-8222-222222222201', '88888888-8888-4888-8888-888888888810', 'places-and-words', 3, 'Places and words', 'Match everyday places to their meanings.', '{}'::jsonb, 25, true),
  ('33333333-3333-4333-8333-333333333304', '22222222-2222-4222-8222-222222222201', '88888888-8888-4888-8888-888888888810', 'listen-and-reply', 4, 'Listen and reply', 'Recognize a greeting and choose a response.', '{}'::jsonb, 30, true)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, objective = EXCLUDED.objective, unit_id = EXCLUDED.unit_id, is_published = EXCLUDED.is_published;
INSERT INTO public.lesson_items(id, lesson_id, position, kind, body)
VALUES
  ('99999999-9999-4999-8999-999999999901', '33333333-3333-4333-8333-333333333301', 1, 'reading', '{"text":"Hello! and How is it going? are friendly greetings."}'::jsonb),
  ('99999999-9999-4999-8999-999999999902', '33333333-3333-4333-8333-333333333302', 1, 'tip', '{"text":"Ask a short follow-up question after a greeting."}'::jsonb),
  ('99999999-9999-4999-8999-999999999903', '33333333-3333-4333-8333-333333333303', 1, 'reading', '{"text":"A station is where you catch a train. A library is where you borrow books."}'::jsonb),
  ('99999999-9999-4999-8999-999999999904', '33333333-3333-4333-8333-333333333304', 1, 'tip', '{"text":"Listen once for the main idea, then again for the exact words."}'::jsonb)
ON CONFLICT (id) DO UPDATE SET body = EXCLUDED.body;
INSERT INTO public.quiz_questions(id, lesson_id, position, kind, prompt, explanation, payload)
VALUES
  ('44444444-4444-4444-8444-444444444402', '33333333-3333-4333-8333-333333333302', 1, 'fill_blank', 'Complete: How ___ you?', 'Use are with you.', '{"placeholder":"Type the missing word"}'::jsonb),
  ('44444444-4444-4444-8444-444444444403', '33333333-3333-4333-8333-333333333302', 2, 'grammar', 'Write the correct sentence: she / is / happy', 'The subject comes before is.', '{"placeholder":"Write the sentence"}'::jsonb),
  ('44444444-4444-4444-8444-444444444404', '33333333-3333-4333-8333-333333333303', 1, 'matching', 'Match each place to its use.', 'Stations have trains; libraries have books.', '{"left":[{"id":"station","text":"station"},{"id":"library","text":"library"}],"right":[{"id":"trains","text":"catch trains"},{"id":"books","text":"borrow books"}]}'::jsonb),
  ('44444444-4444-4444-8444-444444444405', '33333333-3333-4333-8333-333333333304', 1, 'listening', 'Listen and type the greeting.', 'The speaker says Good morning.', '{"speak_text":"Good morning","placeholder":"Type what you hear"}'::jsonb),
  ('44444444-4444-4444-8444-444444444406', '33333333-3333-4333-8333-333333333304', 2, 'multiple_choice', 'Choose a friendly reply to Good morning.', 'Good morning is a matching reply.', '{}'::jsonb)
ON CONFLICT (id) DO UPDATE SET kind = EXCLUDED.kind, prompt = EXCLUDED.prompt, explanation = EXCLUDED.explanation, payload = EXCLUDED.payload;
INSERT INTO public.quiz_options(id, question_id, position, answer_text, is_correct)
VALUES
  ('55555555-5555-4555-8555-555555555504', '44444444-4444-4444-8444-444444444406', 1, 'Good morning!', true),
  ('55555555-5555-4555-8555-555555555505', '44444444-4444-4444-8444-444444444406', 2, 'Good night!', false)
ON CONFLICT (id) DO UPDATE SET answer_text = EXCLUDED.answer_text, is_correct = EXCLUDED.is_correct;
INSERT INTO public.quiz_answer_keys(question_id, answer)
VALUES
  ('44444444-4444-4444-8444-444444444402', '["are"]'::jsonb),
  ('44444444-4444-4444-8444-444444444403', '["She is happy."]'::jsonb),
  ('44444444-4444-4444-8444-444444444404', '{"station":"trains","library":"books"}'::jsonb),
  ('44444444-4444-4444-8444-444444444405', '["Good morning"]'::jsonb)
ON CONFLICT (question_id) DO UPDATE SET answer = EXCLUDED.answer;
-- Keep the project's deterministic examples visible after admin draft defaults were introduced.
UPDATE public.dictionary_entries SET is_published=true WHERE id::text LIKE '11111111-1111-4111-8111-%';
UPDATE public.learning_units SET is_published=true WHERE id::text LIKE '88888888-8888-4888-8888-%';
UPDATE public.lesson_items SET is_published=true WHERE id::text LIKE '99999999-9999-4999-8999-%';
UPDATE public.quiz_questions SET is_published=true WHERE id::text LIKE '44444444-4444-4444-8444-%';
COMMIT;
