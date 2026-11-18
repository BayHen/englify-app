-- Disposable local Supabase only. Requires all migrations and development seeds.
BEGIN;
INSERT INTO auth.users(id) VALUES
('c1111111-1111-4111-8111-111111111111'),
('c2222222-2222-4222-8222-222222222222'),
('c3333333-3333-4333-8333-333333333333');
INSERT INTO public.admin_members(user_id) VALUES('c1111111-1111-4111-8111-111111111111');

DO $$ BEGIN
  IF public.englify_writing_local_date('Asia/Ho_Chi_Minh','2026-01-01 16:59:59+00')<>'2026-01-01'
    OR public.englify_writing_local_date('Asia/Ho_Chi_Minh','2026-01-01 17:00:00+00')<>'2026-01-02' THEN
    RAISE EXCEPTION 'Asia/Ho_Chi_Minh rollover failed';
  END IF;
  IF public.englify_writing_local_date('UTC','2026-01-01 23:59:59+00')<>'2026-01-01'
    OR public.englify_writing_local_date('UTC','2026-01-02 00:00:00+00')<>'2026-01-02' THEN
    RAISE EXCEPTION 'UTC rollover failed';
  END IF;
  IF public.englify_writing_local_date('America/New_York','2026-03-08 04:59:59+00')<>'2026-03-07'
    OR public.englify_writing_local_date('America/New_York','2026-03-08 05:00:00+00')<>'2026-03-08' THEN
    RAISE EXCEPTION 'DST transition calendar failed';
  END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','c1111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_first jsonb; v_second jsonb; v_invalid jsonb; v_completed jsonb; v_retry jsonb;
  v_assignment uuid; v_request uuid:=gen_random_uuid(); v_timezone jsonb;
