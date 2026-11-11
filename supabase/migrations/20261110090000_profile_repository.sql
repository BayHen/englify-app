-- Keep profile ownership safe when clients update through PostgREST.
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_avatar_owned_path CHECK (
    avatar_url IS NULL OR (
      split_part(avatar_url, '/', 1) = id::text
      AND avatar_url LIKE '%.jpg'
      AND char_length(avatar_url) <= 150
    )
  );

-- Preserve the first onboarding completion timestamp in one transaction.
CREATE FUNCTION public.englify_save_onboarding(
  p_learning_goal text,
  p_initial_proficiency text,
  p_daily_goal_minutes integer
) RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  current_user_id uuid := auth.uid();
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;
  IF p_learning_goal NOT IN ('conversation','travel','work','exams')
     OR p_initial_proficiency NOT IN ('beginner','intermediate','advanced')
     OR p_daily_goal_minutes NOT BETWEEN 1 AND 180 THEN
    RAISE EXCEPTION 'Invalid onboarding preferences' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.user_preferences
    (user_id, learning_goal, initial_proficiency, daily_goal_minutes, onboarding_completed_at)
  VALUES
    (current_user_id, p_learning_goal, p_initial_proficiency, p_daily_goal_minutes, now())
  ON CONFLICT (user_id) DO UPDATE SET
    learning_goal = EXCLUDED.learning_goal,
    initial_proficiency = EXCLUDED.initial_proficiency,
    daily_goal_minutes = EXCLUDED.daily_goal_minutes,
    onboarding_completed_at = COALESCE(public.user_preferences.onboarding_completed_at, EXCLUDED.onboarding_completed_at);
END $$;
REVOKE ALL ON FUNCTION public.englify_save_onboarding(text, text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_save_onboarding(text, text, integer) TO authenticated;
