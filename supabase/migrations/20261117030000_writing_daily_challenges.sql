-- Writing V2.3: timezone-aware daily assignments, atomic XP, streaks and milestones.
-- Additive only: existing exercises, submissions, feedback and rewards remain unchanged.

ALTER TABLE public.user_preferences
  ADD COLUMN writing_timezone text NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
  ADD COLUMN pending_writing_timezone text,
  ADD COLUMN writing_timezone_effective_at timestamptz;

CREATE FUNCTION public.englify_protect_writing_timezone()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF current_user IN ('authenticated','anon') THEN
    IF TG_OP='INSERT' AND (NEW.writing_timezone<>'Asia/Ho_Chi_Minh'
      OR NEW.pending_writing_timezone IS NOT NULL OR NEW.writing_timezone_effective_at IS NOT NULL) THEN
      RAISE EXCEPTION 'Use the Writing timezone operation' USING ERRCODE='42501';
    ELSIF TG_OP='UPDATE' AND (NEW.writing_timezone IS DISTINCT FROM OLD.writing_timezone
      OR NEW.pending_writing_timezone IS DISTINCT FROM OLD.pending_writing_timezone
      OR NEW.writing_timezone_effective_at IS DISTINCT FROM OLD.writing_timezone_effective_at) THEN
      RAISE EXCEPTION 'Use the Writing timezone operation' USING ERRCODE='42501';
    END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_protect_writing_timezone() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER protect_writing_timezone BEFORE INSERT OR UPDATE ON public.user_preferences
  FOR EACH ROW EXECUTE FUNCTION public.englify_protect_writing_timezone();

CREATE TABLE public.writing_daily_settings (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id=1),
  enabled boolean NOT NULL DEFAULT true,
  xp_by_level jsonb NOT NULL DEFAULT '{"A1":10,"A2":15,"B1":20,"B2":25,"C1":30}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT writing_daily_settings_xp_check CHECK (
    jsonb_typeof(xp_by_level)='object'
    AND (xp_by_level->>'A1')::integer BETWEEN 1 AND 100
    AND (xp_by_level->>'A2')::integer BETWEEN 1 AND 100
    AND (xp_by_level->>'B1')::integer BETWEEN 1 AND 100
    AND (xp_by_level->>'B2')::integer BETWEEN 1 AND 100
    AND (xp_by_level->>'C1')::integer BETWEEN 1 AND 100)
);
INSERT INTO public.writing_daily_settings(id) VALUES(1) ON CONFLICT(id) DO NOTHING;
ALTER TABLE public.writing_daily_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY writing_daily_settings_admin ON public.writing_daily_settings FOR ALL TO authenticated
  USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin());
REVOKE ALL ON public.writing_daily_settings FROM PUBLIC,anon,authenticated;
GRANT SELECT,UPDATE ON public.writing_daily_settings TO authenticated;
GRANT ALL ON public.writing_daily_settings TO service_role;
CREATE TRIGGER trg_writing_daily_settings_updated_at BEFORE UPDATE ON public.writing_daily_settings
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TABLE public.writing_daily_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  exercise_id uuid NOT NULL REFERENCES public.writing_exercises(id) ON DELETE RESTRICT,
  challenge_date date NOT NULL,
  timezone_name text NOT NULL,
  assigned_cefr_level text NOT NULL CHECK (assigned_cefr_level IN ('A1','A2','B1','B2','C1')),
  xp_reward integer NOT NULL CHECK (xp_reward BETWEEN 1 AND 100),
  assigned_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(id,user_id),
  UNIQUE(user_id,challenge_date)
);
CREATE INDEX writing_daily_assignments_user_recent_idx
  ON public.writing_daily_assignments(user_id,challenge_date DESC);
CREATE INDEX writing_daily_assignments_exercise_recent_idx
  ON public.writing_daily_assignments(user_id,exercise_id,challenge_date DESC);
ALTER TABLE public.writing_daily_assignments ENABLE ROW LEVEL SECURITY;
CREATE POLICY writing_daily_assignments_own_read ON public.writing_daily_assignments FOR SELECT TO authenticated
  USING ((select auth.uid())=user_id);
