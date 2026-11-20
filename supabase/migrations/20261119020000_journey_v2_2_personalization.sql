-- Journey V2.2: placement, explicit learner preferences, evidence-based profile,
-- explainable recommendations and stable daily plans. No historical rows are rewritten.

ALTER TABLE public.user_preferences
  ADD COLUMN journey_selected_cefr text,
  ADD COLUMN journey_recommended_cefr text,
  ADD COLUMN journey_primary_goal text,
  ADD COLUMN journey_preferred_skills text[] NOT NULL DEFAULT '{}',
  ADD COLUMN journey_target_days smallint[] NOT NULL DEFAULT '{}',
  ADD CONSTRAINT journey_selected_cefr_check CHECK (journey_selected_cefr IS NULL OR journey_selected_cefr IN ('A1','A2','B1','B2','C1')),
  ADD CONSTRAINT journey_recommended_cefr_check CHECK (journey_recommended_cefr IS NULL OR journey_recommended_cefr IN ('A1','A2','B1','B2','C1')),
  ADD CONSTRAINT journey_goal_check CHECK (journey_primary_goal IS NULL OR journey_primary_goal IN
    ('general','conversation','academic','work','travel','exam','grammar','vocabulary','writing','listening')),
  ADD CONSTRAINT journey_skills_check CHECK (journey_preferred_skills <@ ARRAY['reading','listening','speaking','writing','grammar','vocabulary']::text[]),
  ADD CONSTRAINT journey_days_check CHECK (journey_target_days <@ ARRAY[1,2,3,4,5,6,7]::smallint[]);

UPDATE public.user_preferences SET journey_selected_cefr=current_cefr
WHERE journey_selected_cefr IS NULL AND current_cefr IN ('A1','A2','B1','B2','C1');

CREATE FUNCTION public.englify_sync_journey_selected_cefr() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF NEW.current_cefr IS DISTINCT FROM OLD.current_cefr AND NEW.current_cefr IN ('A1','A2','B1','B2','C1') THEN
    NEW.journey_selected_cefr:=NEW.current_cefr;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER sync_journey_selected_cefr BEFORE UPDATE OF current_cefr ON public.user_preferences
FOR EACH ROW EXECUTE FUNCTION public.englify_sync_journey_selected_cefr();
REVOKE ALL ON FUNCTION public.englify_sync_journey_selected_cefr() FROM PUBLIC,anon,authenticated;

CREATE TABLE public.journey_placement_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text NOT NULL UNIQUE,
  skill text NOT NULL CHECK (skill IN ('grammar','vocabulary','reading')),
  cefr_level text NOT NULL CHECK (cefr_level IN ('A1','A2','B1','B2','C1')),
  difficulty smallint NOT NULL CHECK (difficulty BETWEEN 1 AND 5),
  prompt text NOT NULL, options jsonb NOT NULL CHECK (jsonb_typeof(options)='array' AND jsonb_array_length(options) BETWEEN 2 AND 6),
  answer_index smallint NOT NULL, explanation text NOT NULL DEFAULT '', is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), CHECK (answer_index>=0 AND answer_index<jsonb_array_length(options))
);
CREATE TABLE public.journey_placement_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','completed','abandoned')),
  algorithm_version smallint NOT NULL DEFAULT 1, question_ids uuid[] NOT NULL,
  recommended_cefr text CHECK (recommended_cefr IN ('A1','A2','B1','B2','C1')),
  confidence text CHECK (confidence IN ('low','medium','high')), score_payload jsonb,
  started_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz
);
CREATE INDEX journey_placement_sessions_user_idx ON public.journey_placement_sessions(user_id,started_at DESC);
CREATE TABLE public.journey_placement_responses (
  session_id uuid NOT NULL REFERENCES public.journey_placement_sessions(id) ON DELETE CASCADE,
  question_id uuid NOT NULL REFERENCES public.journey_placement_questions(id), selected_index smallint NOT NULL CHECK(selected_index>=0),
  is_correct boolean NOT NULL, answered_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY(session_id,question_id)
);

CREATE TABLE public.journey_daily_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  local_date date NOT NULL, timezone text NOT NULL, algorithm_version smallint NOT NULL DEFAULT 1,
  preferences_snapshot jsonb NOT NULL, created_at timestamptz NOT NULL DEFAULT now(), refreshed_at timestamptz,
  UNIQUE(user_id,local_date)
);
CREATE TABLE public.journey_daily_plan_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), plan_id uuid NOT NULL REFERENCES public.journey_daily_plans(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, position smallint NOT NULL CHECK(position>0),
  kind text NOT NULL CHECK(kind IN ('lesson','quiz_practice','mistake_review','writing','vocabulary_review')),
  lesson_id uuid REFERENCES public.lessons(id) ON DELETE SET NULL, title text NOT NULL, estimated_minutes smallint NOT NULL CHECK(estimated_minutes BETWEEN 1 AND 60),
  reason_code text NOT NULL, completed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(plan_id,position)
);
CREATE INDEX journey_daily_items_user_idx ON public.journey_daily_plan_items(user_id,created_at DESC);

