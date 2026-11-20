-- Journey V2.4: authoritative unit checkpoint snapshots, mastery and objective review.
CREATE TABLE public.journey_checkpoint_configs (
 lesson_id uuid PRIMARY KEY REFERENCES public.lessons(id) ON DELETE RESTRICT,
 unit_id uuid NOT NULL REFERENCES public.learning_units(id) ON DELETE RESTRICT,
 passing_percent smallint NOT NULL DEFAULT 70 CHECK(passing_percent=70),
 objectives jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(objectives)='array' AND jsonb_array_length(objectives)>0),
 reward_xp smallint NOT NULL DEFAULT 20 CHECK(reward_xp BETWEEN 0 AND 100), is_published boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX journey_checkpoint_one_per_unit ON public.journey_checkpoint_configs(unit_id);
CREATE TABLE public.journey_checkpoint_attempts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 checkpoint_id uuid NOT NULL REFERENCES public.journey_checkpoint_configs(lesson_id) ON DELETE RESTRICT,
 unit_id uuid NOT NULL REFERENCES public.learning_units(id) ON DELETE RESTRICT, lesson_attempt_id uuid NOT NULL UNIQUE REFERENCES public.lesson_attempts(id) ON DELETE RESTRICT,
 request_id uuid NOT NULL, question_ids uuid[] NOT NULL, content_version text NOT NULL, correct_count int NOT NULL,
 question_count int NOT NULL CHECK(question_count>0), score_percent numeric(5,2) NOT NULL CHECK(score_percent BETWEEN 0 AND 100),
 passing_percent smallint NOT NULL, passed boolean NOT NULL, objective_results jsonb NOT NULL DEFAULT '[]', created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(user_id,request_id)
);
CREATE INDEX journey_checkpoint_attempts_user_idx ON public.journey_checkpoint_attempts(user_id,checkpoint_id,created_at DESC);
CREATE TABLE public.journey_mastery_progress (
 user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, unit_id uuid NOT NULL REFERENCES public.learning_units(id) ON DELETE CASCADE,
 state text NOT NULL CHECK(state IN ('not_started','learning','practicing','proficient','mastered')),
 qualifying_attempts int NOT NULL DEFAULT 0, successful_attempts int NOT NULL DEFAULT 0, recent_accuracy numeric(5,2),
 last_evidence_at timestamptz, updated_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(user_id,unit_id)
);
CREATE TABLE public.journey_objective_reviews (
 user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, checkpoint_id uuid NOT NULL REFERENCES public.journey_checkpoint_configs(lesson_id) ON DELETE CASCADE,
 objective_code text NOT NULL, stage smallint NOT NULL DEFAULT 0 CHECK(stage BETWEEN 0 AND 5), next_review_at timestamptz NOT NULL,
 incorrect_count int NOT NULL DEFAULT 0, successful_reviews int NOT NULL DEFAULT 0, updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,checkpoint_id,objective_code)
);
ALTER TABLE public.journey_checkpoint_configs ENABLE ROW LEVEL SECURITY; ALTER TABLE public.journey_checkpoint_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_mastery_progress ENABLE ROW LEVEL SECURITY; ALTER TABLE public.journey_objective_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.journey_checkpoint_configs,public.journey_checkpoint_attempts,public.journey_mastery_progress,public.journey_objective_reviews FROM anon,authenticated;
GRANT ALL ON public.journey_checkpoint_configs,public.journey_checkpoint_attempts,public.journey_mastery_progress,public.journey_objective_reviews TO service_role;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.journey_checkpoint_configs TO authenticated;
GRANT SELECT ON public.journey_checkpoint_attempts,public.journey_mastery_progress,public.journey_objective_reviews TO authenticated;
CREATE POLICY checkpoint_config_read ON public.journey_checkpoint_configs FOR SELECT TO authenticated USING(is_published OR public.englify_is_admin());
CREATE POLICY checkpoint_config_admin ON public.journey_checkpoint_configs FOR ALL TO authenticated USING(public.englify_is_admin()) WITH CHECK(public.englify_is_admin());
CREATE POLICY checkpoint_attempt_own ON public.journey_checkpoint_attempts FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
CREATE POLICY mastery_own ON public.journey_mastery_progress FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
CREATE POLICY objective_review_own ON public.journey_objective_reviews FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));

CREATE FUNCTION public.englify_checkpoint_eligible(p_checkpoint uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.journey_checkpoint_configs c JOIN public.lessons cp ON cp.id=c.lesson_id
  WHERE c.lesson_id=p_checkpoint AND c.is_published AND cp.is_published AND cp.archived_at IS NULL
   AND NOT EXISTS(SELECT 1 FROM public.lessons l LEFT JOIN public.learning_progress p ON p.lesson_id=l.id AND p.user_id=auth.uid()
    WHERE l.unit_id=c.unit_id AND l.is_required AND l.lesson_kind<>'checkpoint' AND l.is_published AND l.archived_at IS NULL AND coalesce(p.status,'') NOT IN ('completed','mastered')))
