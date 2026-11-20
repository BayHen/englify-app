BEGIN;
INSERT INTO auth.users(id) VALUES ('b3111111-1111-4111-8111-111111111111'),('b3222222-2222-4222-8222-222222222222');
SELECT set_config('request.jwt.claim.sub','b3111111-1111-4111-8111-111111111111',true);
SET LOCAL ROLE authenticated;
DO $$
DECLARE started jsonb; sid uuid; question jsonb; submitted int:=0; finished jsonb; first_q uuid;
BEGIN
  PERFORM public.englify_update_journey_goals('B1','general',20,ARRAY['grammar','vocabulary'],ARRAY[1,3,5]::smallint[]);
  started:=public.englify_start_journey_placement_test(); sid:=(started->>'session_id')::uuid;
  IF jsonb_array_length(started->'questions')<>15 OR (started->'questions'->0 ? 'answer_index') THEN RAISE EXCEPTION 'Placement contract exposed key or wrong bank size'; END IF;
  FOR question IN SELECT value FROM jsonb_array_elements(started->'questions') LOOP
    IF submitted<12 THEN PERFORM public.englify_submit_journey_placement_answer(sid,(question->>'id')::uuid,0::smallint); first_q:=coalesce(first_q,(question->>'id')::uuid); submitted:=submitted+1; END IF;
  END LOOP;
  BEGIN PERFORM public.englify_submit_journey_placement_answer(sid,first_q,0::smallint); RAISE EXCEPTION 'Duplicate answer accepted'; EXCEPTION WHEN unique_violation THEN NULL; END;
  finished:=public.englify_finalize_journey_placement_test(sid);
  IF finished->>'recommended_cefr' IS NULL OR finished->>'confidence' NOT IN ('medium','high') THEN RAISE EXCEPTION 'Placement result invalid: %',finished; END IF;
END $$;
DO $$ DECLARE a jsonb; b jsonb; BEGIN
 a:=public.englify_journey_daily_plan('Asia/Ho_Chi_Minh',false); b:=public.englify_journey_daily_plan('Asia/Ho_Chi_Minh',false);
 IF a->>'id'<>b->>'id' THEN RAISE EXCEPTION 'Daily plan is not stable'; END IF;
 IF EXISTS(SELECT 1 FROM public.xp_events WHERE source_type LIKE 'journey_daily%') THEN RAISE EXCEPTION 'Daily plan granted XP'; END IF;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','b3222222-2222-4222-8222-222222222222',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.journey_placement_sessions) THEN RAISE EXCEPTION 'RLS leaked placement history'; END IF;
 IF EXISTS(SELECT 1 FROM public.journey_daily_plans) THEN RAISE EXCEPTION 'RLS leaked daily plan'; END IF;
END $$;
ROLLBACK;