ALTER TABLE public.journey_placement_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_placement_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_placement_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_daily_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_daily_plan_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.journey_placement_questions,public.journey_placement_sessions,public.journey_placement_responses,
  public.journey_daily_plans,public.journey_daily_plan_items FROM anon,authenticated;
GRANT ALL ON public.journey_placement_questions,public.journey_placement_sessions,public.journey_placement_responses,
  public.journey_daily_plans,public.journey_daily_plan_items TO service_role;
GRANT SELECT ON public.journey_placement_sessions,public.journey_placement_responses,public.journey_daily_plans,public.journey_daily_plan_items TO authenticated;
CREATE POLICY journey_placement_sessions_own_read ON public.journey_placement_sessions FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
CREATE POLICY journey_placement_responses_own_read ON public.journey_placement_responses FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.journey_placement_sessions s WHERE s.id=session_id AND s.user_id=(SELECT auth.uid())));
CREATE POLICY journey_daily_plans_own_read ON public.journey_daily_plans FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
CREATE POLICY journey_daily_items_own_read ON public.journey_daily_plan_items FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));

INSERT INTO public.journey_placement_questions(code,skill,cefr_level,difficulty,prompt,options,answer_index,is_published) VALUES
('a1-g-1','grammar','A1',1,'She ___ from Vietnam.','["am","is","are","be"]',1,true),
('a1-v-1','vocabulary','A1',1,'Which word means “rất lớn”?','["tiny","huge","slow","quiet"]',1,true),
('a1-r-1','reading','A1',1,'Lan gets up at seven and walks to school. How does Lan go to school?','["By bus","On foot","By bike","By train"]',1,true),
('a2-g-1','grammar','A2',2,'I have lived here ___ 2022.','["for","since","from","during"]',1,true),
('a2-v-1','vocabulary','A2',2,'A place where you borrow books is a ___.','["bakery","library","factory","station"]',1,true),
('a2-r-1','reading','A2',2,'The shop closes at 6 p.m., but on Friday it stays open until 8. When does it close on Friday?','["6 p.m.","7 p.m.","8 p.m.","9 p.m."]',2,true),
('b1-g-1','grammar','B1',3,'If it ___ tomorrow, we will stay home.','["rains","rained","will rain","would rain"]',0,true),
('b1-v-1','vocabulary','B1',3,'The closest meaning of “reliable” is ___.','["expensive","dependable","ordinary","temporary"]',1,true),
('b1-r-1','reading','B1',3,'Although the train was delayed, Minh arrived before the meeting began. What is true?','["He missed the meeting","He arrived in time","The meeting was cancelled","The train was early"]',1,true),
('b2-g-1','grammar','B2',4,'By next June, they ___ the project.','["finish","will finish","will have finished","had finished"]',2,true),
('b2-v-1','vocabulary','B2',4,'“The proposal was rejected” means it was ___.','["accepted","postponed","not accepted","published"]',2,true),
('b2-r-1','reading','B2',4,'The policy reduced costs; nevertheless, staff questioned whether the savings were sustainable. What was questioned?','["The policy existed","The savings would last","Staff costs rose","Costs were measured"]',1,true),
('c1-g-1','grammar','C1',5,'Rarely ___ such a compelling argument.','["I heard","have I heard","I have heard","did I have heard"]',1,true),
('c1-v-1','vocabulary','C1',5,'“Ubiquitous” most nearly means ___.','["rare","harmful","present everywhere","carefully hidden"]',2,true),
('c1-r-1','reading','C1',5,'The author concedes the method is efficient, yet cautions that efficiency alone cannot justify its ethical cost. What is the stance?','["Unqualified support","Efficiency is irrelevant","Qualified criticism","No clear opinion"]',2,true)
ON CONFLICT(code) DO NOTHING;

