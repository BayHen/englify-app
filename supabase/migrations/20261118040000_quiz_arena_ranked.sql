-- Quiz Arena V2.3: asynchronous ranked competition, ratings and seasons.
ALTER TABLE public.arena_sessions DROP CONSTRAINT IF EXISTS arena_sessions_mode_check;
ALTER TABLE public.arena_sessions ADD CONSTRAINT arena_sessions_mode_check
  CHECK (mode IN ('practice','time_attack','ranked'));

CREATE TABLE public.arena_ranked_rulesets (
  version integer PRIMARY KEY CHECK (version > 0),
  name text NOT NULL CHECK (char_length(trim(name)) BETWEEN 1 AND 80),
  question_count integer NOT NULL CHECK (question_count BETWEEN 5 AND 30),
  time_limit_seconds integer NOT NULL CHECK (time_limit_seconds BETWEEN 30 AND 600),
  initial_lives integer NOT NULL CHECK (initial_lives BETWEEN 1 AND 10),
  base_points integer NOT NULL CHECK (base_points BETWEEN 1 AND 1000),
  initial_rating integer NOT NULL CHECK (initial_rating BETWEEN 0 AND 5000),
  max_rating_change integer NOT NULL CHECK (max_rating_change BETWEEN 1 AND 100),
  reference_score integer NOT NULL CHECK (reference_score > 0),
  cefr_level text NOT NULL CHECK (cefr_level IN ('A1','A2','B1','B2','C1')),
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.arena_ranked_rulesets(version,name,question_count,time_limit_seconds,initial_lives,base_points,initial_rating,max_rating_change,reference_score,cefr_level)
VALUES (1,'Standard ranked',10,120,3,100,1000,30,2040,'B1');

CREATE TABLE public.arena_seasons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE CHECK (code ~ '^[a-z0-9-]{3,40}$'),
  title text NOT NULL CHECK (char_length(trim(title)) BETWEEN 1 AND 80),
  ruleset_version integer NOT NULL REFERENCES public.arena_ranked_rulesets(version),
  status text NOT NULL CHECK (status IN ('scheduled','active','closing','finalized')),
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  finalized_at timestamptz,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at),
  CHECK ((status='finalized')=(finalized_at IS NOT NULL))
);
CREATE UNIQUE INDEX arena_seasons_one_active ON public.arena_seasons((true)) WHERE status='active';
CREATE INDEX arena_seasons_history ON public.arena_seasons(starts_at DESC,id);

DO $$ DECLARE v_start timestamptz:=date_trunc('week',clock_timestamp()); BEGIN
  INSERT INTO public.arena_seasons(code,title,ruleset_version,status,starts_at,ends_at)
  VALUES ('launch-'||to_char(v_start,'YYYY-MM-DD'),'Launch season',1,'active',v_start,v_start+interval '28 days');
END $$;

