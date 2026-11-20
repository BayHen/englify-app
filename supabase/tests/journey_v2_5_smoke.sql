BEGIN;
INSERT INTO auth.users(id) VALUES('b6111111-1111-4111-8111-111111111111'),('b6222222-2222-4222-8222-222222222222');
INSERT INTO public.courses(id,slug,title,level,is_published) VALUES('b6100000-0000-4000-8000-000000000001','gamification-v25','Gamification',25,true);
INSERT INTO public.learning_units(id,course_id,slug,title,position,is_published) VALUES('b6100000-0000-4000-8000-000000000002','b6100000-0000-4000-8000-000000000001','unit','Unit',1,true);
INSERT INTO public.lessons(id,course_id,unit_id,slug,title,objective,position,is_published,xp_reward) VALUES('b6100000-0000-4000-8000-000000000003','b6100000-0000-4000-8000-000000000001','b6100000-0000-4000-8000-000000000002','lesson','Lesson','Learn',1,true,10);
INSERT INTO public.learning_progress(user_id,lesson_id,status,completed_at) VALUES('b6111111-1111-4111-8111-111111111111','b6100000-0000-4000-8000-000000000003','completed',now());
UPDATE public.learning_progress SET status='mastered' WHERE user_id='b6111111-1111-4111-8111-111111111111' AND lesson_id='b6100000-0000-4000-8000-000000000003';
DO $$ BEGIN
 IF (SELECT count(*) FROM public.journey_milestone_events WHERE user_id='b6111111-1111-4111-8111-111111111111')<>1 THEN RAISE EXCEPTION 'Unit milestone missing or duplicated'; END IF;
 IF (SELECT count(*) FROM public.xp_events WHERE user_id='b6111111-1111-4111-8111-111111111111' AND source_type='journey_unit')<>1 THEN RAISE EXCEPTION 'Milestone XP missing or duplicated'; END IF;
 IF (SELECT count(*) FROM public.learning_activity_days WHERE user_id='b6111111-1111-4111-8111-111111111111')<>1 THEN RAISE EXCEPTION 'Streak day duplicated'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','b6111111-1111-4111-8111-111111111111',true); SET LOCAL ROLE authenticated;
DO $$ DECLARE s jsonb; BEGIN s:=public.englify_learning_streak(NULL); IF (s->>'current_streak')::int<>1 THEN RAISE EXCEPTION 'Streak invalid %',s; END IF; END $$;
RESET ROLE; SELECT set_config('request.jwt.claim.sub','b6222222-2222-4222-8222-222222222222',true); SET LOCAL ROLE authenticated;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.learning_activity_days) OR EXISTS(SELECT 1 FROM public.journey_milestone_events) THEN RAISE EXCEPTION 'Gamification RLS leaked'; END IF; END $$;
ROLLBACK;
