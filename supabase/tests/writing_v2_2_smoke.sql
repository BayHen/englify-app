-- Disposable local database only; development seeds must be loaded first.
BEGIN;
DO $$ DECLARE v_level text; BEGIN
  IF (SELECT count(*) FROM public.writing_topics WHERE is_published)<>10 THEN RAISE EXCEPTION 'Expected 10 writing topics'; END IF;
  FOREACH v_level IN ARRAY ARRAY['A1','A2','B1','B2','C1'] LOOP
    IF (SELECT count(*) FROM public.writing_exercises WHERE is_published AND cefr_level=v_level)<10 THEN
      RAISE EXCEPTION 'Insufficient exercises for %',v_level; END IF;
  END LOOP;
END $$;
INSERT INTO auth.users(id) VALUES('b1111111-1111-4111-8111-111111111111'),('b2222222-2222-4222-8222-222222222222');
INSERT INTO public.admin_members(user_id) VALUES('b1111111-1111-4111-8111-111111111111');

SELECT set_config('request.jwt.claim.sub','b2222222-2222-4222-8222-222222222222',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE v_library jsonb; v_topics jsonb; v_submission jsonb; BEGIN
  IF public.englify_set_writing_level('B1')<>'B1' THEN RAISE EXCEPTION 'Writing level was not saved'; END IF;
  IF (SELECT writing_cefr_level FROM public.user_preferences WHERE user_id=auth.uid())<>'B1' THEN RAISE EXCEPTION 'Writing level was not restored'; END IF;
  v_library:=public.englify_writing_library('meeting','B1',NULL,NULL,1,5);
  IF (v_library->>'total')::integer<1 OR jsonb_array_length(v_library->'items')>5 THEN RAISE EXCEPTION 'Writing search/pagination failed'; END IF;
  v_topics:=public.englify_writing_topics('B1');
  IF jsonb_array_length(v_topics)<>10 THEN RAISE EXCEPTION 'Published topic list failed'; END IF;
  v_submission:=public.englify_submit_writing(gen_random_uuid(),(SELECT id FROM public.writing_exercises WHERE slug='email-writing-b1'),
    'Dear Alex, I am sorry for my delayed reply. I can meet on Friday afternoon. Please let me know if that time works for you. Kind regards, Minh.',false);
  IF v_submission#>>'{feedback,rule_result}'<>'self_review' THEN RAISE EXCEPTION 'Open email grading failed'; END IF;
  BEGIN PERFORM public.englify_set_writing_level('C2'); RAISE EXCEPTION 'Invalid writing level accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN INSERT INTO public.writing_topics(slug,title,description) VALUES('unauthorized','No','Learner write');
    RAISE EXCEPTION 'Learner created topic'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','b1111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
INSERT INTO public.writing_topics(id,slug,title,description,is_published,sort_order)
VALUES('b3333333-3333-4333-8333-333333333333','admin-test','Admin test','Admin-managed writing topic.',false,999);
UPDATE public.writing_topics SET title='Admin test edited',is_published=true WHERE id='b3333333-3333-4333-8333-333333333333';
INSERT INTO public.writing_exercises(id,slug,topic_id,cefr_level,kind,title,prompt,difficulty,is_published)
VALUES('b4444444-4444-4444-8444-444444444444','admin-writing-test','b3333333-3333-4333-8333-333333333333','A2','paragraph','Admin exercise','Describe a useful skill.',2,true);
UPDATE public.writing_exercises SET is_published=false,archived_at=now() WHERE id='b4444444-4444-4444-8444-444444444444';
RESET ROLE;
DO $$ BEGIN
  IF (SELECT count(*) FROM public.admin_audit_logs WHERE resource IN ('writing_topics','writing_exercises'))<3 THEN
    RAISE EXCEPTION 'Writing admin changes were not audited'; END IF;
  IF (SELECT count(*) FROM public.writing_submissions WHERE user_id='b2222222-2222-4222-8222-222222222222')<>1 THEN
    RAISE EXCEPTION 'Historical submission was not preserved'; END IF;
END $$;
ROLLBACK;