REVOKE ALL ON public.writing_daily_assignments FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.writing_daily_assignments TO authenticated;
GRANT ALL ON public.writing_daily_assignments TO service_role;

ALTER TABLE public.writing_submissions ADD CONSTRAINT writing_submissions_id_user_unique UNIQUE(id,user_id);

CREATE TABLE public.writing_daily_completions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assignment_id uuid NOT NULL,
  user_id uuid NOT NULL,
  submission_id uuid NOT NULL,
  challenge_date date NOT NULL,
  awarded_xp integer NOT NULL CHECK (awarded_xp BETWEEN 1 AND 100),
  completed_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(assignment_id,user_id) REFERENCES public.writing_daily_assignments(id,user_id) ON DELETE RESTRICT,
  FOREIGN KEY(submission_id,user_id) REFERENCES public.writing_submissions(id,user_id) ON DELETE RESTRICT,
  UNIQUE(assignment_id),
  UNIQUE(submission_id),
  UNIQUE(user_id,challenge_date)
);
CREATE INDEX writing_daily_completions_user_recent_idx
  ON public.writing_daily_completions(user_id,challenge_date DESC);
ALTER TABLE public.writing_daily_completions ENABLE ROW LEVEL SECURITY;
CREATE POLICY writing_daily_completions_own_read ON public.writing_daily_completions FOR SELECT TO authenticated
  USING ((select auth.uid())=user_id);
REVOKE ALL ON public.writing_daily_completions FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.writing_daily_completions TO authenticated;
GRANT ALL ON public.writing_daily_completions TO service_role;

CREATE TABLE public.writing_milestone_rules (
  badge_id uuid PRIMARY KEY REFERENCES public.badges(id) ON DELETE CASCADE,
  metric text NOT NULL CHECK (metric IN ('writing_streak','writing_completed_days')),
  target integer NOT NULL CHECK (target BETWEEN 1 AND 10000)
);
ALTER TABLE public.writing_milestone_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY writing_milestone_rules_read ON public.writing_milestone_rules FOR SELECT TO authenticated USING (true);
CREATE POLICY writing_milestone_rules_admin ON public.writing_milestone_rules FOR ALL TO authenticated
  USING (public.englify_is_admin()) WITH CHECK (public.englify_is_admin());
REVOKE ALL ON public.writing_milestone_rules FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.writing_milestone_rules TO authenticated;
GRANT ALL ON public.writing_milestone_rules TO service_role;

INSERT INTO public.badges(id,code,title,description,is_published) VALUES
('53000000-0000-4000-8000-000000000001','writing-first-step','First Step','Complete your first Daily Writing Challenge.',true),
('53000000-0000-4000-8000-000000000003','writing-three-day','Three-Day Writer','Complete Daily Writing Challenges for three consecutive days.',true),
('53000000-0000-4000-8000-000000000007','writing-weekly','Weekly Writer','Reach a seven-day Writing streak.',true),
('53000000-0000-4000-8000-000000000014','writing-consistent','Consistent Writer','Reach a fourteen-day Writing streak.',true),
('53000000-0000-4000-8000-000000000030','writing-champion','Writing Champion','Reach a thirty-day Writing streak.',true),
('53000000-0000-4000-8000-000000000050','writing-dedicated','Dedicated Writer','Complete fifty Daily Writing Challenges.',true)
ON CONFLICT(code) DO UPDATE SET title=excluded.title,description=excluded.description,is_published=true,archived_at=NULL;
INSERT INTO public.writing_milestone_rules(badge_id,metric,target) VALUES
('53000000-0000-4000-8000-000000000001','writing_completed_days',1),
('53000000-0000-4000-8000-000000000003','writing_streak',3),
('53000000-0000-4000-8000-000000000007','writing_streak',7),
('53000000-0000-4000-8000-000000000014','writing_streak',14),
('53000000-0000-4000-8000-000000000030','writing_streak',30),
('53000000-0000-4000-8000-000000000050','writing_completed_days',50)
ON CONFLICT(badge_id) DO UPDATE SET metric=excluded.metric,target=excluded.target;

CREATE FUNCTION public.englify_writing_local_date(p_timezone text,p_at timestamptz)
RETURNS date LANGUAGE sql STABLE SET search_path='' AS $$
  SELECT (p_at AT TIME ZONE p_timezone)::date
