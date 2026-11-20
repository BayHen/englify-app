BEGIN;

INSERT INTO public.gamification_config(id,level_xp_step,lesson_multiplier_percent)
VALUES(1,100,100) ON CONFLICT(id) DO NOTHING;

INSERT INTO auth.users(id) VALUES
  ('b2111111-1111-4111-8111-111111111111'),
  ('b2222222-2222-4222-8222-222222222222');
INSERT INTO public.admin_members(user_id) VALUES('b2222222-2222-4222-8222-222222222222');

INSERT INTO public.courses(id,slug,title,level,cefr_level,is_published)
VALUES('b2100000-0000-4000-8000-000000000001','journey-v21','Journey V2.1',1,'A1',true);
INSERT INTO public.journey_chapters(id,course_id,slug,title,position,is_published)
VALUES('b2100000-0000-4000-8000-000000000002','b2100000-0000-4000-8000-000000000001','getting-started','Getting Started',1,true);
INSERT INTO public.learning_units(id,course_id,chapter_id,slug,title,position,is_published)
VALUES('b2100000-0000-4000-8000-000000000003','b2100000-0000-4000-8000-000000000001','b2100000-0000-4000-8000-000000000002','introductions','Introducing Yourself',1,true);
INSERT INTO public.lessons(id,course_id,unit_id,slug,position,title,objective,xp_reward,is_published,is_required,lesson_kind)
VALUES
 ('b2100000-0000-4000-8000-000000000011','b2100000-0000-4000-8000-000000000001','b2100000-0000-4000-8000-000000000003','greetings',1,'Greetings','Use common greetings',10,true,true,'lesson'),
 ('b2100000-0000-4000-8000-000000000012','b2100000-0000-4000-8000-000000000001','b2100000-0000-4000-8000-000000000003','personal-info',2,'Personal Information','Share basic information',10,true,false,'lesson'),
 ('b2100000-0000-4000-8000-000000000013','b2100000-0000-4000-8000-000000000001','b2100000-0000-4000-8000-000000000003','unit-checkpoint',3,'Unit Checkpoint','Verify the unit',20,true,true,'checkpoint'),
 ('b2100000-0000-4000-8000-000000000014','b2100000-0000-4000-8000-000000000001','b2100000-0000-4000-8000-000000000003','future-lesson',4,'Future Lesson','Unpublished future content',10,false,true,'lesson');
INSERT INTO public.journey_lesson_prerequisites(lesson_id,prerequisite_lesson_id) VALUES
 ('b2100000-0000-4000-8000-000000000012','b2100000-0000-4000-8000-000000000011'),
 ('b2100000-0000-4000-8000-000000000013','b2100000-0000-4000-8000-000000000012');

SELECT set_config('request.jwt.claim.sub','b2111111-1111-4111-8111-111111111111',true);
DO $$ BEGIN
  IF public.englify_lesson_state('b2100000-0000-4000-8000-000000000011')<>'available'
    OR public.englify_lesson_state('b2100000-0000-4000-8000-000000000012')<>'locked'
    OR public.englify_lesson_state('b2100000-0000-4000-8000-000000000013')<>'locked'
  THEN RAISE EXCEPTION 'Initial prerequisite states are incorrect'; END IF;
END $$;

INSERT INTO public.learning_progress(user_id,lesson_id,status,completed_at) VALUES
 ('b2111111-1111-4111-8111-111111111111','b2100000-0000-4000-8000-000000000011','completed',now());
DO $$ BEGIN
  IF public.englify_lesson_state('b2100000-0000-4000-8000-000000000012')<>'available' THEN
    RAISE EXCEPTION 'Completed prerequisite did not unlock lesson';
  END IF;
  BEGIN
    INSERT INTO public.journey_lesson_prerequisites(lesson_id,prerequisite_lesson_id)
    VALUES('b2100000-0000-4000-8000-000000000011','b2100000-0000-4000-8000-000000000013');
    RAISE EXCEPTION 'Prerequisite cycle accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN
    INSERT INTO public.journey_chapters(course_id,slug,title,position)
    VALUES(gen_random_uuid(),'missing-course','Missing parent',2);
    RAISE EXCEPTION 'Missing chapter parent accepted';
  EXCEPTION WHEN foreign_key_violation THEN NULL; END;
