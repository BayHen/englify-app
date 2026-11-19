-- Complete V2.3 admin configuration without mutating historical rules or rewards.
CREATE TABLE public.arena_season_reward_rules (
  season_id uuid NOT NULL REFERENCES public.arena_seasons(id) ON DELETE CASCADE,
  reward_code text NOT NULL CHECK(reward_code IN ('tier:bronze','tier:silver','tier:gold','tier:platinum','tier:diamond','top-10')),
  badge_id uuid NOT NULL REFERENCES public.badges(id) ON DELETE RESTRICT,
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(season_id,reward_code)
);
ALTER TABLE public.arena_season_reward_rules ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.arena_season_reward_rules FROM anon,authenticated;
GRANT ALL ON public.arena_season_reward_rules TO service_role;

INSERT INTO public.arena_season_reward_rules(season_id,reward_code,badge_id)
SELECT s.id,replace(b.code,'arena-season-','tier:'),b.id
FROM public.arena_seasons s CROSS JOIN public.badges b
WHERE b.code IN ('arena-season-bronze','arena-season-silver','arena-season-gold','arena-season-platinum','arena-season-diamond')
ON CONFLICT DO NOTHING;
INSERT INTO public.arena_season_reward_rules(season_id,reward_code,badge_id)
SELECT s.id,'top-10',b.id FROM public.arena_seasons s CROSS JOIN public.badges b WHERE b.code='arena-season-top-10'
ON CONFLICT DO NOTHING;

CREATE FUNCTION public.englify_admin_upsert_ranked_ruleset(
  p_version integer,p_name text,p_question_count integer,p_time_limit_seconds integer,p_initial_lives integer,
  p_base_points integer,p_initial_rating integer,p_max_rating_change integer,p_reference_score integer,p_cefr_level text,p_enabled boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE old public.arena_ranked_rulesets%ROWTYPE; result public.arena_ranked_rulesets%ROWTYPE;
BEGIN
 IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 SELECT * INTO old FROM public.arena_ranked_rulesets WHERE version=p_version FOR UPDATE;
 IF FOUND AND EXISTS(SELECT 1 FROM public.arena_ranked_matches WHERE ruleset_version=p_version) AND
   (old.name,old.question_count,old.time_limit_seconds,old.initial_lives,old.base_points,old.initial_rating,old.max_rating_change,old.reference_score,old.cefr_level)
   IS DISTINCT FROM
   (p_name,p_question_count,p_time_limit_seconds,p_initial_lives,p_base_points,p_initial_rating,p_max_rating_change,p_reference_score,p_cefr_level)
 THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Used rulesets are immutable; create a new version'; END IF;
 INSERT INTO public.arena_ranked_rulesets(version,name,question_count,time_limit_seconds,initial_lives,base_points,initial_rating,max_rating_change,reference_score,cefr_level,enabled)
 VALUES(p_version,p_name,p_question_count,p_time_limit_seconds,p_initial_lives,p_base_points,p_initial_rating,p_max_rating_change,p_reference_score,p_cefr_level,p_enabled)
 ON CONFLICT(version) DO UPDATE SET name=excluded.name,question_count=excluded.question_count,time_limit_seconds=excluded.time_limit_seconds,
 initial_lives=excluded.initial_lives,base_points=excluded.base_points,initial_rating=excluded.initial_rating,max_rating_change=excluded.max_rating_change,
 reference_score=excluded.reference_score,cefr_level=excluded.cefr_level,enabled=excluded.enabled RETURNING * INTO result;
 INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data)
 VALUES(auth.uid(),CASE WHEN old.version IS NULL THEN 'create' ELSE 'update' END,'arena-ruleset',
   ('00000000-0000-0000-0000-'||lpad(result.version::text,12,'0'))::uuid,CASE WHEN old.version IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(result));
 RETURN to_jsonb(result);
END $$;

CREATE FUNCTION public.englify_admin_set_season_reward(p_season_id uuid,p_reward_code text,p_badge_id uuid,p_enabled boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.arena_seasons%ROWTYPE; result public.arena_season_reward_rules%ROWTYPE;
BEGIN
 IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 SELECT * INTO s FROM public.arena_seasons WHERE id=p_season_id FOR UPDATE; IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Season not found'; END IF;
 IF s.status='finalized' THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Finalized season rewards are immutable'; END IF;
 INSERT INTO public.arena_season_reward_rules(season_id,reward_code,badge_id,enabled) VALUES(p_season_id,p_reward_code,p_badge_id,p_enabled)
 ON CONFLICT(season_id,reward_code) DO UPDATE SET badge_id=excluded.badge_id,enabled=excluded.enabled RETURNING * INTO result;
 INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data)
 VALUES(auth.uid(),'update','arena-season',p_season_id,NULL,to_jsonb(result)); RETURN to_jsonb(result);
END $$;

-- New seasons receive an explicit, editable reward configuration.
CREATE OR REPLACE FUNCTION public.englify_admin_upsert_arena_season(p_id uuid,p_code text,p_title text,p_ruleset integer,p_starts_at timestamptz,p_ends_at timestamptz) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE old public.arena_seasons%ROWTYPE; result public.arena_seasons%ROWTYPE;
BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 SELECT * INTO old FROM public.arena_seasons WHERE id=p_id FOR UPDATE; IF FOUND AND old.status='finalized' THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Finalized seasons are immutable'; END IF;
 INSERT INTO public.arena_seasons(id,code,title,ruleset_version,status,starts_at,ends_at,created_by) VALUES(coalesce(p_id,gen_random_uuid()),p_code,p_title,p_ruleset,'scheduled',p_starts_at,p_ends_at,auth.uid())
 ON CONFLICT(id) DO UPDATE SET code=excluded.code,title=excluded.title,ruleset_version=excluded.ruleset_version,starts_at=excluded.starts_at,ends_at=excluded.ends_at,updated_at=clock_timestamp() RETURNING * INTO result;
 INSERT INTO public.arena_season_reward_rules(season_id,reward_code,badge_id)
 SELECT result.id,CASE WHEN b.code='arena-season-top-10' THEN 'top-10' ELSE replace(b.code,'arena-season-','tier:') END,b.id
 FROM public.badges b WHERE b.code LIKE 'arena-season-%' ON CONFLICT DO NOTHING;
 INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data) VALUES(auth.uid(),CASE WHEN old.id IS NULL THEN 'create' ELSE 'update' END,'arena-season',result.id,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(result)); RETURN to_jsonb(result); END $$;