$$;
REVOKE ALL ON FUNCTION public.englify_writing_local_date(text,timestamptz) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.englify_resolve_writing_timezone(p_user_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_timezone text; v_pending text; v_effective timestamptz;
BEGIN
  SELECT writing_timezone,pending_writing_timezone,writing_timezone_effective_at
    INTO v_timezone,v_pending,v_effective FROM public.user_preferences WHERE user_id=p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO public.user_preferences(user_id) VALUES(p_user_id)
      ON CONFLICT(user_id) DO NOTHING;
    v_timezone:='Asia/Ho_Chi_Minh';
  END IF;
  IF v_pending IS NOT NULL AND v_effective IS NOT NULL AND transaction_timestamp()>=v_effective THEN
    UPDATE public.user_preferences SET writing_timezone=v_pending,pending_writing_timezone=NULL,
      writing_timezone_effective_at=NULL,updated_at=now() WHERE user_id=p_user_id
      RETURNING writing_timezone INTO v_timezone;
  END IF;
  RETURN coalesce(v_timezone,'Asia/Ho_Chi_Minh');
END $$;
REVOKE ALL ON FUNCTION public.englify_resolve_writing_timezone(uuid) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.englify_set_writing_timezone(p_timezone text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_current text; v_effective timestamptz;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_timezone IS NULL OR length(p_timezone) NOT BETWEEN 1 AND 64 OR NOT EXISTS(
    SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name=p_timezone) THEN
    RAISE EXCEPTION 'Invalid IANA timezone' USING ERRCODE='22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('writing-daily:'||v_uid::text));
  v_current:=public.englify_resolve_writing_timezone(v_uid);
  IF p_timezone=v_current THEN
    UPDATE public.user_preferences SET pending_writing_timezone=NULL,writing_timezone_effective_at=NULL,updated_at=now()
      WHERE user_id=v_uid;
    RETURN jsonb_build_object('timezone',v_current,'pending_timezone',NULL,'effective_at',NULL);
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.writing_daily_assignments WHERE user_id=v_uid) THEN
    UPDATE public.user_preferences SET writing_timezone=p_timezone,pending_writing_timezone=NULL,
      writing_timezone_effective_at=NULL,updated_at=now() WHERE user_id=v_uid;
    RETURN jsonb_build_object('timezone',p_timezone,'pending_timezone',NULL,'effective_at',NULL);
  END IF;
  v_effective:=((public.englify_writing_local_date(v_current,transaction_timestamp())+1)::timestamp AT TIME ZONE v_current);
  UPDATE public.user_preferences SET pending_writing_timezone=p_timezone,
    writing_timezone_effective_at=coalesce(writing_timezone_effective_at,v_effective),updated_at=now() WHERE user_id=v_uid
    RETURNING writing_timezone_effective_at INTO v_effective;
  RETURN jsonb_build_object('timezone',v_current,'pending_timezone',p_timezone,'effective_at',v_effective);
END $$;
REVOKE ALL ON FUNCTION public.englify_set_writing_timezone(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_set_writing_timezone(text) TO authenticated;

CREATE FUNCTION public.englify_writing_streak_summary(p_user_id uuid,p_today date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_last date; v_cursor date; v_current integer:=0; v_longest integer:=0; v_total integer:=0;
BEGIN
  SELECT max(challenge_date),count(*)::integer INTO v_last,v_total
    FROM public.writing_daily_completions WHERE user_id=p_user_id;
  SELECT coalesce(max(run_length),0)::integer INTO v_longest FROM (
    SELECT count(*) AS run_length FROM (
      SELECT challenge_date,challenge_date-(row_number() OVER(ORDER BY challenge_date))::integer AS run_group
      FROM public.writing_daily_completions WHERE user_id=p_user_id) ordered_days GROUP BY run_group) runs;
  IF v_last IS NOT NULL AND v_last>=p_today-1 THEN
    v_cursor:=v_last;
    WHILE EXISTS(SELECT 1 FROM public.writing_daily_completions WHERE user_id=p_user_id AND challenge_date=v_cursor) LOOP
      v_current:=v_current+1; v_cursor:=v_cursor-1;
    END LOOP;
  END IF;
  RETURN jsonb_build_object('current_streak',v_current,'longest_streak',v_longest,
    'last_completed_date',v_last,'total_completed_days',v_total);
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_streak_summary(uuid,date) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.englify_writing_daily_overview()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_timezone text; v_today date; v_level text; v_enabled boolean;
  v_assignment public.writing_daily_assignments%ROWTYPE; v_candidate record; v_challenge jsonb;
  v_streak jsonb; v_calendar jsonb; v_milestones jsonb; v_first date;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('writing-daily:'||v_uid::text));
  v_timezone:=public.englify_resolve_writing_timezone(v_uid);
  v_today:=public.englify_writing_local_date(v_timezone,transaction_timestamp());
  SELECT writing_cefr_level INTO v_level FROM public.user_preferences WHERE user_id=v_uid;
  v_level:=coalesce(v_level,'A1');
  SELECT enabled INTO v_enabled FROM public.writing_daily_settings WHERE id=1;
  SELECT * INTO v_assignment FROM public.writing_daily_assignments
    WHERE user_id=v_uid AND challenge_date=v_today;
  IF NOT FOUND AND coalesce(v_enabled,false) THEN
    SELECT e.id,e.cefr_level,(s.xp_by_level->>e.cefr_level)::integer AS xp_reward INTO v_candidate
    FROM public.writing_exercises e CROSS JOIN public.writing_daily_settings s
      LEFT JOIN public.writing_topics t ON t.id=e.topic_id
    WHERE s.id=1 AND e.is_published AND e.archived_at IS NULL
      AND (e.topic_id IS NULL OR (t.is_published AND t.archived_at IS NULL))
    ORDER BY abs(array_position(ARRAY['A1','A2','B1','B2','C1'],e.cefr_level)-array_position(ARRAY['A1','A2','B1','B2','C1'],v_level)),
      EXISTS(SELECT 1 FROM public.writing_daily_assignments previous
        WHERE previous.user_id=v_uid AND previous.challenge_date=v_today-1 AND previous.exercise_id=e.id),
      EXISTS(SELECT 1 FROM public.writing_daily_assignments recent JOIN public.writing_daily_completions completion
          ON completion.assignment_id=recent.id
        WHERE recent.user_id=v_uid AND recent.exercise_id=e.id AND recent.challenge_date>=v_today-7),
      md5(v_uid::text||':'||v_today::text||':'||e.id::text)
    LIMIT 1;
    IF v_candidate.id IS NOT NULL THEN
      INSERT INTO public.writing_daily_assignments(user_id,exercise_id,challenge_date,timezone_name,assigned_cefr_level,xp_reward)
      VALUES(v_uid,v_candidate.id,v_today,v_timezone,v_candidate.cefr_level,v_candidate.xp_reward)
      ON CONFLICT(user_id,challenge_date) DO NOTHING;
      SELECT * INTO v_assignment FROM public.writing_daily_assignments WHERE user_id=v_uid AND challenge_date=v_today;
    END IF;
  END IF;
  IF v_assignment.id IS NOT NULL THEN
    SELECT jsonb_build_object('assignment_id',v_assignment.id,'id',e.id,'challenge_date',v_assignment.challenge_date,
      'timezone',v_assignment.timezone_name,'cefr_level',v_assignment.assigned_cefr_level,
      'xp_reward',v_assignment.xp_reward,'exercise_id',e.id,'topic_id',e.topic_id,
      'topic',coalesce(t.title,'General'),'topic_title',t.title,'title',e.title,'prompt',e.prompt,'instructions',e.instructions,
      'kind',e.kind,'tokens',e.tokens,'hint',e.hint,'min_words',e.min_words,'recommended_words',e.recommended_words,
      'estimated_minutes',e.estimated_minutes,'difficulty',e.difficulty,'completed',c.id IS NOT NULL,
      'completion',CASE WHEN c.id IS NULL THEN NULL ELSE jsonb_build_object('id',c.id,'submission_id',c.submission_id,
        'awarded_xp',c.awarded_xp,'completed_at',c.completed_at) END)
      INTO v_challenge FROM public.writing_exercises e LEFT JOIN public.writing_topics t ON t.id=e.topic_id
      LEFT JOIN public.writing_daily_completions c ON c.assignment_id=v_assignment.id
      WHERE e.id=v_assignment.exercise_id AND e.is_published AND e.archived_at IS NULL
      AND (e.topic_id IS NULL OR (t.is_published AND t.archived_at IS NULL));
  END IF;
  v_streak:=public.englify_writing_streak_summary(v_uid,v_today);
  SELECT min(challenge_date) INTO v_first FROM public.writing_daily_assignments WHERE user_id=v_uid;
  SELECT coalesce(jsonb_agg(jsonb_build_object('date',day_value::date,'status',CASE
      WHEN completion.id IS NOT NULL THEN 'completed' WHEN day_value>v_today THEN 'future'
      WHEN day_value=v_today THEN 'today' WHEN v_first IS NULL OR day_value<v_first THEN 'unavailable' ELSE 'missed' END)
      ORDER BY day_value),'[]'::jsonb) INTO v_calendar
    FROM generate_series(v_today-10,v_today+3,interval '1 day') series(day_value)
    LEFT JOIN public.writing_daily_completions completion ON completion.user_id=v_uid
      AND completion.challenge_date=series.day_value::date;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',b.id,'title',b.title,'description',b.description,
      'metric',r.metric,'target',r.target,'progress',CASE WHEN r.metric='writing_streak'
        THEN least((v_streak->>'current_streak')::integer,r.target)
        ELSE least((v_streak->>'total_completed_days')::integer,r.target) END,
      'unlocked',ub.id IS NOT NULL,'unlocked_at',ub.awarded_at) ORDER BY r.target,b.title),'[]'::jsonb)
    INTO v_milestones FROM public.writing_milestone_rules r JOIN public.badges b ON b.id=r.badge_id
      LEFT JOIN public.user_badges ub ON ub.badge_id=b.id AND ub.user_id=v_uid
    WHERE b.is_published AND b.archived_at IS NULL;
  RETURN jsonb_build_object('timezone',v_timezone,'local_date',v_today,'selected_cefr_level',v_level,
    'enabled',coalesce(v_enabled,false),'challenge',v_challenge,'streak',v_streak,
    'calendar',v_calendar,'milestones',v_milestones);
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_daily_overview() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_daily_overview() TO authenticated;

