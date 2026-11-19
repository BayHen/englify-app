BEGIN;
INSERT INTO auth.users(id) VALUES ('a2466666-6666-4666-8666-666666666666'),('a2477777-7777-4777-8777-777777777777');

DO $$ BEGIN
 IF public.englify_quiz_review_status(0)<>'needs_review' OR public.englify_quiz_review_status(1)<>'learning'
  OR public.englify_quiz_review_status(3)<>'improving' OR public.englify_quiz_review_status(5)<>'mastered' THEN RAISE EXCEPTION 'Mastery boundaries failed'; END IF;
 IF public.englify_quiz_review_interval(0)<>interval '10 minutes' OR public.englify_quiz_review_interval(1)<>interval '1 day'
  OR public.englify_quiz_review_interval(2)<>interval '3 days' OR public.englify_quiz_review_interval(3)<>interval '7 days'
  OR public.englify_quiz_review_interval(4)<>interval '14 days' OR public.englify_quiz_review_interval(5)<>interval '30 days' THEN RAISE EXCEPTION 'SRS intervals failed'; END IF;
END $$;

SELECT public.englify_quiz_ingest_answer('a2466666-6666-4666-8666-666666666666','arena','11111111-1111-4111-8111-111111111111','practice','22222222-2222-4222-8222-222222222222','"wrong"',false,
 '{"id":"11111111-1111-4111-8111-111111111111","kind":"multiple_choice","topic":"grammar","cefr_level":"B1","difficulty":1,"prompt":"Choose","passage":null,"options":[{"id":"right","text":"Right"},{"id":"wrong","text":"Wrong"}],"left_items":[],"right_items":[]}',
 '"right"','Giải thích tiếng Việt','B1','grammar','multiple_choice',clock_timestamp());
-- A duplicate persisted source identity must not increment mistake counters.
SELECT public.englify_quiz_ingest_answer('a2466666-6666-4666-8666-666666666666','arena','11111111-1111-4111-8111-111111111111','practice','22222222-2222-4222-8222-222222222222','"wrong"',false,
 '{"id":"11111111-1111-4111-8111-111111111111","kind":"multiple_choice","topic":"grammar","cefr_level":"B1","difficulty":1,"prompt":"Choose","passage":null,"options":[],"left_items":[],"right_items":[]}',
 '"right"','Giải thích tiếng Việt','B1','grammar','multiple_choice',clock_timestamp());
DO $$ BEGIN IF (SELECT incorrect_attempts FROM public.quiz_mistake_progress WHERE user_id='a2466666-6666-4666-8666-666666666666')<>1 THEN RAISE EXCEPTION 'Duplicate ingestion changed progress'; END IF; END $$;

SELECT set_config('request.jwt.claim.sub','a2466666-6666-4666-8666-666666666666',true);
DO $$ DECLARE s jsonb; sid uuid; pid uuid; req uuid:=gen_random_uuid(); before_xp integer; BEGIN
 before_xp:=(SELECT count(*) FROM public.xp_events WHERE user_id=auth.uid()); s:=public.englify_quiz_start_review(req,5); sid:=(s->>'id')::uuid; pid:=(s#>>'{current_item,id}')::uuid;
 IF s#>'{current_item,answer_key}' IS NOT NULL OR s#>>'{current_item,question,prompt}'<>'Choose' THEN RAISE EXCEPTION 'Review leaked key or lost question: %',s; END IF;
 s:=public.englify_quiz_submit_review(sid,pid,gen_random_uuid(),'"right"');
 IF s->>'status'<>'completed' OR (s->>'earned_xp')::integer<>0 OR (s->>'correct_count')::integer<>1 THEN RAISE EXCEPTION 'Review completion failed: %',s; END IF;
 IF (SELECT review_stage FROM public.quiz_mistake_progress WHERE id=pid)<>1 OR (SELECT count(*) FROM public.xp_events WHERE user_id=auth.uid())<>before_xp THEN RAISE EXCEPTION 'Review stage or XP invariant failed'; END IF;
 IF NOT (s#>'{review,0}' ? 'correct_answer') THEN RAISE EXCEPTION 'Completed review omitted answer'; END IF;
END $$;

SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN SELECT * FROM public.quiz_answer_facts; RAISE EXCEPTION 'Answer facts exposed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN SELECT * FROM public.quiz_review_session_items; RAISE EXCEPTION 'Review selection exposed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.quiz_mistake_progress SET review_stage=5; RAISE EXCEPTION 'Client mastery write accepted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','a2477777-7777-4777-8777-777777777777',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN IF EXISTS(SELECT 1 FROM public.quiz_mistake_progress) OR EXISTS(SELECT 1 FROM public.quiz_review_sessions) OR EXISTS(SELECT 1 FROM public.quiz_review_events) THEN RAISE EXCEPTION 'Cross-user review data leaked'; END IF; END $$;
RESET ROLE;
ROLLBACK;
