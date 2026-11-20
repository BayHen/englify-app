-- Journey V2.5: extend the existing XP ledger; never create a second wallet.
ALTER TABLE public.xp_events DROP CONSTRAINT xp_events_source_type_check;
ALTER TABLE public.xp_events ADD CONSTRAINT xp_events_source_type_check CHECK (
 source_type IN ('lesson','quiz','review','speaking','writing','adjustment','quest','arena','journey_unit','journey_chapter','journey_course'));

CREATE TABLE public.learning_activity_days (
 user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, local_date date NOT NULL,
 timezone text NOT NULL DEFAULT 'UTC', first_activity_at timestamptz NOT NULL, last_activity_at timestamptz NOT NULL,
 activity_count integer NOT NULL DEFAULT 1 CHECK(activity_count>0), PRIMARY KEY(user_id,local_date)
);
CREATE INDEX learning_activity_days_recent_idx ON public.learning_activity_days(user_id,local_date DESC);
INSERT INTO public.learning_activity_days(user_id,local_date,timezone,first_activity_at,last_activity_at,activity_count)
SELECT user_id,(completed_at AT TIME ZONE 'UTC')::date,'UTC',min(completed_at),max(completed_at),count(*)::integer
FROM public.learning_progress
WHERE status IN ('completed','mastered') AND completed_at IS NOT NULL
GROUP BY user_id,(completed_at AT TIME ZONE 'UTC')::date;
CREATE TABLE public.journey_milestone_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 milestone_type text NOT NULL CHECK(milestone_type IN ('unit','chapter','course')),
 milestone_id uuid NOT NULL, curriculum_version integer NOT NULL, reward_xp smallint NOT NULL CHECK(reward_xp BETWEEN 0 AND 100),
 completed_at timestamptz NOT NULL DEFAULT now(), UNIQUE(user_id,milestone_type,milestone_id,curriculum_version)
);
CREATE INDEX journey_milestones_user_idx ON public.journey_milestone_events(user_id,completed_at DESC);
ALTER TABLE public.learning_activity_days ENABLE ROW LEVEL SECURITY; ALTER TABLE public.journey_milestone_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.learning_activity_days,public.journey_milestone_events FROM anon,authenticated;
GRANT ALL ON public.learning_activity_days,public.journey_milestone_events TO service_role;
GRANT SELECT ON public.learning_activity_days,public.journey_milestone_events TO authenticated;
CREATE POLICY learning_days_own ON public.learning_activity_days FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
CREATE POLICY journey_milestones_own ON public.journey_milestone_events FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));