-- Finalization consumes the season's snapshotted reward configuration.
CREATE OR REPLACE FUNCTION public.englify_admin_transition_arena_season(p_id uuid,p_status text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.arena_seasons%ROWTYPE; match_row public.arena_ranked_matches%ROWTYPE; now_at timestamptz:=clock_timestamp();
BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF; IF p_status NOT IN ('active','closing','finalized') THEN RAISE EXCEPTION 'Invalid transition' USING ERRCODE='22023'; END IF;
 SELECT * INTO s FROM public.arena_seasons WHERE id=p_id FOR UPDATE; IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Season not found'; END IF; IF s.status='finalized' THEN RETURN to_jsonb(s); END IF;
 IF (s.status='scheduled' AND p_status<>'active') OR (s.status='active' AND p_status NOT IN ('closing','finalized')) OR (s.status='closing' AND p_status<>'finalized') THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Invalid season transition'; END IF;
 IF p_status='active' AND EXISTS(SELECT 1 FROM public.arena_seasons WHERE status='active' AND id<>p_id) THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Another season is active'; END IF;
 IF p_status='finalized' THEN
  FOR match_row IN SELECT * FROM public.arena_ranked_matches WHERE season_id=p_id AND status='active' FOR UPDATE LOOP PERFORM public.englify_ranked_close(match_row.id,CASE WHEN now_at>=match_row.expires_at THEN 'time_expired' ELSE 'invalid' END,now_at); END LOOP;
  INSERT INTO public.arena_season_standings(season_id,user_id,position,season_score,qualifying_correct,qualifying_questions,matches_played,rating,tier,achieved_at,finalized_at)
  WITH q AS (SELECT m.*,row_number() OVER(PARTITION BY user_id ORDER BY score DESC,correct_count DESC,completed_at,id) pick FROM public.arena_ranked_matches m WHERE season_id=p_id AND rated_at IS NOT NULL AND status IN ('completed','expired')),
  a AS (SELECT user_id,sum(score)::integer score,sum(correct_count)::integer correct,sum(question_count)::integer questions,max(completed_at) achieved_at,count(*)::integer matches FROM q WHERE pick<=3 GROUP BY user_id),
  z AS (SELECT a.*,r.rating,public.englify_arena_tier(r.rating) tier,row_number() OVER(ORDER BY score DESC,correct::numeric/nullif(questions,0) DESC,achieved_at,user_id)::integer pos FROM a JOIN public.arena_player_ratings r USING(user_id))
  SELECT p_id,user_id,pos,score,correct,questions,matches,rating,tier,achieved_at,now_at FROM z ON CONFLICT DO NOTHING;
  INSERT INTO public.arena_season_rewards(season_id,user_id,reward_code,badge_id)
  SELECT p_id,st.user_id,c.reward_code,c.badge_id FROM public.arena_season_standings st JOIN public.arena_season_reward_rules c ON c.season_id=st.season_id AND c.enabled
  WHERE st.season_id=p_id AND (c.reward_code='tier:'||st.tier OR (c.reward_code='top-10' AND st.position<=10)) ON CONFLICT DO NOTHING;
  INSERT INTO public.user_badges(user_id,badge_id) SELECT user_id,badge_id FROM public.arena_season_rewards WHERE season_id=p_id ON CONFLICT(user_id,badge_id) DO NOTHING;
 END IF;
 UPDATE public.arena_seasons SET status=p_status,finalized_at=CASE WHEN p_status='finalized' THEN now_at ELSE NULL END,updated_at=now_at WHERE id=p_id RETURNING * INTO s;
 INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data) VALUES(auth.uid(),'update','arena-season',s.id,NULL,to_jsonb(s)); RETURN to_jsonb(s); END $$;

CREATE OR REPLACE FUNCTION public.englify_admin_arena_overview() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('seasons',(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY starts_at DESC),'[]'::jsonb) FROM public.arena_seasons s),
 'rulesets',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY version DESC),'[]'::jsonb) FROM public.arena_ranked_rulesets r),
 'reward_rules',(SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY season_id,reward_code),'[]'::jsonb) FROM public.arena_season_reward_rules c),
 'unreviewed_security_events',(SELECT count(*) FROM public.arena_ranked_security_events WHERE reviewed_at IS NULL),
 'recent_suspicious',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY created_at DESC),'[]'::jsonb) FROM (SELECT id,match_id,signal,severity,details,created_at FROM public.arena_ranked_security_events WHERE reviewed_at IS NULL ORDER BY created_at DESC LIMIT 30)x)); END $$;

REVOKE ALL ON FUNCTION public.englify_admin_upsert_ranked_ruleset(integer,text,integer,integer,integer,integer,integer,integer,integer,text,boolean),public.englify_admin_set_season_reward(uuid,text,uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_admin_upsert_ranked_ruleset(integer,text,integer,integer,integer,integer,integer,integer,integer,text,boolean),public.englify_admin_set_season_reward(uuid,text,uuid,boolean) TO authenticated;
