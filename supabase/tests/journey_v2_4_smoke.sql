BEGIN;
INSERT INTO auth.users(id) VALUES('b5111111-1111-4111-8111-111111111111'),('b5222222-2222-4222-8222-222222222222');
INSERT INTO public.courses(id,slug,title,level,is_published) VALUES('b5100000-0000-4000-8000-000000000001','checkpoint-v24','Checkpoint',24,true);
INSERT INTO public.learning_units(id,course_id,slug,title,position,is_published) VALUES('b5100000-0000-4000-8000-000000000002','b5100000-0000-4000-8000-000000000001','unit','Unit',1,true);
INSERT INTO public.lessons(id,course_id,unit_id,slug,title,objective,position,is_published,lesson_kind,xp_reward) VALUES
('b5100000-0000-4000-8000-000000000003','b5100000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000002','required','Required','Learn',1,true,'lesson',0),
('b5100000-0000-4000-8000-000000000004','b5100000-0000-4000-8000-000000000001','b5100000-0000-4000-8000-000000000002','checkpoint','Checkpoint','Verify',2,true,'checkpoint',20);
INSERT INTO public.quiz_questions(id,lesson_id,position,kind,prompt,payload,is_published) VALUES('b5100000-0000-4000-8000-000000000005','b5100000-0000-4000-8000-000000000004',1,'fill_blank','Type yes','{}',false);
INSERT INTO public.quiz_answer_keys(question_id,answer) VALUES('b5100000-0000-4000-8000-000000000005','["yes"]');
UPDATE public.quiz_questions SET is_published=true WHERE id='b5100000-0000-4000-8000-000000000005';
INSERT INTO public.journey_checkpoint_configs(lesson_id,unit_id,objectives,is_published) VALUES('b5100000-0000-4000-8000-000000000004','b5100000-0000-4000-8000-000000000002','[{"code":"agreement"}]',true);
INSERT INTO public.learning_progress(user_id,lesson_id,status,completed_at) VALUES('b5111111-1111-4111-8111-111111111111','b5100000-0000-4000-8000-000000000003','completed',now());
SELECT set_config('request.jwt.claim.sub','b5111111-1111-4111-8111-111111111111',true); SET LOCAL ROLE authenticated;
DO $$ DECLARE r jsonb; request uuid:='b5100000-0000-4000-8000-000000000099'; BEGIN
 IF NOT public.englify_checkpoint_eligible('b5100000-0000-4000-8000-000000000004') THEN RAISE EXCEPTION 'Eligible checkpoint rejected'; END IF;
 r:=public.englify_submit_checkpoint('b5100000-0000-4000-8000-000000000004',request,'{"b5100000-0000-4000-8000-000000000005":"yes"}',NULL);
 IF NOT (r->'checkpoint'->>'passed')::boolean OR (r->'checkpoint'->>'score_percent')::numeric<>100 THEN RAISE EXCEPTION 'Checkpoint grade invalid %',r; END IF;
 r:=public.englify_submit_checkpoint('b5100000-0000-4000-8000-000000000004',request,'{"b5100000-0000-4000-8000-000000000005":"yes"}',NULL);
 IF (SELECT count(*) FROM public.xp_events WHERE user_id=auth.uid() AND source_type='lesson')<>1 THEN RAISE EXCEPTION 'Checkpoint XP duplicated'; END IF;
END $$;
RESET ROLE; SELECT set_config('request.jwt.claim.sub','b5222222-2222-4222-8222-222222222222',true); SET LOCAL ROLE authenticated;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.journey_checkpoint_attempts) OR EXISTS(SELECT 1 FROM public.journey_mastery_progress) THEN RAISE EXCEPTION 'Checkpoint RLS leaked'; END IF; END $$;
ROLLBACK;