CREATE FUNCTION public.englify_update_journey_goals(p_selected_cefr text,p_goal text,p_daily_minutes integer,p_skills text[],p_target_days smallint[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); result jsonb;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 IF p_selected_cefr NOT IN ('A1','A2','B1','B2','C1') OR p_goal NOT IN ('general','conversation','academic','work','travel','exam','grammar','vocabulary','writing','listening')
   OR p_daily_minutes NOT IN (10,15,20,30) OR NOT coalesce(p_skills,'{}') <@ ARRAY['reading','listening','speaking','writing','grammar','vocabulary']::text[]
   OR NOT coalesce(p_target_days,'{}') <@ ARRAY[1,2,3,4,5,6,7]::smallint[] THEN RAISE EXCEPTION 'Invalid learning preferences' USING ERRCODE='22023'; END IF;
 INSERT INTO public.user_preferences(user_id,journey_selected_cefr,journey_primary_goal,daily_goal_minutes,journey_preferred_skills,journey_target_days,current_cefr)
 VALUES(uid,p_selected_cefr,p_goal,p_daily_minutes,coalesce(p_skills,'{}'),coalesce(p_target_days,'{}'),p_selected_cefr)
 ON CONFLICT(user_id) DO UPDATE SET journey_selected_cefr=excluded.journey_selected_cefr,journey_primary_goal=excluded.journey_primary_goal,
   daily_goal_minutes=excluded.daily_goal_minutes,journey_preferred_skills=excluded.journey_preferred_skills,journey_target_days=excluded.journey_target_days,current_cefr=excluded.current_cefr;
 SELECT jsonb_build_object('selected_cefr',journey_selected_cefr,'recommended_cefr',journey_recommended_cefr,'goal',journey_primary_goal,
   'daily_minutes',daily_goal_minutes,'preferred_skills',journey_preferred_skills,'target_days',journey_target_days) INTO result FROM public.user_preferences WHERE user_id=uid;
 RETURN result;
END $$;

CREATE FUNCTION public.englify_start_journey_placement_test() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); sid uuid; qids uuid[];
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 UPDATE public.journey_placement_sessions SET status='abandoned' WHERE user_id=uid AND status='active';
 SELECT array_agg(id ORDER BY difficulty,skill,code) INTO qids FROM public.journey_placement_questions WHERE is_published;
 IF coalesce(cardinality(qids),0)<15 THEN RAISE EXCEPTION 'Placement bank does not have enough validated coverage' USING ERRCODE='55000'; END IF;
 INSERT INTO public.journey_placement_sessions(user_id,question_ids) VALUES(uid,qids) RETURNING id INTO sid;
 RETURN jsonb_build_object('session_id',sid,'questions',(SELECT jsonb_agg(jsonb_build_object('id',q.id,'skill',q.skill,'cefr_level',q.cefr_level,'prompt',q.prompt,'options',q.options) ORDER BY q.difficulty,q.skill,q.code) FROM public.journey_placement_questions q WHERE q.id=ANY(qids)));
END $$;

CREATE FUNCTION public.englify_submit_journey_placement_answer(p_session uuid,p_question uuid,p_selected_index smallint) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); correct boolean;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.journey_placement_sessions WHERE id=p_session AND user_id=uid AND status='active' AND p_question=ANY(question_ids)) THEN RAISE EXCEPTION 'Active assessment question not found' USING ERRCODE='P0002'; END IF;
 SELECT p_selected_index=answer_index INTO correct FROM public.journey_placement_questions WHERE id=p_question AND p_selected_index>=0 AND p_selected_index<jsonb_array_length(options);
 IF correct IS NULL THEN RAISE EXCEPTION 'Invalid answer' USING ERRCODE='22023'; END IF;
 INSERT INTO public.journey_placement_responses(session_id,question_id,selected_index,is_correct) VALUES(p_session,p_question,p_selected_index,correct);
 RETURN jsonb_build_object('accepted',true);
 EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'Question already answered' USING ERRCODE='23505';
END $$;