CREATE TABLE public.arena_player_ratings (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating BETWEEN 0 AND 100000),
  peak_rating integer NOT NULL CHECK (peak_rating >= rating AND peak_rating BETWEEN 0 AND 100000),
  matches_played integer NOT NULL DEFAULT 0 CHECK (matches_played >= 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.arena_ranked_matches (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  season_id uuid NOT NULL REFERENCES public.arena_seasons(id) ON DELETE RESTRICT,
  ruleset_version integer NOT NULL REFERENCES public.arena_ranked_rulesets(version),
  request_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','expired','abandoned','invalid')),
  completion_reason text CHECK (completion_reason IN ('all_questions','time_expired','no_lives','abandoned','invalid')),
  question_count integer NOT NULL CHECK (question_count BETWEEN 5 AND 30),
  time_limit_seconds integer NOT NULL CHECK (time_limit_seconds BETWEEN 30 AND 600),
  initial_lives integer NOT NULL CHECK (initial_lives BETWEEN 1 AND 10),
  base_points integer NOT NULL CHECK (base_points BETWEEN 1 AND 1000),
  answered_count integer NOT NULL DEFAULT 0 CHECK (answered_count >= 0),
  correct_count integer NOT NULL DEFAULT 0 CHECK (correct_count >= 0),
  remaining_lives integer NOT NULL CHECK (remaining_lives >= 0),
  combo integer NOT NULL DEFAULT 0 CHECK (combo >= 0),
  max_combo integer NOT NULL DEFAULT 0 CHECK (max_combo >= combo),
  score integer NOT NULL DEFAULT 0 CHECK (score >= 0),
  rating_before integer CHECK (rating_before >= 0),
  rating_after integer CHECK (rating_after >= 0),
  rating_change integer,
  started_at timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  question_started_at timestamptz,
  completed_at timestamptz,
  duration_ms integer CHECK (duration_ms BETWEEN 0 AND 600000),
  rated_at timestamptz,
  suspicious boolean NOT NULL DEFAULT false,
  UNIQUE(user_id,request_id), UNIQUE(id,user_id),
  FOREIGN KEY(id,user_id) REFERENCES public.arena_sessions(id,user_id) ON DELETE CASCADE,
  CHECK (expires_at=started_at+time_limit_seconds*interval '1 second'),
  CHECK (answered_count<=question_count AND correct_count<=answered_count AND remaining_lives<=initial_lives),
  CHECK ((rated_at IS NULL)=(rating_change IS NULL)),
  CHECK ((status='active' AND completed_at IS NULL AND completion_reason IS NULL) OR
         (status<>'active' AND completed_at IS NOT NULL AND completion_reason IS NOT NULL))
);
CREATE UNIQUE INDEX arena_ranked_one_active ON public.arena_ranked_matches(user_id) WHERE status='active';
CREATE INDEX arena_ranked_history ON public.arena_ranked_matches(user_id,started_at DESC,id);
CREATE INDEX arena_ranked_weekly ON public.arena_ranked_matches(date_trunc('week',completed_at AT TIME ZONE 'UTC'),score DESC)
  WHERE rated_at IS NOT NULL AND status IN ('completed','expired');
CREATE INDEX arena_ranked_season_board ON public.arena_ranked_matches(season_id,ruleset_version,score DESC,completed_at,id)
  WHERE rated_at IS NOT NULL AND status IN ('completed','expired');

CREATE TABLE public.arena_ranked_answers (
  match_id uuid NOT NULL REFERENCES public.arena_ranked_matches(id) ON DELETE CASCADE,
  question_id uuid NOT NULL,
  request_id uuid NOT NULL,
  position integer NOT NULL CHECK(position>0),
  given_answer jsonb NOT NULL,
  question_started_at timestamptz NOT NULL,
  accepted_at timestamptz NOT NULL,
  elapsed_ms integer NOT NULL CHECK(elapsed_ms>=0),
  correct boolean NOT NULL,
  combo integer NOT NULL CHECK(combo>=0),
  multiplier_bps integer NOT NULL CHECK(multiplier_bps BETWEEN 10000 AND 20000),
  speed_bonus integer NOT NULL CHECK(speed_bonus IN (0,10,30,50)),
  points integer NOT NULL CHECK(points>=0),
  PRIMARY KEY(match_id,question_id), UNIQUE(match_id,request_id), UNIQUE(match_id,position),
  FOREIGN KEY(match_id,question_id) REFERENCES public.arena_session_questions(session_id,question_id) ON DELETE CASCADE
);

CREATE TABLE public.arena_rating_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  match_id uuid REFERENCES public.arena_ranked_matches(id) ON DELETE RESTRICT,
  season_id uuid REFERENCES public.arena_seasons(id) ON DELETE RESTRICT,
  kind text NOT NULL CHECK(kind IN ('match','season_adjustment','admin_correction')),
  rating_before integer NOT NULL CHECK(rating_before>=0),
  rating_after integer NOT NULL CHECK(rating_after>=0),
  rating_change integer NOT NULL,
  reason text NOT NULL CHECK(char_length(reason) BETWEEN 1 AND 240),
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(match_id), CHECK(rating_after=rating_before+rating_change)
);
CREATE INDEX arena_rating_events_recent ON public.arena_rating_events(user_id,created_at DESC,id);