CREATE FUNCTION public.englify_reconcile_journey_gamification() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE lesson record; unit_event uuid; chapter_event uuid; chapter uuid; version integer; total int; step int;
BEGIN
 IF NEW.status NOT IN ('completed','mastered') OR (TG_OP='UPDATE' AND OLD.status IN ('completed','mastered')) THEN RETURN NEW; END IF;
 INSERT INTO public.learning_activity_days(user_id,local_date,first_activity_at,last_activity_at)
 VALUES(NEW.user_id,(NEW.completed_at AT TIME ZONE 'UTC')::date,NEW.completed_at,NEW.completed_at)
 ON CONFLICT(user_id,local_date) DO UPDATE SET last_activity_at=greatest(learning_activity_days.last_activity_at,excluded.last_activity_at),activity_count=learning_activity_days.activity_count+1;
 SELECT l.unit_id,u.chapter_id,l.curriculum_version INTO lesson FROM public.lessons l JOIN public.learning_units u ON u.id=l.unit_id WHERE l.id=NEW.lesson_id;
 version:=coalesce(lesson.curriculum_version,1);
 IF EXISTS(SELECT 1 FROM public.lessons l WHERE l.unit_id=lesson.unit_id AND l.is_required AND l.is_published AND l.archived_at IS NULL)
 AND NOT EXISTS(SELECT 1 FROM public.lessons l LEFT JOIN public.learning_progress p ON p.lesson_id=l.id AND p.user_id=NEW.user_id
   WHERE l.unit_id=lesson.unit_id AND l.is_required AND l.is_published AND l.archived_at IS NULL AND coalesce(p.status,'') NOT IN ('completed','mastered')) THEN
   INSERT INTO public.journey_milestone_events(user_id,milestone_type,milestone_id,curriculum_version,reward_xp)
   VALUES(NEW.user_id,'unit',lesson.unit_id,version,20) ON CONFLICT DO NOTHING RETURNING id INTO unit_event;
   IF unit_event IS NOT NULL THEN INSERT INTO public.xp_events(user_id,source_type,source_id,amount) VALUES(NEW.user_id,'journey_unit',unit_event,20) ON CONFLICT DO NOTHING; END IF;
 END IF;
 chapter:=lesson.chapter_id;
 IF chapter IS NOT NULL
 AND EXISTS(SELECT 1 FROM public.learning_units u JOIN public.lessons l ON l.unit_id=u.id
   WHERE u.chapter_id=chapter AND u.is_required AND l.is_required AND u.is_published AND l.is_published AND l.archived_at IS NULL)
 AND NOT EXISTS(SELECT 1 FROM public.learning_units u JOIN public.lessons l ON l.unit_id=u.id
   LEFT JOIN public.learning_progress p ON p.lesson_id=l.id AND p.user_id=NEW.user_id WHERE u.chapter_id=chapter AND u.is_required AND l.is_required AND u.is_published AND l.is_published AND l.archived_at IS NULL AND coalesce(p.status,'') NOT IN ('completed','mastered')) THEN
   INSERT INTO public.journey_milestone_events(user_id,milestone_type,milestone_id,curriculum_version,reward_xp)
   VALUES(NEW.user_id,'chapter',chapter,version,50) ON CONFLICT DO NOTHING RETURNING id INTO chapter_event;
   IF chapter_event IS NOT NULL THEN INSERT INTO public.xp_events(user_id,source_type,source_id,amount) VALUES(NEW.user_id,'journey_chapter',chapter_event,50) ON CONFLICT DO NOTHING; END IF;
 END IF;
 SELECT level_xp_step INTO step FROM public.gamification_config WHERE id=1; SELECT greatest(0,coalesce(sum(amount),0)) INTO total FROM public.xp_events WHERE user_id=NEW.user_id;
 INSERT INTO public.user_levels(user_id,total_xp,level) VALUES(NEW.user_id,total,total/coalesce(step,100)+1)
 ON CONFLICT(user_id) DO UPDATE SET total_xp=excluded.total_xp,level=excluded.level,updated_at=now();
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_reconcile_journey_gamification() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER journey_gamification_after_progress AFTER INSERT OR UPDATE OF status ON public.learning_progress
FOR EACH ROW EXECUTE FUNCTION public.englify_reconcile_journey_gamification();

CREATE FUNCTION public.englify_learning_streak(p_today date DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); today date:=coalesce(p_today,(now() AT TIME ZONE 'UTC')::date); current_count int:=0; longest int:=0; run int:=0; previous date; d date;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 FOR d IN SELECT local_date FROM public.learning_activity_days WHERE user_id=uid AND local_date<=today ORDER BY local_date LOOP
  IF previous IS NULL OR d=previous+1 THEN run:=run+1; ELSE run:=1; END IF; longest:=greatest(longest,run); previous:=d;
 END LOOP;
 IF previous IN (today,today-1) THEN current_count:=run; END IF;
 RETURN jsonb_build_object('current_streak',current_count,'longest_streak',longest,'last_activity_date',previous,'total_active_days',(SELECT count(*) FROM public.learning_activity_days WHERE user_id=uid));
END $$;
CREATE FUNCTION public.englify_journey_gamification() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE base jsonb;
BEGIN base:=public.englify_gamification_overview(); RETURN base||jsonb_build_object('learning_streak',public.englify_learning_streak(NULL),
 'recent_milestones',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY completed_at DESC) FROM (SELECT milestone_type,milestone_id,reward_xp,completed_at FROM public.journey_milestone_events WHERE user_id=auth.uid() ORDER BY completed_at DESC LIMIT 10)x),'[]'));
END $$;
REVOKE ALL ON FUNCTION public.englify_learning_streak(date),public.englify_journey_gamification() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_learning_streak(date),public.englify_journey_gamification() TO authenticated;