CREATE FUNCTION public.englify_finalize_journey_placement_test(p_session uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); total int; covered int; weighted numeric; max_weight numeric; ratio numeric; level text; v_confidence text; payload jsonb;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 SELECT count(*),count(DISTINCT q.skill),coalesce(sum(CASE WHEN r.is_correct THEN q.difficulty ELSE 0 END),0),sum(q.difficulty)
 INTO total,covered,weighted,max_weight FROM public.journey_placement_sessions s JOIN public.journey_placement_responses r ON r.session_id=s.id JOIN public.journey_placement_questions q ON q.id=r.question_id
 WHERE s.id=p_session AND s.user_id=uid AND s.status='active';
 IF total<12 THEN RAISE EXCEPTION 'Answer at least 12 questions before finalizing' USING ERRCODE='22023'; END IF;
 ratio:=weighted/nullif(max_weight,0); level:=CASE WHEN ratio>=.86 THEN 'C1' WHEN ratio>=.70 THEN 'B2' WHEN ratio>=.52 THEN 'B1' WHEN ratio>=.32 THEN 'A2' ELSE 'A1' END;
 v_confidence:=CASE WHEN total>=15 AND covered=3 THEN 'high' WHEN covered=3 THEN 'medium' ELSE 'low' END;
 SELECT jsonb_build_object('weighted_ratio',round(ratio,3),'answered',total,'coverage',covered,'skills',jsonb_object_agg(skill,jsonb_build_object('attempts',attempts,'correct',correct))) INTO payload
 FROM (SELECT q.skill,count(*) attempts,count(*) FILTER(WHERE r.is_correct) correct FROM public.journey_placement_responses r JOIN public.journey_placement_questions q ON q.id=r.question_id WHERE r.session_id=p_session GROUP BY q.skill) x;
 UPDATE public.journey_placement_sessions SET status='completed',recommended_cefr=level,confidence=v_confidence,score_payload=payload,completed_at=now() WHERE id=p_session AND user_id=uid AND status='active';
 IF NOT FOUND THEN RAISE EXCEPTION 'Active assessment not found' USING ERRCODE='P0002'; END IF;
 INSERT INTO public.user_preferences(user_id,journey_recommended_cefr) VALUES(uid,level) ON CONFLICT(user_id) DO UPDATE SET journey_recommended_cefr=excluded.journey_recommended_cefr;
 RETURN jsonb_build_object('recommended_cefr',level,'confidence',v_confidence,'evidence',payload,'disclaimer','This is a suggested starting level, not an official CEFR certification.');
END $$;

CREATE FUNCTION public.englify_journey_learning_profile() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); pref record; skills jsonb; recs jsonb;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 SELECT * INTO pref FROM public.user_preferences WHERE user_id=uid;
 SELECT jsonb_object_agg(s.skill,jsonb_build_object('attempts',s.attempts,'last_practiced_at',s.last_at,'estimated_percent',CASE WHEN s.attempts>=3 THEN round(100.0*s.correct/nullif(s.attempts,0)) ELSE NULL END,'data_sufficient',s.attempts>=3)) INTO skills FROM (
   SELECT skill,sum(attempts)::int attempts,sum(correct)::int correct,max(last_at) last_at FROM (
     SELECT CASE WHEN q.kind='grammar' THEN 'grammar' ELSE 'vocabulary' END skill,count(*) attempts,count(*) FILTER(WHERE a.is_correct) correct,max(a.created_at) last_at FROM public.quiz_attempts a JOIN public.quiz_questions q ON q.id=a.question_id WHERE a.user_id=uid GROUP BY 1
     UNION ALL SELECT 'writing',count(*),count(*) FILTER(WHERE f.rule_result='matched'),max(s.created_at)
       FROM public.writing_submissions s JOIN public.writing_feedback f ON f.submission_id=s.id WHERE s.user_id=uid
   ) evidence GROUP BY skill
 ) s;
 SELECT coalesce(jsonb_agg(item),'[]') INTO recs FROM (SELECT jsonb_build_object('lesson_id',l.id,'title',l.title,'cefr_level',c.cefr_level,'target_skill',CASE WHEN lower(u.title) LIKE '%grammar%' THEN 'grammar' WHEN lower(u.title) LIKE '%vocab%' THEN 'vocabulary' ELSE 'reading' END,
   'reason_code',CASE WHEN public.englify_lesson_state(l.id)='in_progress' THEN 'continue_in_progress' ELSE 'eligible_next' END,
   'reason_vi',CASE WHEN public.englify_lesson_state(l.id)='in_progress' THEN 'Tiếp tục bài học bạn đang thực hiện.' ELSE 'Bài học phù hợp với trình độ đã chọn và đủ điều kiện tiên quyết.' END,
   'destination','/lesson/'||l.id) item FROM public.lessons l JOIN public.courses c ON c.id=l.course_id JOIN public.learning_units u ON u.id=l.unit_id
   WHERE l.is_published AND l.archived_at IS NULL AND c.is_published AND c.archived_at IS NULL AND public.englify_lesson_state(l.id) IN ('available','in_progress')
     AND (pref.journey_selected_cefr IS NULL OR c.cefr_level=pref.journey_selected_cefr)
   ORDER BY CASE public.englify_lesson_state(l.id) WHEN 'in_progress' THEN 0 ELSE 1 END,u.position,l.position LIMIT 5) ranked;
 RETURN jsonb_build_object('selected_cefr',pref.journey_selected_cefr,'recommended_cefr',pref.journey_recommended_cefr,'goal',pref.journey_primary_goal,
   'daily_minutes',coalesce(pref.daily_goal_minutes,10),'skills',coalesce(skills,'{}'),'recommendations',recs,
   'insight',CASE WHEN skills IS NULL THEN 'Chưa đủ dữ liệu. Hãy hoàn thành một vài hoạt động để nhận phân tích kỹ năng.' ELSE 'Ước tính chỉ dựa trên các lượt đánh giá đủ điều kiện, không phải chứng nhận CEFR.' END);