CREATE TABLE public.arena_season_standings (
  season_id uuid NOT NULL REFERENCES public.arena_seasons(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  position integer NOT NULL CHECK(position>0),
  season_score integer NOT NULL CHECK(season_score>=0),
  qualifying_correct integer NOT NULL CHECK(qualifying_correct>=0),
  qualifying_questions integer NOT NULL CHECK(qualifying_questions>=0),
  matches_played integer NOT NULL CHECK(matches_played>=0),
  rating integer NOT NULL CHECK(rating>=0),
  tier text NOT NULL CHECK(tier IN ('bronze','silver','gold','platinum','diamond')),
  achieved_at timestamptz NOT NULL,
  finalized_at timestamptz NOT NULL,
  PRIMARY KEY(season_id,user_id), UNIQUE(season_id,position)
);

CREATE TABLE public.arena_season_rewards (
  season_id uuid NOT NULL REFERENCES public.arena_seasons(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reward_code text NOT NULL,
  badge_id uuid NOT NULL REFERENCES public.badges(id) ON DELETE RESTRICT,
  awarded_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(season_id,user_id,reward_code)
);

CREATE TABLE public.arena_ranked_security_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), match_id uuid NOT NULL REFERENCES public.arena_ranked_matches(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  signal text NOT NULL CHECK(signal IN ('implausible_speed','excessive_abandonment','malformed_request','rating_progression')),
  severity integer NOT NULL CHECK(severity BETWEEN 1 AND 5), details jsonb NOT NULL DEFAULT '{}'::jsonb,
  reviewed_at timestamptz, reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL, created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(match_id,signal)
);
CREATE INDEX arena_security_unreviewed ON public.arena_ranked_security_events(created_at DESC) WHERE reviewed_at IS NULL;

INSERT INTO public.badges(id,code,title,description,is_published)
SELECT gen_random_uuid(),v.code,v.title,'Quiz Arena seasonal achievement',true FROM (VALUES
 ('arena-season-bronze','Arena Bronze'),('arena-season-silver','Arena Silver'),('arena-season-gold','Arena Gold'),
 ('arena-season-platinum','Arena Platinum'),('arena-season-diamond','Arena Diamond'),('arena-season-top-10','Arena Top 10')) v(code,title)
ON CONFLICT(code) DO NOTHING;

DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['arena_ranked_rulesets','arena_seasons','arena_player_ratings','arena_ranked_matches','arena_ranked_answers','arena_rating_events','arena_season_standings','arena_season_rewards','arena_ranked_security_events'] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON public.%I FROM anon,authenticated',t);
  EXECUTE format('GRANT ALL ON public.%I TO service_role',t);
END LOOP; END $$;
GRANT SELECT ON public.arena_ranked_rulesets,public.arena_seasons TO authenticated;
CREATE POLICY ranked_rules_read ON public.arena_ranked_rulesets FOR SELECT TO authenticated USING(enabled OR public.englify_is_admin());
CREATE POLICY seasons_read ON public.arena_seasons FOR SELECT TO authenticated USING(true);
GRANT SELECT ON public.arena_player_ratings,public.arena_ranked_matches,public.arena_rating_events,public.arena_season_rewards TO authenticated;
CREATE POLICY rating_owner ON public.arena_player_ratings FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE POLICY match_owner ON public.arena_ranked_matches FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE POLICY rating_event_owner ON public.arena_rating_events FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE POLICY season_reward_owner ON public.arena_season_rewards FOR SELECT TO authenticated USING(user_id=auth.uid());

CREATE FUNCTION public.englify_arena_tier(p_rating integer) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN p_rating>=1600 THEN 'diamond' WHEN p_rating>=1400 THEN 'platinum' WHEN p_rating>=1200 THEN 'gold' WHEN p_rating>=1000 THEN 'silver' ELSE 'bronze' END
$$;
CREATE FUNCTION public.englify_ranked_rating_delta(p_score integer,p_correct integer,p_questions integer,p_reference integer,p_max integer,p_abandoned boolean)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN p_abandoned THEN -least(15,p_max) ELSE greatest(-p_max,least(p_max,round((((p_correct*100.0/p_questions)*0.70)+(least(p_score::numeric/p_reference,1)*100*0.30)-60)/2)::integer)) END
$$;
REVOKE ALL ON FUNCTION public.englify_arena_tier(integer),public.englify_ranked_rating_delta(integer,integer,integer,integer,integer,boolean) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.englify_ranked_close(p_id uuid,p_reason text,p_now timestamptz) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m public.arena_ranked_matches%ROWTYPE; r public.arena_ranked_rulesets%ROWTYPE; before_rating integer; delta integer; after_rating integer; end_at timestamptz; target_status text;
BEGIN
 SELECT * INTO m FROM public.arena_ranked_matches WHERE id=p_id FOR UPDATE;
 IF NOT FOUND OR m.status<>'active' THEN RETURN; END IF;
 SELECT * INTO r FROM public.arena_ranked_rulesets WHERE version=m.ruleset_version;
 end_at:=least(p_now,m.expires_at);
 target_status:=CASE p_reason WHEN 'time_expired' THEN 'expired' WHEN 'abandoned' THEN 'abandoned' WHEN 'invalid' THEN 'invalid' ELSE 'completed' END;
 INSERT INTO public.arena_player_ratings(user_id,rating,peak_rating) VALUES(m.user_id,r.initial_rating,r.initial_rating) ON CONFLICT(user_id) DO NOTHING;
 SELECT rating INTO before_rating FROM public.arena_player_ratings WHERE user_id=m.user_id FOR UPDATE;
 delta:=CASE WHEN target_status='invalid' THEN NULL ELSE public.englify_ranked_rating_delta(m.score,m.correct_count,m.question_count,r.reference_score,r.max_rating_change,target_status='abandoned') END;
 after_rating:=CASE WHEN delta IS NULL THEN before_rating ELSE greatest(0,before_rating+delta) END;
 IF delta IS NOT NULL THEN delta:=after_rating-before_rating; END IF;
 UPDATE public.arena_ranked_matches SET status=target_status,completion_reason=p_reason,completed_at=end_at,duration_ms=greatest(0,ceil(extract(epoch FROM end_at-started_at)*1000)::integer),
   rating_before=CASE WHEN delta IS NULL THEN NULL ELSE before_rating END,rating_after=CASE WHEN delta IS NULL THEN NULL ELSE after_rating END,rating_change=delta,rated_at=CASE WHEN delta IS NULL THEN NULL ELSE clock_timestamp() END
 WHERE id=p_id;
 UPDATE public.arena_sessions SET status=CASE WHEN target_status='invalid' THEN 'abandoned' ELSE 'completed' END,completed_at=end_at WHERE id=p_id;
 IF delta IS NOT NULL THEN
   UPDATE public.arena_player_ratings SET rating=after_rating,peak_rating=greatest(peak_rating,after_rating),matches_played=matches_played+1,updated_at=clock_timestamp() WHERE user_id=m.user_id;
   INSERT INTO public.arena_rating_events(user_id,match_id,season_id,kind,rating_before,rating_after,rating_change,reason)
     VALUES(m.user_id,m.id,m.season_id,'match',before_rating,after_rating,delta,'Verified ranked match');
 END IF;
 IF EXISTS(SELECT 1 FROM public.arena_ranked_answers WHERE match_id=m.id GROUP BY match_id HAVING count(*) FILTER(WHERE elapsed_ms<500)>=3) THEN
   INSERT INTO public.arena_ranked_security_events(match_id,user_id,signal,severity,details) VALUES(m.id,m.user_id,'implausible_speed',2,jsonb_build_object('answers_under_500ms',true)) ON CONFLICT DO NOTHING;
   UPDATE public.arena_ranked_matches SET suspicious=true WHERE id=m.id;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.englify_ranked_close(uuid,text,timestamptz) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.englify_ranked_view(p_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m public.arena_ranked_matches%ROWTYPE; p public.arena_sessions%ROWTYPE; q jsonb; review jsonb; last_answer jsonb;
BEGIN
 SELECT * INTO m FROM public.arena_ranked_matches WHERE id=p_id AND user_id=auth.uid(); IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Ranked match not found'; END IF;
 SELECT * INTO p FROM public.arena_sessions WHERE id=p_id;
 IF m.status='active' AND m.question_started_at IS NOT NULL THEN SELECT s.question INTO q FROM public.arena_session_questions s JOIN public.arena_questions bank ON bank.id=s.question_id WHERE s.session_id=p_id AND s.position=m.answered_count+1 AND bank.is_published AND bank.archived_at IS NULL; END IF;
 SELECT jsonb_build_object('question_id',question_id,'position',position,'correct',correct,'combo',combo,'points',points,'speed_bonus',speed_bonus) INTO last_answer FROM public.arena_ranked_answers WHERE match_id=p_id ORDER BY position DESC LIMIT 1;
 IF m.status<>'active' THEN SELECT coalesce(jsonb_agg(jsonb_build_object('question_id',a.question_id,'position',a.position,'given_answer',a.given_answer,'correct',a.correct,'points',a.points,'question',s.question,'correct_answer',s.answer,'explanation_vi',s.explanation_vi) ORDER BY a.position),'[]'::jsonb) INTO review FROM public.arena_ranked_answers a JOIN public.arena_session_questions s ON s.session_id=a.match_id AND s.question_id=a.question_id WHERE a.match_id=p_id; END IF;
 RETURN jsonb_build_object('server_now',clock_timestamp(),'match',to_jsonb(m)-'user_id'-'request_id','cefr_level',p.cefr_level,'current_question',q,'last_answer',last_answer,'review',review);
END $$;
REVOKE ALL ON FUNCTION public.englify_ranked_view(uuid) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.englify_ranked_start(p_request_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.arena_seasons%ROWTYPE; r public.arena_ranked_rulesets%ROWTYPE; old_match public.arena_ranked_matches%ROWTYPE; parent_id uuid; now_at timestamptz:=clock_timestamp();
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF; IF p_request_id IS NULL THEN RAISE EXCEPTION 'Request ID required' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text));
 SELECT * INTO old_match FROM public.arena_ranked_matches WHERE user_id=auth.uid() AND request_id=p_request_id;
 IF FOUND THEN RETURN public.englify_ranked_session(old_match.id); END IF;
 FOR old_match IN SELECT * FROM public.arena_ranked_matches WHERE user_id=auth.uid() AND status='active' FOR UPDATE LOOP
   IF clock_timestamp()>=old_match.expires_at THEN PERFORM public.englify_ranked_close(old_match.id,'time_expired',clock_timestamp()); ELSE RAISE SQLSTATE 'PT409' USING MESSAGE='Finish the active ranked match first'; END IF;
 END LOOP;
 SELECT * INTO s FROM public.arena_seasons WHERE status='active' AND now_at>=starts_at AND now_at<ends_at FOR SHARE; IF NOT FOUND THEN RAISE SQLSTATE 'PT409' USING MESSAGE='No active ranked season'; END IF;
 SELECT * INTO r FROM public.arena_ranked_rulesets WHERE version=s.ruleset_version AND enabled FOR SHARE; IF NOT FOUND THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Ranked rules are unavailable'; END IF;
 parent_id:=(public.englify_arena_start(p_request_id,r.cefr_level,NULL,NULL,r.question_count,NULL)->>'id')::uuid;
 UPDATE public.arena_sessions SET mode='ranked' WHERE id=parent_id;
 INSERT INTO public.arena_ranked_matches(id,user_id,season_id,ruleset_version,request_id,question_count,time_limit_seconds,initial_lives,base_points,remaining_lives,started_at,expires_at,question_started_at)
 VALUES(parent_id,auth.uid(),s.id,r.version,p_request_id,r.question_count,r.time_limit_seconds,r.initial_lives,r.base_points,r.initial_lives,now_at,now_at+r.time_limit_seconds*interval '1 second',now_at);
 RETURN public.englify_ranked_view(parent_id);
END $$;

CREATE FUNCTION public.englify_ranked_session(p_match_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m public.arena_ranked_matches%ROWTYPE; now_at timestamptz:=clock_timestamp();
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF; PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text));
 SELECT * INTO m FROM public.arena_ranked_matches WHERE id=p_match_id AND user_id=auth.uid() FOR UPDATE; IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Ranked match not found'; END IF;
 IF m.status='active' THEN
   IF now_at>=m.expires_at THEN PERFORM public.englify_ranked_close(m.id,'time_expired',now_at);
   ELSIF NOT EXISTS(SELECT 1 FROM public.arena_seasons WHERE id=m.season_id AND status IN ('active','closing')) THEN PERFORM public.englify_ranked_close(m.id,'invalid',now_at);
   ELSIF m.question_started_at IS NULL THEN UPDATE public.arena_ranked_matches SET question_started_at=clock_timestamp() WHERE id=m.id; END IF;
 END IF; RETURN public.englify_ranked_view(p_match_id); END $$;

