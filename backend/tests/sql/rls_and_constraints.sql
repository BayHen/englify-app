-- Run only against a disposable database with the test Auth fixture.
\set ON_ERROR_STOP on
BEGIN;
INSERT INTO auth.users(id) VALUES
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
DO $$
BEGIN
  IF (SELECT count(*) FROM public.profiles WHERE id IN (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')) <> 2 THEN
    RAISE EXCEPTION 'Auth signup did not provision profiles';
  END IF;
END $$;
UPDATE public.profiles SET display_name = 'Alice' WHERE id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
UPDATE public.profiles SET display_name = 'Bob' WHERE id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
INSERT INTO public.saved_vocabulary(id, user_id, entry_id) VALUES
  ('88888888-8888-4888-8888-888888888801', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '11111111-1111-4111-8111-111111111101');
INSERT INTO public.user_levels(user_id, total_xp, level) VALUES
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 25, 1),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 120, 2);
INSERT INTO public.quest_claims(user_id, quest_id, period_start, awarded_xp) VALUES
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'aaaaaaaa-0000-4000-8000-000000000001', current_date, 5),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'aaaaaaaa-0000-4000-8000-000000000001', current_date, 5);
INSERT INTO public.reward_notifications(user_id, kind, source_id, title, message) VALUES
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'quest', 'aaaaaaaa-0000-4000-8000-000000000001', 'Alice quest', 'Complete'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'quest', 'aaaaaaaa-0000-4000-8000-000000000001', 'Bob quest', 'Complete');

DO $$
BEGIN
  IF (SELECT count(*) FROM pg_tables WHERE schemaname = 'public' AND rowsecurity AND tablename IN (
    'profiles','user_preferences','dictionary_entries','courses','lessons','quiz_questions',
    'quiz_options','learning_progress','learning_plans','saved_vocabulary','review_history',
    'badges','reward_items','xp_events','user_badges','reward_claims','quiz_attempts',
    'speaking_attempts','writing_submissions','learning_units','lesson_items',
    'quiz_answer_keys','lesson_attempts','lesson_answer_attempts',
    'gamification_config','user_levels','quests','quest_claims','badge_rules','reward_notifications')) <> 30 THEN
    RAISE EXCEPTION 'RLS is not enabled on every application table';
  END IF;
END $$;

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
UPDATE public.profiles SET display_name = 'Alice updated'
WHERE id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
UPDATE public.profiles SET display_name = 'Unauthorized change'
WHERE id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
DO $$
DECLARE visible_names text[];
BEGIN
  SELECT array_agg(display_name ORDER BY display_name) INTO visible_names FROM public.profiles;
  IF visible_names <> ARRAY['Alice updated'] THEN RAISE EXCEPTION 'Profile isolation failed: %', visible_names; END IF;
  IF (SELECT count(*) FROM public.dictionary_entries) < 3 THEN RAISE EXCEPTION 'Dictionary read failed'; END IF;
  IF (SELECT count(*) FROM public.courses) <> 1 THEN RAISE EXCEPTION 'Published course read failed'; END IF;
  IF (SELECT count(*) FROM public.lesson_items WHERE lesson_id = '33333333-3333-4333-8333-333333333302') <> 0 THEN RAISE EXCEPTION 'Locked lesson item exposed'; END IF;
  IF (SELECT count(*) FROM public.quiz_questions WHERE lesson_id = '33333333-3333-4333-8333-333333333302') <> 0 THEN RAISE EXCEPTION 'Locked quiz exposed'; END IF;
  IF has_table_privilege('authenticated', 'public.quiz_options', 'SELECT') THEN RAISE EXCEPTION 'Quiz answer key exposed'; END IF;
  IF has_table_privilege('authenticated', 'public.quiz_answer_keys', 'SELECT') THEN RAISE EXCEPTION 'Typed answer key exposed'; END IF;
  IF has_table_privilege('authenticated', 'public.lesson_attempts', 'INSERT') THEN RAISE EXCEPTION 'Client can forge lesson result'; END IF;
  IF has_table_privilege('authenticated', 'public.xp_events', 'INSERT') THEN RAISE EXCEPTION 'Client can award XP'; END IF;
  IF has_table_privilege('authenticated', 'public.reward_claims', 'INSERT') THEN RAISE EXCEPTION 'Client can claim rewards'; END IF;
  IF has_table_privilege('authenticated', 'public.quest_claims', 'INSERT') THEN RAISE EXCEPTION 'Client can forge quest rewards'; END IF;
  IF has_table_privilege('authenticated', 'public.user_levels', 'UPDATE') THEN RAISE EXCEPTION 'Client can forge levels'; END IF;
  IF has_table_privilege('authenticated', 'public.reward_notifications', 'INSERT') THEN RAISE EXCEPTION 'Client can forge notifications'; END IF;
  IF has_table_privilege('authenticated', 'public.gamification_config', 'SELECT') THEN RAISE EXCEPTION 'Client can read reward rules'; END IF;
  IF (SELECT count(*) FROM public.user_levels) <> 1 THEN RAISE EXCEPTION 'Level isolation failed'; END IF;
  IF (SELECT count(*) FROM public.quest_claims) <> 1 THEN RAISE EXCEPTION 'Quest isolation failed'; END IF;
  IF (SELECT count(*) FROM public.reward_notifications) <> 1 THEN RAISE EXCEPTION 'Notification isolation failed'; END IF;
  IF has_table_privilege('authenticated', 'public.learning_progress', 'UPDATE') THEN RAISE EXCEPTION 'Client can forge progress'; END IF;
