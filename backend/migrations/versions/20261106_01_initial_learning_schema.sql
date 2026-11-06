-- Supabase owns auth.users, auth.uid(), anon and authenticated. Never create them here.
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL CHECK (length(trim(display_name)) BETWEEN 1 AND 80),
  avatar_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
-- Auth remains Supabase-managed. This trigger creates only an application profile.
CREATE FUNCTION public.provision_profile() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  INSERT INTO public.profiles(id, display_name)
  VALUES (NEW.id, left(coalesce(nullif(trim(NEW.raw_user_meta_data->>'display_name'), ''), 'Learner'), 80))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.provision_profile() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.provision_profile();
INSERT INTO public.profiles(id, display_name)
SELECT id, left(coalesce(nullif(trim(raw_user_meta_data->>'display_name'), ''), 'Learner'), 80)
FROM auth.users ON CONFLICT (id) DO NOTHING;
CREATE TABLE public.user_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  learning_language text NOT NULL DEFAULT 'en' CHECK (learning_language = 'en'),
  native_language text NOT NULL DEFAULT 'vi' CHECK (native_language IN ('vi', 'en')),
  daily_goal_minutes integer NOT NULL DEFAULT 10 CHECK (daily_goal_minutes BETWEEN 1 AND 180),
  reminder_enabled boolean NOT NULL DEFAULT false,
  theme text NOT NULL DEFAULT 'system' CHECK (theme IN ('system', 'light', 'dark')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.dictionary_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  language text NOT NULL CHECK (language IN ('en', 'vi')),
  term text NOT NULL CHECK (length(trim(term)) > 0),
  normalized_term text NOT NULL CHECK (length(trim(normalized_term)) > 0),
  definition text NOT NULL,
  translation text,
  part_of_speech text,
  example text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (language, normalized_term)
);
CREATE INDEX ix_dictionary_entries_lookup ON public.dictionary_entries(language, normalized_term);
CREATE TABLE public.courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  level integer NOT NULL DEFAULT 1 CHECK (level > 0),
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_courses_published_level ON public.courses(is_published, level);
CREATE TABLE public.lessons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  slug text NOT NULL,
  position integer NOT NULL CHECK (position > 0),
  title text NOT NULL,
  objective text NOT NULL,
  content jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(content) = 'object'),
  xp_reward integer NOT NULL DEFAULT 0 CHECK (xp_reward BETWEEN 0 AND 1000),
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (course_id, slug), UNIQUE (course_id, position)
);
CREATE INDEX ix_lessons_course_position ON public.lessons(course_id, position);
CREATE TABLE public.quiz_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  position integer NOT NULL CHECK (position > 0),
  prompt text NOT NULL,
  explanation text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (lesson_id, position)
);
CREATE TABLE public.quiz_options (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL REFERENCES public.quiz_questions(id) ON DELETE CASCADE,
  position integer NOT NULL CHECK (position > 0),
  answer_text text NOT NULL,
  is_correct boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (question_id, position), UNIQUE (id, question_id)
);
CREATE UNIQUE INDEX ux_quiz_one_correct_option ON public.quiz_options(question_id) WHERE is_correct;
CREATE TABLE public.learning_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'not_started' CHECK (status IN ('not_started', 'in_progress', 'completed')),
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, lesson_id),
  CHECK ((status = 'completed') = (completed_at IS NOT NULL))
);
CREATE INDEX ix_learning_progress_user_status ON public.learning_progress(user_id, status);
CREATE INDEX ix_learning_progress_lesson ON public.learning_progress(lesson_id);
CREATE TABLE public.learning_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  goal text NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed')),
  target_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_learning_plans_user_status ON public.learning_plans(user_id, status);