CREATE FUNCTION public.englify_ranked_answer(p_match_id uuid,p_question_id uuid,p_request_id uuid,p_answer jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m public.arena_ranked_matches%ROWTYPE; a public.arena_ranked_answers%ROWTYPE; q record; now_at timestamptz; ok boolean; next_combo integer; elapsed integer; scored jsonb;
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 IF p_request_id IS NULL OR p_question_id IS NULL OR p_answer IS NULL OR octet_length(p_answer::text)>10000 THEN RAISE EXCEPTION 'Invalid ranked answer' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text)); SELECT * INTO m FROM public.arena_ranked_matches WHERE id=p_match_id AND user_id=auth.uid() FOR UPDATE; IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Ranked match not found'; END IF;
 SELECT * INTO a FROM public.arena_ranked_answers WHERE match_id=p_match_id AND request_id=p_request_id;
 IF FOUND THEN IF a.question_id<>p_question_id OR a.given_answer<>p_answer THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Request ID belongs to another answer'; END IF; RETURN public.englify_ranked_view(p_match_id); END IF;
 IF EXISTS(SELECT 1 FROM public.arena_ranked_answers WHERE match_id=p_match_id AND question_id=p_question_id) THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Question already answered'; END IF;
 IF m.status<>'active' THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Ranked match has ended'; END IF; now_at:=clock_timestamp();
 IF now_at>=m.expires_at THEN PERFORM public.englify_ranked_close(m.id,'time_expired',now_at); RETURN public.englify_ranked_view(m.id); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.arena_seasons WHERE id=m.season_id AND status IN ('active','closing')) THEN PERFORM public.englify_ranked_close(m.id,'invalid',now_at); RETURN public.englify_ranked_view(m.id); END IF;
 SELECT * INTO q FROM public.arena_session_questions WHERE session_id=m.id AND position=m.answered_count+1; IF q.question_id<>p_question_id OR m.question_started_at IS NULL THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Answer only the current question'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.arena_questions WHERE id=p_question_id AND is_published AND archived_at IS NULL) THEN PERFORM public.englify_ranked_close(m.id,'invalid',now_at); RETURN public.englify_ranked_view(m.id); END IF;
 ok:=public.englify_arena_grade(q.question,q.answer,p_answer); next_combo:=CASE WHEN ok THEN m.combo+1 ELSE 0 END; elapsed:=greatest(0,ceil(extract(epoch FROM now_at-m.question_started_at)*1000)::integer); scored:=public.englify_time_attack_points(ok,next_combo,elapsed,m.base_points);
 INSERT INTO public.arena_ranked_answers(match_id,question_id,request_id,position,given_answer,question_started_at,accepted_at,elapsed_ms,correct,combo,multiplier_bps,speed_bonus,points)
 VALUES(m.id,p_question_id,p_request_id,q.position,p_answer,m.question_started_at,now_at,elapsed,ok,next_combo,(scored->>'multiplier_bps')::integer,(scored->>'speed_bonus')::integer,(scored->>'points')::integer);
 UPDATE public.arena_ranked_matches SET answered_count=answered_count+1,correct_count=correct_count+CASE WHEN ok THEN 1 ELSE 0 END,remaining_lives=remaining_lives-CASE WHEN ok THEN 0 ELSE 1 END,combo=next_combo,max_combo=greatest(max_combo,next_combo),score=score+(scored->>'points')::integer,question_started_at=NULL WHERE id=m.id RETURNING * INTO m;
 IF m.remaining_lives=0 THEN PERFORM public.englify_ranked_close(m.id,'no_lives',now_at); ELSIF m.answered_count=m.question_count THEN PERFORM public.englify_ranked_close(m.id,'all_questions',now_at); END IF; RETURN public.englify_ranked_view(m.id); END $$;