END $$;

INSERT INTO public.learning_progress(user_id,lesson_id,status,completed_at) VALUES
 ('b2111111-1111-4111-8111-111111111111','b2100000-0000-4000-8000-000000000012','completed',now());

DO $$ DECLARE journey jsonb; course jsonb; unit jsonb; BEGIN
  journey:=public.englify_journey();
  SELECT value INTO course FROM jsonb_array_elements(journey) WHERE value->>'id'='b2100000-0000-4000-8000-000000000001';
  unit:=course#>'{chapters,0,units,0}';
  IF course->>'cefr_level'<>'A1' OR course#>>'{continue_lesson,id}'<>'b2100000-0000-4000-8000-000000000013'
    OR (unit->>'required_lessons')::integer<>2 OR (unit->>'completed_required_lessons')::integer<>1
    OR (unit->>'progress_percent')::integer<>50
  THEN RAISE EXCEPTION 'Hierarchy, Continue Learning or optional progress failed: %',journey; END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','b2222222-2222-4222-8222-222222222222',true);
INSERT INTO public.quiz_questions(id,lesson_id,position,kind,prompt,payload,is_published)
VALUES('b2100000-0000-4000-8000-000000000021','b2100000-0000-4000-8000-000000000013',1,'fill_blank','Type yes','{}',false);
INSERT INTO public.quiz_answer_keys(question_id,answer)
VALUES('b2100000-0000-4000-8000-000000000021','["yes"]');
UPDATE public.quiz_questions SET is_published=true WHERE id='b2100000-0000-4000-8000-000000000021';
SELECT set_config('request.jwt.claim.sub','b2111111-1111-4111-8111-111111111111',true);

DO $$ DECLARE first_result jsonb; replay jsonb; BEGIN
  first_result:=public.englify_submit_lesson('b2100000-0000-4000-8000-000000000013',gen_random_uuid(),
    '{"b2100000-0000-4000-8000-000000000021":"yes"}',NULL);
  replay:=public.englify_submit_lesson('b2100000-0000-4000-8000-000000000013',gen_random_uuid(),
    '{"b2100000-0000-4000-8000-000000000021":"yes"}',NULL);
  IF NOT (first_result->>'passed')::boolean OR (first_result->>'earned_xp')::integer<=0
    OR (replay->>'earned_xp')::integer<>0
    OR (SELECT count(*) FROM public.xp_events WHERE user_id=auth.uid() AND source_type='lesson' AND source_id='b2100000-0000-4000-8000-000000000013')<>1
  THEN RAISE EXCEPTION 'Checkpoint completion or idempotent reward failed: %, %',first_result,replay; END IF;
END $$;

-- A completed lesson remains completed even if curriculum prerequisites are later extended.
INSERT INTO public.journey_lesson_prerequisites(lesson_id,prerequisite_lesson_id)
VALUES('b2100000-0000-4000-8000-000000000011','b2100000-0000-4000-8000-000000000014');
DO $$ BEGIN
  IF public.englify_lesson_state('b2100000-0000-4000-8000-000000000011')<>'completed' THEN
    RAISE EXCEPTION 'Historical completion was relocked';
  END IF;
END $$;

SET LOCAL ROLE authenticated;
DO $$ BEGIN
  BEGIN UPDATE public.journey_chapters SET position=9 WHERE id='b2100000-0000-4000-8000-000000000002';
    RAISE EXCEPTION 'Learner changed curriculum'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO public.learning_progress(user_id,lesson_id,status)
    VALUES('b2222222-2222-4222-8222-222222222222','b2100000-0000-4000-8000-000000000011','in_progress');
    RAISE EXCEPTION 'Learner changed another user progress'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

ROLLBACK;