BEGIN
  PERFORM public.englify_set_writing_level('B1');
  v_timezone:=public.englify_set_writing_timezone('Asia/Ho_Chi_Minh');
  IF v_timezone->>'timezone'<>'Asia/Ho_Chi_Minh' THEN RAISE EXCEPTION 'Initial timezone save failed'; END IF;
  v_first:=public.englify_writing_daily_overview();
  v_second:=public.englify_writing_daily_overview();
  IF v_first#>>'{challenge,assignment_id}' IS NULL
    OR v_first#>>'{challenge,assignment_id}'<>v_second#>>'{challenge,assignment_id}'
    OR v_first#>>'{challenge,cefr_level}'<>'B1' THEN
    RAISE EXCEPTION 'Daily assignment is unstable or wrong CEFR';
  END IF;
  v_assignment:=(v_first#>>'{challenge,assignment_id}')::uuid;
  PERFORM public.englify_set_writing_level('C1');
  IF public.englify_writing_daily_overview()#>>'{challenge,assignment_id}'<>v_assignment::text THEN
    RAISE EXCEPTION 'Same-day level change replaced the assignment'; END IF;
  v_timezone:=public.englify_set_writing_timezone('Asia/Tokyo');
  IF v_timezone->>'timezone'<>'Asia/Ho_Chi_Minh' OR v_timezone->>'pending_timezone'<>'Asia/Tokyo' THEN
    RAISE EXCEPTION 'Timezone change did not wait for the next old-timezone midnight'; END IF;
  v_invalid:=public.englify_submit_daily_writing(v_assignment,gen_random_uuid(),'Too short.',false);
  IF (v_invalid->>'completed')::boolean OR (SELECT count(*) FROM public.xp_events WHERE user_id=auth.uid())<>0 THEN
    RAISE EXCEPTION 'Invalid open response completed or earned XP'; END IF;
  v_completed:=public.englify_submit_daily_writing(v_assignment,v_request,
    btrim(repeat('This response contains enough original words for the server validated daily writing challenge. ',9))||'.',false);
  IF NOT (v_completed->>'completed')::boolean OR NOT (v_completed->>'newly_completed')::boolean
    OR (v_completed->>'earned_xp')::integer<>20 THEN RAISE EXCEPTION 'Valid challenge completion failed'; END IF;
  v_retry:=public.englify_submit_daily_writing(v_assignment,v_request,
    btrim(repeat('This response contains enough original words for the server validated daily writing challenge. ',9))||'.',false);
  IF NOT (v_retry->>'completed')::boolean OR (v_retry->>'newly_completed')::boolean
    OR (v_retry->>'earned_xp')::integer<>0 THEN RAISE EXCEPTION 'Completion retry was not idempotent'; END IF;
  IF (SELECT count(*) FROM public.xp_events WHERE user_id=auth.uid() AND source_type='writing' AND source_id=v_assignment)<>1
    OR (SELECT count(*) FROM public.writing_daily_completions WHERE user_id=auth.uid())<>1 THEN
    RAISE EXCEPTION 'Duplicate XP or completion was created'; END IF;
  IF (SELECT total_xp FROM public.user_levels WHERE user_id=auth.uid())<>20 THEN
    RAISE EXCEPTION 'Daily Writing XP did not update the shared user level ledger'; END IF;
  PERFORM public.englify_create_writing_revision(gen_random_uuid(),(v_completed#>>'{submission,id}')::uuid,
    'This learner revision remains separate and must not grant another Daily Writing reward.',NULL,NULL);
  IF (SELECT count(*) FROM public.xp_events WHERE user_id=auth.uid() AND source_type='writing')<>1 THEN
    RAISE EXCEPTION 'Writing revision duplicated Daily Writing XP'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.user_badges ub JOIN public.badges b ON b.id=ub.badge_id
      WHERE ub.user_id=auth.uid() AND b.code='writing-first-step') THEN
    RAISE EXCEPTION 'First Writing milestone was not awarded'; END IF;
  BEGIN
    PERFORM public.englify_submit_daily_writing(gen_random_uuid(),gen_random_uuid(),'Unrelated assignment response.',false);
    RAISE EXCEPTION 'Unassigned exercise submission was accepted';
  EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END;
  BEGIN
    UPDATE public.user_preferences SET writing_timezone='UTC' WHERE user_id=auth.uid();
    RAISE EXCEPTION 'Learner bypassed timezone transition rules';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.xp_events(user_id,source_type,source_id,amount) VALUES(auth.uid(),'writing',gen_random_uuid(),100);
    RAISE EXCEPTION 'Learner forged Writing XP';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

-- Add two historical completions and one older separated completion to verify streak semantics.
DO $$ DECLARE v_today date; v_exercise uuid; BEGIN
  SELECT challenge_date INTO v_today FROM public.writing_daily_assignments
    WHERE user_id='c1111111-1111-4111-8111-111111111111' ORDER BY challenge_date DESC LIMIT 1;
  SELECT id INTO v_exercise FROM public.writing_exercises WHERE cefr_level='B1' AND is_published LIMIT 1;
  INSERT INTO public.writing_daily_assignments(id,user_id,exercise_id,challenge_date,timezone_name,assigned_cefr_level,xp_reward) VALUES
    ('c3000000-0000-4000-8000-000000000001','c1111111-1111-4111-8111-111111111111',v_exercise,v_today-1,'Asia/Ho_Chi_Minh','B1',20),
    ('c3000000-0000-4000-8000-000000000002','c1111111-1111-4111-8111-111111111111',v_exercise,v_today-2,'Asia/Ho_Chi_Minh','B1',20),
    ('c3000000-0000-4000-8000-000000000004','c1111111-1111-4111-8111-111111111111',v_exercise,v_today-4,'Asia/Ho_Chi_Minh','B1',20);
  INSERT INTO public.writing_submissions(id,user_id,exercise_id,request_id,prompt,body) VALUES
    ('c4000000-0000-4000-8000-000000000001','c1111111-1111-4111-8111-111111111111',v_exercise,gen_random_uuid(),'History','Historical response one.'),
    ('c4000000-0000-4000-8000-000000000002','c1111111-1111-4111-8111-111111111111',v_exercise,gen_random_uuid(),'History','Historical response two.'),
    ('c4000000-0000-4000-8000-000000000004','c1111111-1111-4111-8111-111111111111',v_exercise,gen_random_uuid(),'History','Older response.');
  INSERT INTO public.writing_daily_completions(assignment_id,user_id,submission_id,challenge_date,awarded_xp) VALUES
    ('c3000000-0000-4000-8000-000000000001','c1111111-1111-4111-8111-111111111111','c4000000-0000-4000-8000-000000000001',v_today-1,20),
    ('c3000000-0000-4000-8000-000000000002','c1111111-1111-4111-8111-111111111111','c4000000-0000-4000-8000-000000000002',v_today-2,20),
    ('c3000000-0000-4000-8000-000000000004','c1111111-1111-4111-8111-111111111111','c4000000-0000-4000-8000-000000000004',v_today-4,20);
END $$;

SELECT set_config('request.jwt.claim.sub','c1111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_overview jsonb:=public.englify_writing_daily_overview(); BEGIN
  IF (v_overview#>>'{streak,current_streak}')::integer<>3
    OR (v_overview#>>'{streak,longest_streak}')::integer<>3
    OR (v_overview#>>'{streak,total_completed_days}')::integer<>4 THEN
    RAISE EXCEPTION 'Writing streak calculation failed: %',v_overview->'streak'; END IF;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_overview->'calendar') day
      WHERE day->>'status'='missed') THEN RAISE EXCEPTION 'Missed calendar day is absent'; END IF;
END $$;
RESET ROLE;

-- A normal third-day completion unlocks the streak milestone through the same RPC.
SELECT set_config('request.jwt.claim.sub','c3333333-3333-4333-8333-333333333333',true);
SET LOCAL ROLE authenticated;
SELECT public.englify_set_writing_level('A1');
SELECT public.englify_writing_daily_overview();
RESET ROLE;
DO $$ DECLARE v_today date; v_exercise uuid; BEGIN
  SELECT challenge_date,exercise_id INTO v_today,v_exercise FROM public.writing_daily_assignments
    WHERE user_id='c3333333-3333-4333-8333-333333333333';
  INSERT INTO public.writing_daily_assignments(id,user_id,exercise_id,challenge_date,timezone_name,assigned_cefr_level,xp_reward) VALUES
    ('c5000000-0000-4000-8000-000000000001','c3333333-3333-4333-8333-333333333333',v_exercise,v_today-1,'Asia/Ho_Chi_Minh','A1',10),
    ('c5000000-0000-4000-8000-000000000002','c3333333-3333-4333-8333-333333333333',v_exercise,v_today-2,'Asia/Ho_Chi_Minh','A1',10);
  INSERT INTO public.writing_submissions(id,user_id,exercise_id,request_id,prompt,body) VALUES
    ('c6000000-0000-4000-8000-000000000001','c3333333-3333-4333-8333-333333333333',v_exercise,gen_random_uuid(),'History','Historical response one.'),
    ('c6000000-0000-4000-8000-000000000002','c3333333-3333-4333-8333-333333333333',v_exercise,gen_random_uuid(),'History','Historical response two.');
  INSERT INTO public.writing_daily_completions(assignment_id,user_id,submission_id,challenge_date,awarded_xp) VALUES
    ('c5000000-0000-4000-8000-000000000001','c3333333-3333-4333-8333-333333333333','c6000000-0000-4000-8000-000000000001',v_today-1,10),
    ('c5000000-0000-4000-8000-000000000002','c3333333-3333-4333-8333-333333333333','c6000000-0000-4000-8000-000000000002',v_today-2,10);
END $$;
SELECT set_config('request.jwt.claim.sub','c3333333-3333-4333-8333-333333333333',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_assignment uuid; v_result jsonb; BEGIN
  SELECT id INTO v_assignment FROM public.writing_daily_assignments WHERE user_id=auth.uid()
    ORDER BY challenge_date DESC LIMIT 1;
  v_result:=public.englify_submit_daily_writing(v_assignment,gen_random_uuid(),
    'I write a clear daily response with enough words to complete this challenge successfully today.',false);
  IF NOT (v_result->>'completed')::boolean OR (v_result#>>'{overview,streak,current_streak}')::integer<>3 THEN
    RAISE EXCEPTION 'Third consecutive Daily Writing completion failed'; END IF;
  IF NOT EXISTS(SELECT 1 FROM public.user_badges ub JOIN public.badges b ON b.id=ub.badge_id
      WHERE ub.user_id=auth.uid() AND b.code='writing-three-day') THEN
    RAISE EXCEPTION 'Three-Day Writer milestone was not awarded'; END IF;
END $$;
RESET ROLE;

-- A second learner cannot see or mutate the first learner's private challenge data.
SELECT set_config('request.jwt.claim.sub','c2222222-2222-4222-8222-222222222222',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.writing_daily_assignments)<>0
    OR (SELECT count(*) FROM public.writing_daily_completions)<>0 THEN
    RAISE EXCEPTION 'Cross-user Daily Writing data leaked'; END IF;
  BEGIN
    DELETE FROM public.writing_daily_completions WHERE user_id='c1111111-1111-4111-8111-111111111111';
    IF FOUND THEN RAISE EXCEPTION 'Learner deleted another completion'; END IF;
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM public.englify_writing_daily_overview();
END $$;
RESET ROLE;

-- With no published exercise the server returns an explicit empty challenge instead of leaking a draft.
SELECT set_config('request.jwt.claim.sub','c1111111-1111-4111-8111-111111111111',true);
UPDATE public.writing_exercises SET is_published=false;
SELECT set_config('request.jwt.claim.sub','c2222222-2222-4222-8222-222222222222',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_overview jsonb:=public.englify_writing_daily_overview(); BEGIN
  IF v_overview->'challenge'<>'null'::jsonb THEN RAISE EXCEPTION 'Unpublished exercise was assigned'; END IF;
  IF (SELECT count(*) FROM public.writing_daily_assignments WHERE user_id=auth.uid())<>1 THEN
    RAISE EXCEPTION 'Unpublished same-day assignment was replaced instead of hidden'; END IF;
END $$;

ROLLBACK;