CREATE FUNCTION public.englify_ranked_finalize(p_match_id uuid,p_abandon boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE m public.arena_ranked_matches%ROWTYPE; now_at timestamptz:=clock_timestamp(); BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF; PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text)); SELECT * INTO m FROM public.arena_ranked_matches WHERE id=p_match_id AND user_id=auth.uid() FOR UPDATE; IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Ranked match not found'; END IF;
 IF m.status='active' THEN IF now_at>=m.expires_at THEN PERFORM public.englify_ranked_close(m.id,'time_expired',now_at); ELSIF p_abandon THEN PERFORM public.englify_ranked_close(m.id,'abandoned',now_at); END IF; END IF; RETURN public.englify_ranked_view(m.id); END $$;

CREATE FUNCTION public.englify_ranked_me() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.arena_ranked_rulesets%ROWTYPE; current_rating integer; peak integer; played integer; s jsonb; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF; SELECT * INTO r FROM public.arena_ranked_rulesets WHERE enabled ORDER BY version DESC LIMIT 1; INSERT INTO public.arena_player_ratings(user_id,rating,peak_rating) VALUES(auth.uid(),r.initial_rating,r.initial_rating) ON CONFLICT DO NOTHING;
 SELECT rating,peak_rating,matches_played INTO current_rating,peak,played FROM public.arena_player_ratings WHERE user_id=auth.uid(); SELECT to_jsonb(x) INTO s FROM (SELECT id,code,title,ruleset_version,status,starts_at,ends_at,finalized_at FROM public.arena_seasons WHERE status IN ('active','closing') ORDER BY status='active' DESC,starts_at DESC LIMIT 1)x;
 RETURN jsonb_build_object('rating',current_rating,'peak_rating',peak,'matches_played',played,'tier',public.englify_arena_tier(current_rating),'peak_tier',public.englify_arena_tier(peak),'next_tier_rating',CASE WHEN current_rating<1000 THEN 1000 WHEN current_rating<1200 THEN 1200 WHEN current_rating<1400 THEN 1400 WHEN current_rating<1600 THEN 1600 ELSE NULL END,'season',s,'recent_changes',coalesce((SELECT jsonb_agg(to_jsonb(e) ORDER BY created_at DESC) FROM (SELECT rating_before,rating_after,rating_change,reason,created_at FROM public.arena_rating_events WHERE user_id=auth.uid() ORDER BY created_at DESC,id LIMIT 5)e),'[]'::jsonb)); END $$;

