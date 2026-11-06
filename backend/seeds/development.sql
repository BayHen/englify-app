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
COMMIT;