END $$;

CREATE FUNCTION public.englify_journey_daily_plan(p_timezone text DEFAULT 'Asia/Ho_Chi_Minh',p_refresh boolean DEFAULT false) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); today date; pid uuid; minutes int; remaining int; lesson record; profile jsonb;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 IF length(p_timezone)>64 THEN RAISE EXCEPTION 'Invalid timezone' USING ERRCODE='22023'; END IF;
 BEGIN today:=(now() AT TIME ZONE p_timezone)::date; EXCEPTION WHEN invalid_parameter_value THEN RAISE EXCEPTION 'Invalid timezone' USING ERRCODE='22023'; END;
 SELECT id INTO pid FROM public.journey_daily_plans WHERE user_id=uid AND local_date=today FOR UPDATE;
 IF pid IS NULL THEN
   profile:=public.englify_journey_learning_profile(); minutes:=coalesce((profile->>'daily_minutes')::int,10);
   INSERT INTO public.journey_daily_plans(user_id,local_date,timezone,preferences_snapshot) VALUES(uid,today,p_timezone,profile-'recommendations') RETURNING id INTO pid;
 ELSIF p_refresh THEN DELETE FROM public.journey_daily_plan_items WHERE plan_id=pid;
 ELSE RETURN jsonb_build_object('id',pid,'local_date',today,'items',(SELECT coalesce(jsonb_agg(to_jsonb(i) ORDER BY position),'[]') FROM public.journey_daily_plan_items i WHERE i.plan_id=pid)); END IF;
 IF NOT EXISTS(SELECT 1 FROM public.journey_daily_plan_items WHERE plan_id=pid) THEN
   minutes:=coalesce(minutes,(SELECT daily_goal_minutes FROM public.user_preferences WHERE user_id=uid),10); remaining:=minutes;
   FOR lesson IN SELECT l.id,l.title,least(l.estimated_minutes,remaining) duration FROM public.lessons l JOIN public.courses c ON c.id=l.course_id
     WHERE l.is_published AND l.archived_at IS NULL AND c.is_published AND c.archived_at IS NULL AND public.englify_lesson_state(l.id) IN ('available','in_progress')
       AND ((SELECT journey_selected_cefr FROM public.user_preferences WHERE user_id=uid) IS NULL OR c.cefr_level=(SELECT journey_selected_cefr FROM public.user_preferences WHERE user_id=uid))
     ORDER BY CASE public.englify_lesson_state(l.id) WHEN 'in_progress' THEN 0 ELSE 1 END,l.position LIMIT 2
   LOOP EXIT WHEN remaining<=0; INSERT INTO public.journey_daily_plan_items(plan_id,user_id,position,kind,lesson_id,title,estimated_minutes,reason_code)
     VALUES(pid,uid,(SELECT count(*)+1 FROM public.journey_daily_plan_items WHERE plan_id=pid),'lesson',lesson.id,lesson.title,greatest(1,lesson.duration),'eligible_lesson'); remaining:=remaining-lesson.duration; END LOOP;
 END IF;
 RETURN jsonb_build_object('id',pid,'local_date',today,'items',(SELECT coalesce(jsonb_agg(to_jsonb(i) ORDER BY position),'[]') FROM public.journey_daily_plan_items i WHERE i.plan_id=pid));
END $$;

REVOKE ALL ON FUNCTION public.englify_update_journey_goals(text,text,integer,text[],smallint[]),public.englify_start_journey_placement_test(),
 public.englify_submit_journey_placement_answer(uuid,uuid,smallint),public.englify_finalize_journey_placement_test(uuid),
 public.englify_journey_learning_profile(),public.englify_journey_daily_plan(text,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_update_journey_goals(text,text,integer,text[],smallint[]),public.englify_start_journey_placement_test(),
 public.englify_submit_journey_placement_answer(uuid,uuid,smallint),public.englify_finalize_journey_placement_test(uuid),
 public.englify_journey_learning_profile(),public.englify_journey_daily_plan(text,boolean) TO authenticated;