CREATE FUNCTION public.englify_ranked_history(p_page integer DEFAULT 1) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF; IF p_page NOT BETWEEN 1 AND 10000 THEN RAISE EXCEPTION 'Invalid page' USING ERRCODE='22023'; END IF; RETURN jsonb_build_object('page',p_page,'total',(SELECT count(*) FROM public.arena_ranked_matches WHERE user_id=auth.uid()),'items',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY started_at DESC,id) FROM (SELECT m.id,m.season_id,s.title AS season_title,m.ruleset_version,m.status,m.completion_reason,m.score,m.correct_count,m.answered_count,m.question_count,m.max_combo,m.rating_before,m.rating_after,m.rating_change,m.started_at,m.completed_at FROM public.arena_ranked_matches m JOIN public.arena_seasons s ON s.id=m.season_id WHERE m.user_id=auth.uid() ORDER BY m.started_at DESC,m.id LIMIT 10 OFFSET(p_page-1)*10)x),'[]'::jsonb)); END $$;

CREATE FUNCTION public.englify_ranked_leaderboard(p_scope text DEFAULT 'weekly',p_page integer DEFAULT 1,p_season_id uuid DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE sid uuid; from_at timestamptz; to_at timestamptz; total_count integer; result jsonb; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF; IF p_scope NOT IN ('weekly','season') OR p_page NOT BETWEEN 1 AND 1000 THEN RAISE EXCEPTION 'Invalid leaderboard request' USING ERRCODE='22023'; END IF;
 IF p_scope='weekly' THEN from_at:=date_trunc('week',clock_timestamp() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'; to_at:=from_at+interval '7 days'; SELECT id INTO sid FROM public.arena_seasons WHERE status IN ('active','closing') ORDER BY starts_at DESC LIMIT 1;
 ELSE SELECT id,starts_at,ends_at INTO sid,from_at,to_at FROM public.arena_seasons WHERE id=coalesce(p_season_id,(SELECT id FROM public.arena_seasons WHERE status IN ('active','closing','finalized') ORDER BY starts_at DESC LIMIT 1)); IF sid IS NULL THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Season not found'; END IF; END IF;
 WITH qualified AS (SELECT m.*,row_number() OVER(PARTITION BY m.user_id ORDER BY m.score DESC,m.correct_count DESC,m.completed_at,m.id) pick FROM public.arena_ranked_matches m WHERE m.season_id=sid AND m.rated_at IS NOT NULL AND m.status IN ('completed','expired') AND m.completed_at>=from_at AND m.completed_at<to_at), aggregates AS (SELECT user_id,sum(score)::integer score,sum(correct_count)::integer correct,sum(question_count)::integer questions,max(completed_at) achieved_at,count(*)::integer matches FROM qualified WHERE pick<=3 GROUP BY user_id), ranked AS (SELECT a.*,r.rating,public.englify_arena_tier(r.rating) tier,row_number() OVER(ORDER BY a.score DESC,a.correct::numeric/nullif(a.questions,0) DESC,a.achieved_at,a.user_id)::integer position FROM aggregates a JOIN public.arena_player_ratings r USING(user_id)) SELECT count(*) INTO total_count FROM ranked;
 WITH qualified AS (SELECT m.*,row_number() OVER(PARTITION BY m.user_id ORDER BY m.score DESC,m.correct_count DESC,m.completed_at,m.id) pick FROM public.arena_ranked_matches m WHERE m.season_id=sid AND m.rated_at IS NOT NULL AND m.status IN ('completed','expired') AND m.completed_at>=from_at AND m.completed_at<to_at), aggregates AS (SELECT user_id,sum(score)::integer score,sum(correct_count)::integer correct,sum(question_count)::integer questions,max(completed_at) achieved_at,(SELECT count(*) FROM public.arena_ranked_matches z WHERE z.user_id=q.user_id AND z.season_id=sid AND z.rated_at IS NOT NULL)::integer matches FROM qualified q WHERE pick<=3 GROUP BY user_id), ranked AS (SELECT a.*,r.rating,public.englify_arena_tier(r.rating) tier,row_number() OVER(ORDER BY a.score DESC,a.correct::numeric/nullif(a.questions,0) DESC,a.achieved_at,a.user_id)::integer position FROM aggregates a JOIN public.arena_player_ratings r USING(user_id)), visible AS (SELECT position,CASE WHEN trim(p.display_name)='' THEN 'Englify learner' ELSE left(trim(p.display_name),40) END display_name,tier,rating,score,correct,questions,matches,(ranked.user_id=auth.uid()) is_me FROM ranked JOIN public.profiles p ON p.id=ranked.user_id WHERE position BETWEEN (p_page-1)*50+1 AND p_page*50 ORDER BY position) SELECT coalesce(jsonb_agg(to_jsonb(visible) ORDER BY position),'[]'::jsonb) INTO result FROM visible;
 RETURN jsonb_build_object('scope',p_scope,'page',p_page,'page_size',50,'total',total_count,'starts_at',from_at,'ends_at',to_at,'season_id',sid,'items',result,'my_position',(WITH qualified AS (SELECT m.*,row_number() OVER(PARTITION BY m.user_id ORDER BY m.score DESC,m.correct_count DESC,m.completed_at,m.id) pick FROM public.arena_ranked_matches m WHERE m.season_id=sid AND m.rated_at IS NOT NULL AND m.status IN ('completed','expired') AND m.completed_at>=from_at AND m.completed_at<to_at), aggregates AS (SELECT user_id,sum(score) score,sum(correct_count) correct,sum(question_count) questions,max(completed_at) achieved_at FROM qualified WHERE pick<=3 GROUP BY user_id), z AS (SELECT user_id,row_number() OVER(ORDER BY score DESC,correct::numeric/nullif(questions,0) DESC,achieved_at,user_id)::integer position FROM aggregates) SELECT position FROM z WHERE user_id=auth.uid())); END $$;

CREATE FUNCTION public.englify_admin_upsert_arena_season(p_id uuid,p_code text,p_title text,p_ruleset integer,p_starts_at timestamptz,p_ends_at timestamptz) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE old public.arena_seasons%ROWTYPE; result public.arena_seasons%ROWTYPE; BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF; SELECT * INTO old FROM public.arena_seasons WHERE id=p_id FOR UPDATE; IF FOUND AND old.status='finalized' THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Finalized seasons are immutable'; END IF; INSERT INTO public.arena_seasons(id,code,title,ruleset_version,status,starts_at,ends_at,created_by) VALUES(coalesce(p_id,gen_random_uuid()),p_code,p_title,p_ruleset,'scheduled',p_starts_at,p_ends_at,auth.uid()) ON CONFLICT(id) DO UPDATE SET code=excluded.code,title=excluded.title,ruleset_version=excluded.ruleset_version,starts_at=excluded.starts_at,ends_at=excluded.ends_at,updated_at=clock_timestamp() RETURNING * INTO result; INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data) VALUES(auth.uid(),CASE WHEN old.id IS NULL THEN 'create' ELSE 'update' END,'arena-season',result.id,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(result)); RETURN to_jsonb(result); END $$;

CREATE FUNCTION public.englify_admin_transition_arena_season(p_id uuid,p_status text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.arena_seasons%ROWTYPE; now_at timestamptz:=clock_timestamp(); BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF; IF p_status NOT IN ('active','closing','finalized') THEN RAISE EXCEPTION 'Invalid transition' USING ERRCODE='22023'; END IF; SELECT * INTO s FROM public.arena_seasons WHERE id=p_id FOR UPDATE; IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Season not found'; END IF; IF s.status='finalized' THEN RETURN to_jsonb(s); END IF;
 IF (s.status='scheduled' AND p_status<>'active') OR (s.status='active' AND p_status NOT IN ('closing','finalized')) OR (s.status='closing' AND p_status<>'finalized') THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Invalid season transition'; END IF;
 IF p_status='active' AND EXISTS(SELECT 1 FROM public.arena_seasons WHERE status='active' AND id<>p_id) THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Another season is active'; END IF;
 IF p_status='finalized' THEN
   FOR s IN SELECT * FROM public.arena_ranked_matches WHERE season_id=p_id AND status='active' FOR UPDATE LOOP PERFORM public.englify_ranked_close(s.id,CASE WHEN now_at>=s.expires_at THEN 'time_expired' ELSE 'invalid' END,now_at); END LOOP;
   INSERT INTO public.arena_season_standings(season_id,user_id,position,season_score,qualifying_correct,qualifying_questions,matches_played,rating,tier,achieved_at,finalized_at)
   WITH q AS (SELECT m.*,row_number() OVER(PARTITION BY user_id ORDER BY score DESC,correct_count DESC,completed_at,id) pick FROM public.arena_ranked_matches m WHERE season_id=p_id AND rated_at IS NOT NULL AND status IN ('completed','expired')),a AS (SELECT user_id,sum(score)::integer score,sum(correct_count)::integer correct,sum(question_count)::integer questions,max(completed_at) achieved_at,count(*)::integer matches FROM q WHERE pick<=3 GROUP BY user_id),z AS (SELECT a.*,r.rating,public.englify_arena_tier(r.rating) tier,row_number() OVER(ORDER BY score DESC,correct::numeric/nullif(questions,0) DESC,achieved_at,user_id)::integer pos FROM a JOIN public.arena_player_ratings r USING(user_id)) SELECT p_id,user_id,pos,score,correct,questions,matches,rating,tier,achieved_at,now_at FROM z ON CONFLICT DO NOTHING;
   INSERT INTO public.arena_season_rewards(season_id,user_id,reward_code,badge_id) SELECT p_id,st.user_id,'tier:'||st.tier,b.id FROM public.arena_season_standings st JOIN public.badges b ON b.code='arena-season-'||st.tier WHERE st.season_id=p_id ON CONFLICT DO NOTHING;
   INSERT INTO public.arena_season_rewards(season_id,user_id,reward_code,badge_id) SELECT p_id,st.user_id,'top-10',b.id FROM public.arena_season_standings st CROSS JOIN public.badges b WHERE st.season_id=p_id AND st.position<=10 AND b.code='arena-season-top-10' ON CONFLICT DO NOTHING;
   INSERT INTO public.user_badges(user_id,badge_id) SELECT user_id,badge_id FROM public.arena_season_rewards WHERE season_id=p_id ON CONFLICT(user_id,badge_id) DO NOTHING;
 END IF;
 UPDATE public.arena_seasons SET status=p_status,finalized_at=CASE WHEN p_status='finalized' THEN now_at ELSE NULL END,updated_at=now_at WHERE id=p_id RETURNING * INTO s; INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data) VALUES(auth.uid(),'update','arena-season',s.id,NULL,to_jsonb(s)); RETURN to_jsonb(s); END $$;

CREATE FUNCTION public.englify_admin_arena_overview() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT CASE WHEN public.englify_is_admin() THEN jsonb_build_object('seasons',(SELECT coalesce(jsonb_agg(to_jsonb(s) ORDER BY starts_at DESC),'[]'::jsonb) FROM public.arena_seasons s),'rulesets',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY version DESC),'[]'::jsonb) FROM public.arena_ranked_rulesets r),'unreviewed_security_events',(SELECT count(*) FROM public.arena_ranked_security_events WHERE reviewed_at IS NULL),'recent_suspicious',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY created_at DESC),'[]'::jsonb) FROM (SELECT id,match_id,signal,severity,details,created_at FROM public.arena_ranked_security_events WHERE reviewed_at IS NULL ORDER BY created_at DESC LIMIT 30)x)) ELSE (SELECT pg_catalog.jsonb_build_object('error','forbidden') WHERE false) END $$;

REVOKE ALL ON FUNCTION public.englify_ranked_start(uuid),public.englify_ranked_session(uuid),public.englify_ranked_answer(uuid,uuid,uuid,jsonb),public.englify_ranked_finalize(uuid,boolean),public.englify_ranked_me(),public.englify_ranked_history(integer),public.englify_ranked_leaderboard(text,integer,uuid),public.englify_admin_upsert_arena_season(uuid,text,text,integer,timestamptz,timestamptz),public.englify_admin_transition_arena_season(uuid,text),public.englify_admin_arena_overview() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_ranked_start(uuid),public.englify_ranked_session(uuid),public.englify_ranked_answer(uuid,uuid,uuid,jsonb),public.englify_ranked_finalize(uuid,boolean),public.englify_ranked_me(),public.englify_ranked_history(integer),public.englify_ranked_leaderboard(text,integer,uuid),public.englify_admin_upsert_arena_season(uuid,text,text,integer,timestamptz,timestamptz),public.englify_admin_transition_arena_season(uuid,text),public.englify_admin_arena_overview() TO authenticated;