$$;
REVOKE ALL ON FUNCTION public.englify_checkpoint_eligible(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_checkpoint_eligible(uuid) TO authenticated;

CREATE FUNCTION public.englify_submit_checkpoint(p_checkpoint uuid,p_request_id uuid,p_answers jsonb,p_content_version text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); cfg record; result jsonb; attempt uuid; score numeric; snapshot public.journey_checkpoint_attempts; prior_pass boolean;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 SELECT c.* INTO cfg FROM public.journey_checkpoint_configs c JOIN public.lessons l ON l.id=c.lesson_id AND l.lesson_kind='checkpoint' WHERE c.lesson_id=p_checkpoint AND c.is_published FOR SHARE;
 IF cfg.lesson_id IS NULL OR cfg.passing_percent<>70 OR NOT public.englify_checkpoint_eligible(p_checkpoint) THEN RAISE EXCEPTION 'Checkpoint prerequisites are not complete or policy is unsupported' USING ERRCODE='42501'; END IF;
 SELECT EXISTS(SELECT 1 FROM public.journey_checkpoint_attempts WHERE user_id=uid AND checkpoint_id=p_checkpoint AND passed) INTO prior_pass;
 result:=public.englify_submit_lesson(p_checkpoint,p_request_id,p_answers,p_content_version); attempt:=(result->>'attempt_id')::uuid;
 score:=round(100.0*(result->>'correct_count')::int/greatest((result->>'question_count')::int,1),2);
 INSERT INTO public.journey_checkpoint_attempts(user_id,checkpoint_id,unit_id,lesson_attempt_id,request_id,question_ids,content_version,correct_count,question_count,score_percent,passing_percent,passed,objective_results)
 SELECT uid,p_checkpoint,cfg.unit_id,attempt,p_request_id,array_agg(a.question_id ORDER BY a.question_id),coalesce(p_content_version,public.englify_lesson_content_version(p_checkpoint)),
  (result->>'correct_count')::int,(result->>'question_count')::int,score,cfg.passing_percent,score>=cfg.passing_percent,
  jsonb_build_array(jsonb_build_object('code','unit-objectives','passed',score>=cfg.passing_percent,'accuracy',score))
 FROM public.lesson_answer_attempts a WHERE a.attempt_id=attempt
 ON CONFLICT(user_id,request_id) DO UPDATE SET request_id=excluded.request_id RETURNING * INTO snapshot;
 INSERT INTO public.journey_mastery_progress(user_id,unit_id,state,qualifying_attempts,successful_attempts,recent_accuracy,last_evidence_at)
 VALUES(uid,cfg.unit_id,CASE WHEN snapshot.passed AND score>=90 AND prior_pass THEN 'mastered' WHEN snapshot.passed THEN 'proficient' ELSE 'practicing' END,1,CASE WHEN snapshot.passed THEN 1 ELSE 0 END,score,now())
 ON CONFLICT(user_id,unit_id) DO UPDATE SET qualifying_attempts=journey_mastery_progress.qualifying_attempts+1,
  successful_attempts=journey_mastery_progress.successful_attempts+CASE WHEN snapshot.passed THEN 1 ELSE 0 END,recent_accuracy=score,last_evidence_at=now(),updated_at=now(),
  state=CASE WHEN snapshot.passed AND score>=90 AND journey_mastery_progress.successful_attempts>=1 THEN 'mastered' WHEN snapshot.passed THEN 'proficient' ELSE 'practicing' END;
 IF NOT snapshot.passed THEN
  INSERT INTO public.journey_objective_reviews(user_id,checkpoint_id,objective_code,next_review_at,incorrect_count)
  VALUES(uid,p_checkpoint,'unit-objectives',now()+interval '10 minutes',1)
  ON CONFLICT(user_id,checkpoint_id,objective_code) DO UPDATE SET stage=0,next_review_at=now()+interval '10 minutes',incorrect_count=journey_objective_reviews.incorrect_count+1,updated_at=now();
 END IF;
 RETURN result||jsonb_build_object('checkpoint',to_jsonb(snapshot),'mastery',(SELECT to_jsonb(m) FROM public.journey_mastery_progress m WHERE m.user_id=uid AND m.unit_id=cfg.unit_id),
  'recommendations',CASE WHEN snapshot.passed THEN '[]'::jsonb ELSE jsonb_build_array(jsonb_build_object('reason_code','failed_checkpoint','reason_vi','Hãy ôn lại các bài bắt buộc trong Unit trước khi thử lại.','destination','/journey')) END);
END $$;
REVOKE ALL ON FUNCTION public.englify_submit_checkpoint(uuid,uuid,jsonb,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_submit_checkpoint(uuid,uuid,jsonb,text) TO authenticated;