END $$;

INSERT INTO public.user_preferences(user_id, daily_goal_minutes)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 15);
DO $$
BEGIN
  BEGIN
    INSERT INTO public.user_preferences(user_id) VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    RAISE EXCEPTION 'Cross-user preference insert unexpectedly passed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    INSERT INTO public.saved_vocabulary(user_id, entry_id)
    VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '11111111-1111-4111-8111-111111111102');
    RAISE EXCEPTION 'Cross-user saved word insert unexpectedly passed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;
INSERT INTO public.saved_vocabulary(id, user_id, entry_id)
VALUES ('88888888-8888-4888-8888-888888888802', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '11111111-1111-4111-8111-111111111102');
DO $$
BEGIN
  IF (SELECT count(*) FROM public.saved_vocabulary) <> 1 THEN RAISE EXCEPTION 'Saved word isolation failed'; END IF;
  BEGIN
    UPDATE public.saved_vocabulary SET user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'
    WHERE id = '88888888-8888-4888-8888-888888888802';
    RAISE EXCEPTION 'Cross-user ownership update unexpectedly passed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

SET LOCAL request.jwt.claim.sub = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
DO $$
BEGIN
  IF (SELECT count(*) FROM public.profiles) <> 1 THEN RAISE EXCEPTION 'Second user profile isolation failed'; END IF;
  IF (SELECT display_name FROM public.profiles) <> 'Bob' THEN RAISE EXCEPTION 'Cross-user profile update passed'; END IF;
  IF (SELECT count(*) FROM public.saved_vocabulary) <> 1 THEN RAISE EXCEPTION 'Second user saved word isolation failed'; END IF;
  IF (SELECT count(*) FROM public.user_preferences) <> 0 THEN RAISE EXCEPTION 'Other user preferences exposed'; END IF;
  IF (SELECT total_xp FROM public.user_levels) <> 120 THEN RAISE EXCEPTION 'Cross-user level exposed'; END IF;
  IF (SELECT count(*) FROM public.quest_claims) <> 1 THEN RAISE EXCEPTION 'Cross-user quest exposed'; END IF;
  IF (SELECT title FROM public.reward_notifications) <> 'Bob quest' THEN RAISE EXCEPTION 'Cross-user notification exposed'; END IF;
END $$;
SET LOCAL ROLE anon;
DO $$
BEGIN
  IF has_table_privilege('anon', 'public.profiles', 'SELECT') THEN RAISE EXCEPTION 'Anonymous profile read grant exists'; END IF;
  IF has_table_privilege('anon', 'public.dictionary_entries', 'SELECT') THEN RAISE EXCEPTION 'Anonymous dictionary read grant exists'; END IF;
END $$;

RESET ROLE;
DO $$
BEGIN
  BEGIN
    INSERT INTO public.review_history(user_id, saved_vocabulary_id, rating)
    VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '88888888-8888-4888-8888-888888888801', 5);
    RAISE EXCEPTION 'Cross-owner review FK unexpectedly passed';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.saved_vocabulary(user_id, entry_id)
    VALUES ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '11111111-1111-4111-8111-111111111101');
    RAISE EXCEPTION 'Duplicate saved word unexpectedly passed';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.quiz_attempts(user_id, question_id, selected_option_id, is_correct)
    VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '44444444-4444-4444-8444-444444444401',
            '55555555-5555-4555-8555-555555555501', true);
  EXCEPTION WHEN OTHERS THEN RAISE EXCEPTION 'Valid quiz FK failed: %', SQLERRM;
  END;
END $$;
ROLLBACK;
