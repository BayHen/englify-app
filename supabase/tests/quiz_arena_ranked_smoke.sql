BEGIN;
INSERT INTO auth.users(id) VALUES
 ('a2333333-3333-4333-8333-333333333333'),
 ('a2344444-4444-4444-8444-444444444444'),
 ('a2355555-5555-4555-8555-555555555555');
INSERT INTO public.admin_members(user_id) VALUES('a2355555-5555-4555-8555-555555555555');

DO $$ BEGIN
 IF public.englify_arena_tier(999)<>'bronze' OR public.englify_arena_tier(1000)<>'silver'
  OR public.englify_arena_tier(1200)<>'gold' OR public.englify_arena_tier(1400)<>'platinum'
  OR public.englify_arena_tier(1600)<>'diamond' THEN RAISE EXCEPTION 'Tier boundaries failed'; END IF;
 IF public.englify_ranked_rating_delta(2040,10,10,2040,30,false)<>20
  OR public.englify_ranked_rating_delta(0,0,10,2040,30,false)<>-30
  OR public.englify_ranked_rating_delta(0,0,10,2040,30,true)<>-15 THEN RAISE EXCEPTION 'Rating formula failed'; END IF;
END $$;

SELECT set_config('request.jwt.claim.sub','a2333333-3333-4333-8333-333333333333',true);
CREATE TEMP TABLE ranked_fixture(id uuid,question_id uuid,answer jsonb);
GRANT SELECT ON ranked_fixture TO authenticated;
DO $$ DECLARE envelope jsonb; match jsonb; v_id uuid; q uuid; v_answer jsonb; req uuid; i integer; before_count integer; BEGIN
 envelope:=public.englify_ranked_start(gen_random_uuid()); match:=envelope->'match'; v_id:=(match->>'id')::uuid;
 IF match->>'ruleset_version'<>'1' OR (match->>'question_count')::integer<>10 OR (match->>'time_limit_seconds')::integer<>120
  OR envelope->'current_question' ? 'answer' OR envelope ? 'user_id' THEN RAISE EXCEPTION 'Unsafe ranked start: %',envelope; END IF;
 BEGIN PERFORM public.englify_ranked_start(gen_random_uuid());RAISE EXCEPTION 'Second active ranked match accepted';EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;END;
 FOR i IN 1..10 LOOP
  envelope:=public.englify_ranked_session(v_id);q:=(envelope#>>'{current_question,id}')::uuid;
  SELECT CASE WHEN sq.question->>'kind' IN ('fill_blank','grammar_correction') THEN sq.answer->0 ELSE sq.answer END INTO v_answer
   FROM public.arena_session_questions sq WHERE sq.session_id=v_id AND sq.question_id=q;
  req:=gen_random_uuid();envelope:=public.englify_ranked_answer(v_id,q,req,v_answer);match:=envelope->'match';
  IF (match->>'answered_count')::integer<>i THEN RAISE EXCEPTION 'Ranked answer count failed';END IF;
  before_count:=(SELECT count(*) FROM public.arena_ranked_answers WHERE match_id=v_id);
  PERFORM public.englify_ranked_answer(v_id,q,req,v_answer);
  IF (SELECT count(*) FROM public.arena_ranked_answers WHERE match_id=v_id)<>before_count THEN RAISE EXCEPTION 'Answer replay duplicated';END IF;
 END LOOP;
 IF match->>'status'<>'completed' OR (match->>'score')::integer<>2040 OR (match->>'rating_before')::integer<>1000
  OR (match->>'rating_after')::integer<>1020 OR (match->>'rating_change')::integer<>20
  OR (SELECT count(*) FROM public.arena_rating_events WHERE match_id=v_id)<>1 THEN RAISE EXCEPTION 'Atomic rating finalization failed: %',match;END IF;
 PERFORM public.englify_ranked_finalize(v_id,false);
 IF (SELECT count(*) FROM public.arena_rating_events WHERE match_id=v_id)<>1 OR (SELECT rating FROM public.arena_player_ratings WHERE user_id=auth.uid())<>1020 THEN RAISE EXCEPTION 'Duplicate finalization changed rating';END IF;
 INSERT INTO ranked_fixture VALUES(v_id,q,v_answer);
 IF EXISTS(SELECT 1 FROM public.xp_events WHERE user_id=auth.uid()) THEN RAISE EXCEPTION 'Ranked awarded XP';END IF;
 IF (public.englify_ranked_leaderboard('weekly')->>'my_position')::integer<>1 THEN RAISE EXCEPTION 'Weekly own position failed';END IF;
END $$;

-- Abandonment has an explicit conservative penalty and remains idempotent.
DO $$ DECLARE e jsonb; v_id uuid; BEGIN e:=public.englify_ranked_start(gen_random_uuid());v_id:=(e#>>'{match,id}')::uuid;e:=public.englify_ranked_finalize(v_id,true);
 IF (e#>>'{match,status}')<>'abandoned' OR (e#>>'{match,rating_change}')::integer<>-15 THEN RAISE EXCEPTION 'Abandon rule failed';END IF;
 PERFORM public.englify_ranked_finalize(v_id,true);IF (SELECT count(*) FROM public.arena_rating_events WHERE match_id=v_id)<>1 THEN RAISE EXCEPTION 'Abandon rated twice';END IF;END $$;

SET LOCAL ROLE authenticated;
DO $$ BEGIN
 BEGIN UPDATE public.arena_player_ratings SET rating=99999;RAISE EXCEPTION 'Client rating write accepted';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN SELECT * FROM public.arena_ranked_answers;RAISE EXCEPTION 'Private ranked answers exposed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN SELECT * FROM public.arena_ranked_security_events;RAISE EXCEPTION 'Security events exposed';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub','a2344444-4444-4444-8444-444444444444',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE f record; BEGIN SELECT * INTO f FROM ranked_fixture;
 IF EXISTS(SELECT 1 FROM public.arena_ranked_matches) OR EXISTS(SELECT 1 FROM public.arena_rating_events) THEN RAISE EXCEPTION 'Cross-user ranked metadata leaked';END IF;
 BEGIN PERFORM public.englify_ranked_session(f.id);RAISE EXCEPTION 'Cross-user match exposed';EXCEPTION WHEN SQLSTATE 'PT404' THEN NULL;END;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(public.englify_ranked_leaderboard('weekly')->'items') x WHERE x ? 'user_id' OR x ? 'email' OR x ? 'avatar_url') THEN RAISE EXCEPTION 'Leaderboard exposed private fields';END IF;
END $$;
RESET ROLE;

-- Admin lifecycle, finalization snapshot and reward ledger are idempotent.
SELECT set_config('request.jwt.claim.sub','a2355555-5555-4555-8555-555555555555',true);
DO $$ DECLARE current_id uuid; next_id uuid:=gen_random_uuid(); s jsonb; reward_count integer; BEGIN
 SELECT id INTO current_id FROM public.arena_seasons WHERE status='active';
 PERFORM public.englify_admin_upsert_ranked_ruleset(2,'Next ranked',10,120,3,100,1000,30,2040,'B1',true);
 IF NOT EXISTS(SELECT 1 FROM public.arena_ranked_rulesets WHERE version=2) THEN RAISE EXCEPTION 'Admin ruleset configuration failed';END IF;
 BEGIN PERFORM public.englify_admin_upsert_ranked_ruleset(1,'Changed used rule',11,120,3,100,1000,30,2040,'B1',true);RAISE EXCEPTION 'Used ruleset mutated';EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;END;
 PERFORM public.englify_admin_set_season_reward(current_id,'top-10',(SELECT id FROM public.badges WHERE code='arena-season-top-10'),false);
 PERFORM public.englify_admin_transition_arena_season(current_id,'closing');
 s:=public.englify_admin_upsert_arena_season(next_id,'smoke-next','Smoke next',1,clock_timestamp(),clock_timestamp()+interval '7 days');
 s:=public.englify_admin_transition_arena_season(next_id,'active');
 BEGIN PERFORM public.englify_admin_transition_arena_season(current_id,'active');RAISE EXCEPTION 'Duplicate active season accepted';EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;END;
 PERFORM public.englify_admin_transition_arena_season(current_id,'finalized');
 IF EXISTS(SELECT 1 FROM public.arena_season_rewards WHERE season_id=current_id AND reward_code='top-10') THEN RAISE EXCEPTION 'Disabled reward was granted';END IF;
 SELECT count(*) INTO reward_count FROM public.arena_season_rewards WHERE season_id=current_id;
 PERFORM public.englify_admin_transition_arena_season(current_id,'finalized');
 IF (SELECT count(*) FROM public.arena_season_rewards WHERE season_id=current_id)<>reward_count THEN RAISE EXCEPTION 'Season rewards duplicated';END IF;
 BEGIN PERFORM public.englify_admin_upsert_arena_season(current_id,'changed','Changed',1,clock_timestamp(),clock_timestamp()+interval '1 day');RAISE EXCEPTION 'Finalized season mutated';EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;END;
END $$;
ROLLBACK;