CREATE UNIQUE INDEX ux_learning_plans_one_active ON public.learning_plans(user_id) WHERE status = 'active';
CREATE TABLE public.saved_vocabulary (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  entry_id uuid NOT NULL REFERENCES public.dictionary_entries(id) ON DELETE CASCADE,
  note text NOT NULL DEFAULT '',
  next_review_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, entry_id), UNIQUE (id, user_id)
);
CREATE INDEX ix_saved_vocabulary_due ON public.saved_vocabulary(user_id, next_review_at);
CREATE INDEX ix_saved_vocabulary_entry ON public.saved_vocabulary(entry_id);
CREATE TABLE public.review_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  saved_vocabulary_id uuid NOT NULL,
  rating integer NOT NULL CHECK (rating BETWEEN 0 AND 5),
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (saved_vocabulary_id, user_id) REFERENCES public.saved_vocabulary(id, user_id) ON DELETE CASCADE
);
CREATE INDEX ix_review_history_user_recent ON public.review_history(user_id, reviewed_at DESC);
CREATE INDEX ix_review_history_saved ON public.review_history(saved_vocabulary_id);
CREATE TABLE public.badges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.reward_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  xp_cost integer NOT NULL CHECK (xp_cost >= 0),
  is_active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.xp_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  source_type text NOT NULL CHECK (source_type IN ('lesson', 'quiz', 'review', 'speaking', 'writing', 'adjustment')),
  source_id uuid NOT NULL,
  amount integer NOT NULL CHECK (amount BETWEEN -10000 AND 10000 AND amount <> 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, source_type, source_id)
);
CREATE INDEX ix_xp_events_user_recent ON public.xp_events(user_id, created_at DESC);
CREATE TABLE public.user_badges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  badge_id uuid NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
  awarded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, badge_id)
);
CREATE INDEX ix_user_badges_user_recent ON public.user_badges(user_id, awarded_at DESC);
CREATE TABLE public.reward_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reward_id uuid NOT NULL REFERENCES public.reward_items(id) ON DELETE RESTRICT,
  xp_cost integer NOT NULL CHECK (xp_cost >= 0),
  claimed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, reward_id)
);
CREATE INDEX ix_reward_claims_user_recent ON public.reward_claims(user_id, claimed_at DESC);
CREATE TABLE public.quiz_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  question_id uuid NOT NULL REFERENCES public.quiz_questions(id) ON DELETE CASCADE,
  selected_option_id uuid NOT NULL,
  is_correct boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (selected_option_id, question_id) REFERENCES public.quiz_options(id, question_id) ON DELETE CASCADE
);
CREATE INDEX ix_quiz_attempts_user_recent ON public.quiz_attempts(user_id, created_at DESC);
CREATE INDEX ix_quiz_attempts_question ON public.quiz_attempts(question_id);
CREATE TABLE public.speaking_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  lesson_id uuid REFERENCES public.lessons(id) ON DELETE SET NULL,
  prompt text NOT NULL,
  transcript text,
  feedback jsonb CHECK (feedback IS NULL OR jsonb_typeof(feedback) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_speaking_attempts_user_recent ON public.speaking_attempts(user_id, created_at DESC);
CREATE INDEX ix_speaking_attempts_lesson ON public.speaking_attempts(lesson_id);
CREATE TABLE public.writing_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  lesson_id uuid REFERENCES public.lessons(id) ON DELETE SET NULL,
  prompt text NOT NULL,
  body text NOT NULL CHECK (length(body) <= 20000),
  feedback jsonb CHECK (feedback IS NULL OR jsonb_typeof(feedback) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_writing_submissions_user_recent ON public.writing_submissions(user_id, created_at DESC);
CREATE INDEX ix_writing_submissions_lesson ON public.writing_submissions(lesson_id);

CREATE FUNCTION public.touch_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.touch_updated_at() FROM PUBLIC, anon, authenticated;
DO $do$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'profiles','user_preferences','dictionary_entries','courses','lessons',
    'quiz_questions','quiz_options','learning_progress','learning_plans',
    'saved_vocabulary','badges','reward_items','speaking_attempts','writing_submissions'
  ] LOOP
    EXECUTE format('CREATE TRIGGER %I BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at()', 'trg_' || t || '_updated_at', t);
  END LOOP;
END $do$;

-- The request role and auth.uid() come from Supabase Auth. No public writes to
-- course content or reward/progress award tables.
DO $do$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'profiles','user_preferences','dictionary_entries','courses','lessons',
    'quiz_questions','quiz_options','learning_progress','learning_plans',
    'saved_vocabulary','review_history','badges','reward_items','xp_events',
    'user_badges','reward_claims','quiz_attempts','speaking_attempts',
    'writing_submissions'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated', t);
  END LOOP;
END $do$;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Published learning content is readable; the answer key is not exposed.
GRANT SELECT ON public.dictionary_entries, public.courses, public.lessons,
  public.quiz_questions, public.badges, public.reward_items TO authenticated;
CREATE POLICY dictionary_read ON public.dictionary_entries FOR SELECT TO authenticated USING (true);
CREATE POLICY courses_read ON public.courses FOR SELECT TO authenticated USING (is_published);
CREATE POLICY lessons_read ON public.lessons FOR SELECT TO authenticated USING (
  is_published AND EXISTS (SELECT 1 FROM public.courses c WHERE c.id = course_id AND c.is_published)
);
CREATE POLICY questions_read ON public.quiz_questions FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM public.lessons l WHERE l.id = lesson_id AND l.is_published)
);
CREATE POLICY badges_read ON public.badges FOR SELECT TO authenticated USING (true);
CREATE POLICY rewards_read ON public.reward_items FOR SELECT TO authenticated USING (is_active);
-- quiz_options intentionally has no client grant/policy: is_correct stays server-only.

GRANT SELECT ON public.profiles, public.user_preferences, public.learning_progress,
  public.learning_plans, public.saved_vocabulary, public.review_history,
  public.xp_events, public.user_badges, public.reward_claims,
  public.quiz_attempts, public.speaking_attempts, public.writing_submissions TO authenticated;
DO $do$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'profiles','user_preferences','learning_progress','learning_plans',
    'saved_vocabulary','review_history','xp_events','user_badges',
    'reward_claims','quiz_attempts','speaking_attempts','writing_submissions'
  ] LOOP
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING ((select auth.uid()) = %I)', t || '_own_select', t, CASE WHEN t = 'profiles' THEN 'id' ELSE 'user_id' END);
  END LOOP;
END $do$;

-- Only low-trust preferences and saved words can be changed directly by clients.
GRANT INSERT, UPDATE, DELETE ON public.user_preferences, public.saved_vocabulary TO authenticated;
CREATE POLICY preferences_insert ON public.user_preferences FOR INSERT TO authenticated WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY preferences_update ON public.user_preferences FOR UPDATE TO authenticated USING ((select auth.uid()) = user_id) WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY preferences_delete ON public.user_preferences FOR DELETE TO authenticated USING ((select auth.uid()) = user_id);
CREATE POLICY saved_insert ON public.saved_vocabulary FOR INSERT TO authenticated WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY saved_update ON public.saved_vocabulary FOR UPDATE TO authenticated USING ((select auth.uid()) = user_id) WITH CHECK ((select auth.uid()) = user_id);
CREATE POLICY saved_delete ON public.saved_vocabulary FOR DELETE TO authenticated USING ((select auth.uid()) = user_id);