CREATE FUNCTION public.englify_submit_daily_writing(p_assignment_id uuid,p_request_id uuid,p_body text,
  p_grammar_check boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_timezone text; v_today date; v_assignment public.writing_daily_assignments%ROWTYPE;
  v_completion public.writing_daily_completions%ROWTYPE; v_exercise record; v_submission jsonb;
  v_valid boolean:=false; v_words integer:=0; v_earned integer:=0; v_total integer; v_step integer; v_level integer;
  v_streak jsonb; v_badge record; v_progress integer; v_badge_award uuid; v_overview jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_assignment_id IS NULL OR p_request_id IS NULL OR length(btrim(coalesce(p_body,''))) NOT BETWEEN 1 AND 5000 THEN
    RAISE EXCEPTION 'Write 1-5000 characters before submitting' USING ERRCODE='22023'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('writing-daily:'||v_uid::text));
  v_timezone:=public.englify_resolve_writing_timezone(v_uid);
  v_today:=public.englify_writing_local_date(v_timezone,transaction_timestamp());
  SELECT * INTO v_assignment FROM public.writing_daily_assignments
    WHERE id=p_assignment_id AND user_id=v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Daily Writing Challenge not found' USING ERRCODE='P0002'; END IF;
  IF v_assignment.challenge_date<>v_today THEN
    RAISE SQLSTATE 'PT409' USING MESSAGE='This Daily Writing Challenge has expired'; END IF;
  SELECT * INTO v_completion FROM public.writing_daily_completions WHERE assignment_id=v_assignment.id;
  IF FOUND THEN
    v_overview:=public.englify_writing_daily_overview();
    RETURN jsonb_build_object('completed',true,'newly_completed',false,'earned_xp',0,
      'submission',public.englify_writing_submission(v_completion.submission_id),'overview',v_overview);
  END IF;
  SELECT e.kind,e.min_words,k.accepted_answers INTO v_exercise FROM public.writing_exercises e
    LEFT JOIN public.writing_answer_keys k ON k.exercise_id=e.id
    WHERE e.id=v_assignment.exercise_id AND e.is_published AND e.archived_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Assigned Writing exercise is unavailable' USING ERRCODE='P0002'; END IF;
  v_submission:=public.englify_submit_writing(p_request_id,v_assignment.exercise_id,p_body,p_grammar_check);
  SELECT count(*)::integer INTO v_words FROM regexp_split_to_table(btrim(p_body),'\s+') word;
  IF coalesce(jsonb_array_length(v_exercise.accepted_answers),0)>0 THEN
    v_valid:=v_submission#>>'{feedback,rule_result}'='matched';
  ELSE
    v_valid:=v_words>=coalesce(v_exercise.min_words,1);
  END IF;
  IF NOT v_valid THEN
    RETURN jsonb_build_object('completed',false,'newly_completed',false,'earned_xp',0,
      'submission',v_submission,'overview',public.englify_writing_daily_overview());
  END IF;
  SELECT level_xp_step INTO v_step FROM public.gamification_config WHERE id=1;
  IF v_step IS NULL OR v_step<=0 THEN RAISE EXCEPTION 'Gamification rules unavailable' USING ERRCODE='P0001'; END IF;
  INSERT INTO public.writing_daily_completions(assignment_id,user_id,submission_id,challenge_date,awarded_xp)
    VALUES(v_assignment.id,v_uid,(v_submission->>'id')::uuid,v_assignment.challenge_date,v_assignment.xp_reward)
    RETURNING * INTO v_completion;
  INSERT INTO public.xp_events(user_id,source_type,source_id,amount)
    VALUES(v_uid,'writing',v_assignment.id,v_assignment.xp_reward)
    ON CONFLICT(user_id,source_type,source_id) DO NOTHING RETURNING amount INTO v_earned;
  v_earned:=coalesce(v_earned,0);
  INSERT INTO public.reward_notifications(user_id,kind,source_id,title,message)
    VALUES(v_uid,'xp',v_assignment.id,'Daily Writing completed','You earned '||v_assignment.xp_reward||' XP.')
    ON CONFLICT(user_id,kind,source_id) DO NOTHING;
  SELECT greatest(0,coalesce(sum(amount),0)) INTO v_total FROM public.xp_events WHERE user_id=v_uid;
  v_level:=v_total/v_step+1;
  INSERT INTO public.user_levels(user_id,total_xp,level) VALUES(v_uid,v_total,v_level)
    ON CONFLICT(user_id) DO UPDATE SET total_xp=excluded.total_xp,level=excluded.level,updated_at=now();
  v_streak:=public.englify_writing_streak_summary(v_uid,v_today);
  FOR v_badge IN SELECT b.id,b.title,r.metric,r.target FROM public.writing_milestone_rules r
    JOIN public.badges b ON b.id=r.badge_id WHERE b.is_published AND b.archived_at IS NULL ORDER BY r.target,b.id LOOP
    v_progress:=CASE WHEN v_badge.metric='writing_streak' THEN (v_streak->>'current_streak')::integer
      ELSE (v_streak->>'total_completed_days')::integer END;
    IF v_progress<v_badge.target THEN CONTINUE; END IF;
    INSERT INTO public.user_badges(user_id,badge_id) VALUES(v_uid,v_badge.id)
      ON CONFLICT(user_id,badge_id) DO NOTHING RETURNING id INTO v_badge_award;
    IF v_badge_award IS NOT NULL THEN
      INSERT INTO public.reward_notifications(user_id,kind,source_id,title,message)
        VALUES(v_uid,'badge',v_badge_award,v_badge.title,'Writing milestone unlocked!')
        ON CONFLICT(user_id,kind,source_id) DO NOTHING;
    END IF;
    v_badge_award:=NULL;
  END LOOP;
  v_overview:=public.englify_writing_daily_overview();
  RETURN jsonb_build_object('completed',true,'newly_completed',true,'earned_xp',v_earned,
    'submission',v_submission,'overview',v_overview);
END $$;
REVOKE ALL ON FUNCTION public.englify_submit_daily_writing(uuid,uuid,text,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_submit_daily_writing(uuid,uuid,text,boolean) TO authenticated;

