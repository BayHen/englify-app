-- Quiz Arena V2.4: real mistake history, deterministic review and recommendations.
CREATE TABLE public.quiz_answer_facts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  question_source text NOT NULL CHECK(question_source IN ('journey','arena')),
  question_id uuid NOT NULL,
  source_mode text NOT NULL CHECK(source_mode IN ('journey','practice','time_attack','ranked')),
  source_attempt_id uuid NOT NULL,
  given_answer jsonb NOT NULL,
  is_correct boolean NOT NULL,
  cefr_level text NOT NULL CHECK(cefr_level IN ('A1','A2','B1','B2','C1')),
  topic text NOT NULL CHECK(char_length(topic) BETWEEN 1 AND 80),
  question_kind text NOT NULL CHECK(char_length(question_kind) BETWEEN 1 AND 40),
  attempted_at timestamptz NOT NULL,
  UNIQUE(source_mode,source_attempt_id,question_id)
);
CREATE INDEX quiz_answer_facts_user_analysis ON public.quiz_answer_facts(user_id,attempted_at DESC);
CREATE INDEX quiz_answer_facts_dimensions ON public.quiz_answer_facts(user_id,topic,cefr_level,question_kind,is_correct);

CREATE TABLE public.quiz_mistake_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  question_source text NOT NULL CHECK(question_source IN ('journey','arena')),
  question_id uuid NOT NULL,
  question jsonb NOT NULL CHECK(jsonb_typeof(question)='object'),
  answer_key jsonb NOT NULL,
  explanation_vi text NOT NULL DEFAULT '',
  cefr_level text NOT NULL CHECK(cefr_level IN ('A1','A2','B1','B2','C1')),
  topic text NOT NULL CHECK(char_length(topic) BETWEEN 1 AND 80),
  question_kind text NOT NULL CHECK(char_length(question_kind) BETWEEN 1 AND 40),
  first_incorrect_at timestamptz NOT NULL,
  latest_incorrect_at timestamptz NOT NULL,
  latest_incorrect_answer jsonb NOT NULL,
  incorrect_attempts integer NOT NULL DEFAULT 1 CHECK(incorrect_attempts>0),
  successful_reviews integer NOT NULL DEFAULT 0 CHECK(successful_reviews>=0),
  incorrect_reviews integer NOT NULL DEFAULT 0 CHECK(incorrect_reviews>=0),
  review_stage integer NOT NULL DEFAULT 0 CHECK(review_stage BETWEEN 0 AND 5),
  mastery_status text NOT NULL DEFAULT 'needs_review' CHECK(mastery_status IN ('needs_review','learning','improving','mastered')),
  last_reviewed_at timestamptz,
  next_review_at timestamptz NOT NULL,
  algorithm_version integer NOT NULL DEFAULT 1 CHECK(algorithm_version=1),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id,question_source,question_id)
);
CREATE INDEX quiz_mistakes_due ON public.quiz_mistake_progress(user_id,next_review_at,id) WHERE mastery_status<>'mastered';
CREATE INDEX quiz_mistakes_filter ON public.quiz_mistake_progress(user_id,mastery_status,cefr_level,topic,question_kind);

CREATE TABLE public.quiz_review_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  request_id uuid NOT NULL,
  requested_count integer NOT NULL CHECK(requested_count BETWEEN 1 AND 50),
  status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','completed','abandoned')),
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  correct_count integer NOT NULL DEFAULT 0 CHECK(correct_count>=0),
  answered_count integer NOT NULL DEFAULT 0 CHECK(answered_count>=0),
  UNIQUE(user_id,request_id), UNIQUE(id,user_id)
);
CREATE UNIQUE INDEX quiz_review_one_active ON public.quiz_review_sessions(user_id) WHERE status='active';
CREATE INDEX quiz_review_history ON public.quiz_review_sessions(user_id,started_at DESC,id);

CREATE TABLE public.quiz_review_session_items (
  session_id uuid NOT NULL REFERENCES public.quiz_review_sessions(id) ON DELETE CASCADE,
  progress_id uuid NOT NULL REFERENCES public.quiz_mistake_progress(id) ON DELETE RESTRICT,
  position integer NOT NULL CHECK(position>0),
  PRIMARY KEY(session_id,position), UNIQUE(session_id,progress_id)
);

CREATE TABLE public.quiz_review_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  session_id uuid NOT NULL,
  progress_id uuid NOT NULL REFERENCES public.quiz_mistake_progress(id) ON DELETE RESTRICT,
  request_id uuid NOT NULL,
  given_answer jsonb NOT NULL,
  is_correct boolean NOT NULL,
  stage_before integer NOT NULL CHECK(stage_before BETWEEN 0 AND 5),
  stage_after integer NOT NULL CHECK(stage_after BETWEEN 0 AND 5),
  next_review_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(session_id,user_id) REFERENCES public.quiz_review_sessions(id,user_id) ON DELETE CASCADE,
  UNIQUE(user_id,request_id), UNIQUE(session_id,progress_id)
);
CREATE INDEX quiz_review_events_progress ON public.quiz_review_events(user_id,progress_id,created_at DESC);

DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['quiz_answer_facts','quiz_mistake_progress','quiz_review_sessions','quiz_review_session_items','quiz_review_events'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
 EXECUTE format('REVOKE ALL ON public.%I FROM anon,authenticated',t);
 EXECUTE format('GRANT ALL ON public.%I TO service_role',t);
END LOOP; END $$;
GRANT SELECT ON public.quiz_mistake_progress,public.quiz_review_sessions,public.quiz_review_events TO authenticated;
CREATE POLICY quiz_mistake_owner ON public.quiz_mistake_progress FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE POLICY quiz_review_session_owner ON public.quiz_review_sessions FOR SELECT TO authenticated USING(user_id=auth.uid());
CREATE POLICY quiz_review_event_owner ON public.quiz_review_events FOR SELECT TO authenticated USING(user_id=auth.uid());

CREATE FUNCTION public.englify_quiz_review_status(p_stage integer) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN p_stage>=5 THEN 'mastered' WHEN p_stage>=3 THEN 'improving' WHEN p_stage>=1 THEN 'learning' ELSE 'needs_review' END
$$;
CREATE FUNCTION public.englify_quiz_review_interval(p_stage integer) RETURNS interval LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE p_stage WHEN 1 THEN interval '1 day' WHEN 2 THEN interval '3 days' WHEN 3 THEN interval '7 days'
  WHEN 4 THEN interval '14 days' WHEN 5 THEN interval '30 days' ELSE interval '10 minutes' END
$$;
REVOKE ALL ON FUNCTION public.englify_quiz_review_status(integer),public.englify_quiz_review_interval(integer) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.englify_quiz_ingest_answer(
 p_user uuid,p_question_source text,p_question_id uuid,p_source_mode text,p_source_attempt_id uuid,p_given jsonb,p_correct boolean,
 p_question jsonb,p_answer jsonb,p_explanation text,p_cefr text,p_topic text,p_kind text,p_attempted_at timestamptz
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_user IS NULL OR p_question_id IS NULL OR p_source_attempt_id IS NULL OR p_given IS NULL OR p_correct IS NULL OR p_question IS NULL OR p_answer IS NULL THEN RETURN; END IF;
 INSERT INTO public.quiz_answer_facts(user_id,question_source,question_id,source_mode,source_attempt_id,given_answer,is_correct,cefr_level,topic,question_kind,attempted_at)
 VALUES(p_user,p_question_source,p_question_id,p_source_mode,p_source_attempt_id,p_given,p_correct,p_cefr,p_topic,p_kind,p_attempted_at)
 ON CONFLICT(source_mode,source_attempt_id,question_id) DO NOTHING;
 IF p_correct THEN RETURN; END IF;
 INSERT INTO public.quiz_mistake_progress(user_id,question_source,question_id,question,answer_key,explanation_vi,cefr_level,topic,question_kind,
   first_incorrect_at,latest_incorrect_at,latest_incorrect_answer,next_review_at)
 VALUES(p_user,p_question_source,p_question_id,p_question,p_answer,coalesce(p_explanation,''),p_cefr,p_topic,p_kind,p_attempted_at,p_attempted_at,p_given,p_attempted_at)
 ON CONFLICT(user_id,question_source,question_id) DO UPDATE SET
   question=excluded.question,answer_key=excluded.answer_key,explanation_vi=excluded.explanation_vi,cefr_level=excluded.cefr_level,
   topic=excluded.topic,question_kind=excluded.question_kind,latest_incorrect_at=greatest(public.quiz_mistake_progress.latest_incorrect_at,excluded.latest_incorrect_at),
   latest_incorrect_answer=CASE WHEN excluded.latest_incorrect_at>=public.quiz_mistake_progress.latest_incorrect_at THEN excluded.latest_incorrect_answer ELSE public.quiz_mistake_progress.latest_incorrect_answer END,
   incorrect_attempts=public.quiz_mistake_progress.incorrect_attempts+1,review_stage=0,mastery_status='needs_review',
   next_review_at=least(public.quiz_mistake_progress.next_review_at,excluded.next_review_at),updated_at=now();
END $$;
REVOKE ALL ON FUNCTION public.englify_quiz_ingest_answer(uuid,text,uuid,text,uuid,jsonb,boolean,jsonb,jsonb,text,text,text,text,timestamptz) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.englify_quiz_ingest_journey_trigger() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE a public.lesson_attempts%ROWTYPE; q record; question_doc jsonb; answer_doc jsonb; cefr text;
BEGIN
 SELECT * INTO a FROM public.lesson_attempts WHERE id=NEW.attempt_id;
 SELECT qq.*,k.answer AS answer_key,c.level INTO q FROM public.quiz_questions qq JOIN public.lessons l ON l.id=qq.lesson_id JOIN public.courses c ON c.id=l.course_id LEFT JOIN public.quiz_answer_keys k ON k.question_id=qq.id WHERE qq.id=NEW.question_id;
 IF q.kind='multiple_choice' THEN
  SELECT to_jsonb(id::text) INTO answer_doc FROM public.quiz_options WHERE question_id=q.id AND is_correct;
 ELSE answer_doc:=q.answer_key; END IF;
 cefr:=CASE WHEN q.level BETWEEN 1 AND 5 THEN (ARRAY['A1','A2','B1','B2','C1'])[q.level] ELSE 'A1' END;
 question_doc:=jsonb_build_object('id',q.id,'kind',CASE q.kind WHEN 'grammar' THEN 'grammar_correction' WHEN 'listening' THEN 'fill_blank' ELSE q.kind END,
  'topic','journey','cefr_level',cefr,'difficulty',1,'prompt',q.prompt,'passage',NULL,'options',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'text',answer_text) ORDER BY position) FROM public.quiz_options WHERE question_id=q.id),'[]'::jsonb),
  'left_items',coalesce(q.payload->'left_items','[]'::jsonb),'right_items',coalesce(q.payload->'right_items','[]'::jsonb));
 PERFORM public.englify_quiz_ingest_answer(a.user_id,'journey',q.id,'journey',a.id,NEW.answer,NEW.is_correct,question_doc,answer_doc,coalesce(q.explanation,''),cefr,'journey',question_doc->>'kind',a.created_at);
 RETURN NEW;
END $$;

CREATE FUNCTION public.englify_quiz_ingest_time_trigger() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE owner_id uuid; snap record; BEGIN SELECT user_id INTO owner_id FROM public.arena_time_attack_sessions WHERE id=NEW.session_id;
 SELECT * INTO snap FROM public.arena_session_questions WHERE session_id=NEW.session_id AND question_id=NEW.question_id;
 PERFORM public.englify_quiz_ingest_answer(owner_id,'arena',NEW.question_id,'time_attack',NEW.session_id,NEW.given_answer,NEW.correct,snap.question,snap.answer,snap.explanation_vi,snap.question->>'cefr_level',snap.question->>'topic',snap.question->>'kind',NEW.accepted_at); RETURN NEW; END $$;

CREATE FUNCTION public.englify_quiz_ingest_ranked_trigger() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE owner_id uuid; snap record; BEGIN SELECT user_id INTO owner_id FROM public.arena_ranked_matches WHERE id=NEW.match_id;
 SELECT * INTO snap FROM public.arena_session_questions WHERE session_id=NEW.match_id AND question_id=NEW.question_id;
 PERFORM public.englify_quiz_ingest_answer(owner_id,'arena',NEW.question_id,'ranked',NEW.match_id,NEW.given_answer,NEW.correct,snap.question,snap.answer,snap.explanation_vi,snap.question->>'cefr_level',snap.question->>'topic',snap.question->>'kind',NEW.accepted_at); RETURN NEW; END $$;

CREATE FUNCTION public.englify_quiz_ingest_practice_trigger() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item jsonb; q jsonb; BEGIN
 IF NEW.mode<>'practice' OR NEW.status<>'completed' OR NEW.result IS NULL OR (OLD.status='completed' AND OLD.result IS NOT DISTINCT FROM NEW.result) THEN RETURN NEW; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(NEW.result->'review') LOOP q:=item->'question';
  PERFORM public.englify_quiz_ingest_answer(NEW.user_id,'arena',(q->>'id')::uuid,'practice',NEW.id,item->'given_answer',(item->>'correct')::boolean,q,item->'correct_answer',item->>'explanation_vi',q->>'cefr_level',q->>'topic',q->>'kind',NEW.completed_at);
 END LOOP; RETURN NEW; END $$;
DO $$ BEGIN
 CREATE TRIGGER quiz_ingest_journey AFTER INSERT ON public.lesson_answer_attempts FOR EACH ROW EXECUTE FUNCTION public.englify_quiz_ingest_journey_trigger();
 CREATE TRIGGER quiz_ingest_time AFTER INSERT ON public.arena_time_attack_answers FOR EACH ROW EXECUTE FUNCTION public.englify_quiz_ingest_time_trigger();
 CREATE TRIGGER quiz_ingest_ranked AFTER INSERT ON public.arena_ranked_answers FOR EACH ROW EXECUTE FUNCTION public.englify_quiz_ingest_ranked_trigger();
 CREATE TRIGGER quiz_ingest_practice AFTER UPDATE OF status,result ON public.arena_sessions FOR EACH ROW EXECUTE FUNCTION public.englify_quiz_ingest_practice_trigger();
END $$;
REVOKE ALL ON FUNCTION public.englify_quiz_ingest_journey_trigger(),public.englify_quiz_ingest_time_trigger(),public.englify_quiz_ingest_ranked_trigger(),public.englify_quiz_ingest_practice_trigger() FROM PUBLIC,anon,authenticated;

-- Backfill from authoritative persisted attempts. Idempotent unique source identities prevent duplication.
INSERT INTO public.quiz_answer_facts(user_id,question_source,question_id,source_mode,source_attempt_id,given_answer,is_correct,cefr_level,topic,question_kind,attempted_at)
SELECT la.user_id,'journey',aa.question_id,'journey',la.id,aa.answer,aa.is_correct,
 CASE WHEN c.level BETWEEN 1 AND 5 THEN (ARRAY['A1','A2','B1','B2','C1'])[c.level] ELSE 'A1' END,'journey',
 CASE q.kind WHEN 'grammar' THEN 'grammar_correction' WHEN 'listening' THEN 'fill_blank' ELSE q.kind END,la.created_at
FROM public.lesson_answer_attempts aa JOIN public.lesson_attempts la ON la.id=aa.attempt_id JOIN public.quiz_questions q ON q.id=aa.question_id JOIN public.lessons l ON l.id=q.lesson_id JOIN public.courses c ON c.id=l.course_id
ON CONFLICT DO NOTHING;

DO $$ DECLARE f record; v_question jsonb; answer_doc jsonb; question_doc jsonb; BEGIN
 FOR f IN SELECT aa.*,la.user_id,la.created_at,q.kind,q.prompt,q.payload,q.explanation,q.lesson_id,c.level,k.answer AS answer_key
  FROM public.lesson_answer_attempts aa JOIN public.lesson_attempts la ON la.id=aa.attempt_id JOIN public.quiz_questions q ON q.id=aa.question_id
  JOIN public.lessons l ON l.id=q.lesson_id JOIN public.courses c ON c.id=l.course_id LEFT JOIN public.quiz_answer_keys k ON k.question_id=q.id WHERE NOT aa.is_correct ORDER BY la.created_at LOOP
  IF f.kind='multiple_choice' THEN SELECT to_jsonb(id::text) INTO answer_doc FROM public.quiz_options WHERE question_id=f.question_id AND is_correct; ELSE answer_doc:=f.answer_key; END IF;
  question_doc:=jsonb_build_object('id',f.question_id,'kind',CASE f.kind WHEN 'grammar' THEN 'grammar_correction' WHEN 'listening' THEN 'fill_blank' ELSE f.kind END,'topic','journey',
   'cefr_level',CASE WHEN f.level BETWEEN 1 AND 5 THEN (ARRAY['A1','A2','B1','B2','C1'])[f.level] ELSE 'A1' END,'difficulty',1,'prompt',f.prompt,'passage',NULL,
   'options',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'text',answer_text) ORDER BY position) FROM public.quiz_options WHERE question_id=f.question_id),'[]'::jsonb),
   'left_items',coalesce(f.payload->'left_items','[]'::jsonb),'right_items',coalesce(f.payload->'right_items','[]'::jsonb));
  PERFORM public.englify_quiz_ingest_answer(f.user_id,'journey',f.question_id,'journey',f.attempt_id,f.answer,false,question_doc,answer_doc,coalesce(f.explanation,''),question_doc->>'cefr_level','journey',question_doc->>'kind',f.created_at);
 END LOOP;
 FOR f IN SELECT s.user_id,s.id,s.completed_at,item FROM public.arena_sessions s CROSS JOIN LATERAL jsonb_array_elements(s.result->'review') item WHERE s.mode='practice' AND s.status='completed' ORDER BY s.completed_at LOOP v_question:=f.item->'question'; PERFORM public.englify_quiz_ingest_answer(f.user_id,'arena',(v_question->>'id')::uuid,'practice',f.id,f.item->'given_answer',(f.item->>'correct')::boolean,v_question,f.item->'correct_answer',f.item->>'explanation_vi',v_question->>'cefr_level',v_question->>'topic',v_question->>'kind',f.completed_at); END LOOP;
 FOR f IN SELECT a.*,s.user_id,q.question,q.answer,q.explanation_vi FROM public.arena_time_attack_answers a JOIN public.arena_time_attack_sessions s ON s.id=a.session_id JOIN public.arena_session_questions q ON q.session_id=a.session_id AND q.question_id=a.question_id ORDER BY a.accepted_at LOOP PERFORM public.englify_quiz_ingest_answer(f.user_id,'arena',f.question_id,'time_attack',f.session_id,f.given_answer,f.correct,f.question,f.answer,f.explanation_vi,f.question->>'cefr_level',f.question->>'topic',f.question->>'kind',f.accepted_at); END LOOP;
 FOR f IN SELECT a.*,s.user_id,q.question,q.answer,q.explanation_vi FROM public.arena_ranked_answers a JOIN public.arena_ranked_matches s ON s.id=a.match_id JOIN public.arena_session_questions q ON q.session_id=a.match_id AND q.question_id=a.question_id ORDER BY a.accepted_at LOOP PERFORM public.englify_quiz_ingest_answer(f.user_id,'arena',f.question_id,'ranked',f.match_id,f.given_answer,f.correct,f.question,f.answer,f.explanation_vi,f.question->>'cefr_level',f.question->>'topic',f.question->>'kind',f.accepted_at); END LOOP;
END $$;

CREATE FUNCTION public.englify_quiz_mistake_summary() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 RETURN jsonb_build_object('total',(SELECT count(*) FROM public.quiz_mistake_progress WHERE user_id=auth.uid()),
 'due',(SELECT count(*) FROM public.quiz_mistake_progress WHERE user_id=auth.uid() AND next_review_at<=clock_timestamp()),
 'needs_review',(SELECT count(*) FROM public.quiz_mistake_progress WHERE user_id=auth.uid() AND mastery_status='needs_review'),
 'learning',(SELECT count(*) FROM public.quiz_mistake_progress WHERE user_id=auth.uid() AND mastery_status='learning'),
 'improving',(SELECT count(*) FROM public.quiz_mistake_progress WHERE user_id=auth.uid() AND mastery_status='improving'),
 'mastered',(SELECT count(*) FROM public.quiz_mistake_progress WHERE user_id=auth.uid() AND mastery_status='mastered'),
 'reviewed',(SELECT count(*) FROM public.quiz_review_events WHERE user_id=auth.uid()));
END $$;

CREATE FUNCTION public.englify_quiz_mistakes(p_page integer DEFAULT 1,p_cefr text DEFAULT NULL,p_topic text DEFAULT NULL,p_kind text DEFAULT NULL,p_status text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE total_count integer; items jsonb; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 IF p_page NOT BETWEEN 1 AND 10000 OR (p_cefr IS NOT NULL AND p_cefr NOT IN ('A1','A2','B1','B2','C1')) OR (p_status IS NOT NULL AND p_status NOT IN ('needs_review','learning','improving','mastered')) THEN RAISE EXCEPTION 'Invalid mistake filter' USING ERRCODE='22023'; END IF;
 WITH filtered AS (SELECT * FROM public.quiz_mistake_progress WHERE user_id=auth.uid() AND (p_cefr IS NULL OR cefr_level=p_cefr) AND (p_topic IS NULL OR topic=p_topic) AND (p_kind IS NULL OR question_kind=p_kind) AND (p_status IS NULL OR mastery_status=p_status))
 SELECT count(*),coalesce((SELECT jsonb_agg(to_jsonb(x)-'answer_key' ORDER BY next_review_at,latest_incorrect_at DESC,id) FROM (SELECT * FROM filtered ORDER BY next_review_at,latest_incorrect_at DESC,id LIMIT 20 OFFSET(p_page-1)*20)x),'[]'::jsonb) INTO total_count,items FROM filtered;
 RETURN jsonb_build_object('page',p_page,'page_size',20,'total',total_count,'items',items); END $$;

CREATE FUNCTION public.englify_quiz_review_view(p_session uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.quiz_review_sessions%ROWTYPE; current_item jsonb; review jsonb; BEGIN SELECT * INTO s FROM public.quiz_review_sessions WHERE id=p_session AND user_id=auth.uid(); IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Review session not found'; END IF;
 IF s.status='active' THEN SELECT to_jsonb(p)-'answer_key'-'user_id' INTO current_item FROM public.quiz_review_session_items i JOIN public.quiz_mistake_progress p ON p.id=i.progress_id WHERE i.session_id=s.id AND i.position=s.answered_count+1; END IF;
 IF s.status='completed' THEN SELECT coalesce(jsonb_agg(jsonb_build_object('progress_id',p.id,'question',p.question,'given_answer',e.given_answer,'correct_answer',p.answer_key,'correct',e.is_correct,'explanation_vi',p.explanation_vi,'stage_after',e.stage_after,'next_review_at',e.next_review_at) ORDER BY i.position),'[]'::jsonb) INTO review FROM public.quiz_review_session_items i JOIN public.quiz_mistake_progress p ON p.id=i.progress_id JOIN public.quiz_review_events e ON e.session_id=i.session_id AND e.progress_id=i.progress_id WHERE i.session_id=s.id; END IF;
 RETURN to_jsonb(s)-'user_id'-'request_id'||jsonb_build_object('current_item',current_item,'review',review,'earned_xp',0); END $$;

CREATE FUNCTION public.englify_quiz_start_review(p_request_id uuid,p_count integer DEFAULT 5) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.quiz_review_sessions%ROWTYPE; row record; n integer:=0; target integer; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF; IF p_request_id IS NULL OR p_count NOT IN (0,5,10) THEN RAISE EXCEPTION 'Choose 5, 10 or all due questions' USING ERRCODE='22023'; END IF; PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text));
 SELECT * INTO s FROM public.quiz_review_sessions WHERE user_id=auth.uid() AND request_id=p_request_id; IF FOUND THEN RETURN public.englify_quiz_review_view(s.id); END IF;
 IF EXISTS(SELECT 1 FROM public.quiz_review_sessions WHERE user_id=auth.uid() AND status='active') THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Finish the active review first'; END IF;
 SELECT CASE WHEN p_count=0 THEN least(50,count(*)) ELSE least(p_count,count(*)) END INTO target FROM public.quiz_mistake_progress WHERE user_id=auth.uid() AND next_review_at<=clock_timestamp();
 IF target=0 THEN RAISE SQLSTATE 'PT422' USING MESSAGE='No questions are due'; END IF;
 INSERT INTO public.quiz_review_sessions(user_id,request_id,requested_count) VALUES(auth.uid(),p_request_id,target) RETURNING * INTO s;
 FOR row IN SELECT id FROM public.quiz_mistake_progress WHERE user_id=auth.uid() AND next_review_at<=clock_timestamp()
  ORDER BY next_review_at,incorrect_attempts+incorrect_reviews DESC,latest_incorrect_at DESC,id LIMIT target FOR UPDATE LOOP n:=n+1;INSERT INTO public.quiz_review_session_items VALUES(s.id,row.id,n);END LOOP;
 RETURN public.englify_quiz_review_view(s.id); END $$;

CREATE FUNCTION public.englify_quiz_review_session(p_session uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF; RETURN public.englify_quiz_review_view(p_session); END $$;

CREATE FUNCTION public.englify_quiz_submit_review(p_session uuid,p_progress uuid,p_request_id uuid,p_answer jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE s public.quiz_review_sessions%ROWTYPE; p public.quiz_mistake_progress%ROWTYPE; old public.quiz_review_events%ROWTYPE; pos integer; ok boolean; before_stage integer; after_stage integer; due timestamptz; now_at timestamptz:=clock_timestamp();
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF; IF p_request_id IS NULL OR p_answer IS NULL OR octet_length(p_answer::text)>10000 THEN RAISE EXCEPTION 'Invalid review answer' USING ERRCODE='22023'; END IF; PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text));
 SELECT * INTO old FROM public.quiz_review_events WHERE user_id=auth.uid() AND request_id=p_request_id; IF FOUND THEN IF old.session_id<>p_session OR old.progress_id<>p_progress OR old.given_answer<>p_answer THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Request ID belongs to another review'; END IF; RETURN public.englify_quiz_review_view(p_session); END IF;
 SELECT * INTO s FROM public.quiz_review_sessions WHERE id=p_session AND user_id=auth.uid() FOR UPDATE; IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Review session not found'; END IF; IF s.status<>'active' THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Review session has ended'; END IF;
 SELECT position INTO pos FROM public.quiz_review_session_items WHERE session_id=s.id AND progress_id=p_progress; IF pos IS NULL OR pos<>s.answered_count+1 THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Answer only the current review question'; END IF;
 SELECT * INTO p FROM public.quiz_mistake_progress WHERE id=p_progress AND user_id=auth.uid() FOR UPDATE; IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Review item not found'; END IF;
 ok:=CASE WHEN p.question_source='arena' THEN public.englify_arena_grade(p.question,p.answer_key,p_answer)
  WHEN p.question_kind IN ('fill_blank','grammar_correction') THEN jsonb_typeof(p_answer)='string' AND EXISTS(SELECT 1 FROM jsonb_array_elements_text(p.answer_key) k WHERE public.englify_normalize_answer(p_answer#>>'{}')=public.englify_normalize_answer(k))
  ELSE p_answer=p.answer_key END;
 before_stage:=p.review_stage;after_stage:=CASE WHEN ok THEN least(5,before_stage+1) ELSE 0 END;due:=now_at+public.englify_quiz_review_interval(after_stage);
 UPDATE public.quiz_mistake_progress SET review_stage=after_stage,mastery_status=public.englify_quiz_review_status(after_stage),successful_reviews=successful_reviews+CASE WHEN ok THEN 1 ELSE 0 END,incorrect_reviews=incorrect_reviews+CASE WHEN ok THEN 0 ELSE 1 END,last_reviewed_at=now_at,next_review_at=due,latest_incorrect_at=CASE WHEN ok THEN latest_incorrect_at ELSE now_at END,latest_incorrect_answer=CASE WHEN ok THEN latest_incorrect_answer ELSE p_answer END,updated_at=now_at WHERE id=p.id;
 INSERT INTO public.quiz_review_events(user_id,session_id,progress_id,request_id,given_answer,is_correct,stage_before,stage_after,next_review_at) VALUES(auth.uid(),s.id,p.id,p_request_id,p_answer,ok,before_stage,after_stage,due);
 UPDATE public.quiz_review_sessions SET answered_count=answered_count+1,correct_count=correct_count+CASE WHEN ok THEN 1 ELSE 0 END WHERE id=s.id RETURNING * INTO s;
 IF s.answered_count=s.requested_count THEN UPDATE public.quiz_review_sessions SET status='completed',completed_at=now_at WHERE id=s.id; END IF;
 RETURN public.englify_quiz_review_view(s.id); END $$;

CREATE FUNCTION public.englify_quiz_weakness_analytics() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 RETURN jsonb_build_object('minimum_sample',5,'topics',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY error_rate DESC,attempts DESC,topic) FROM (SELECT topic,count(*)::integer attempts,count(*) FILTER(WHERE NOT is_correct)::integer incorrect,round(count(*) FILTER(WHERE NOT is_correct)*100.0/count(*),1) error_rate,(count(*)>=5) reliable FROM public.quiz_answer_facts WHERE user_id=auth.uid() GROUP BY topic)x),'[]'::jsonb),
 'levels',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY cefr_level) FROM (SELECT cefr_level,count(*)::integer attempts,count(*) FILTER(WHERE NOT is_correct)::integer incorrect,round(count(*) FILTER(WHERE NOT is_correct)*100.0/count(*),1) error_rate,(count(*)>=5) reliable FROM public.quiz_answer_facts WHERE user_id=auth.uid() GROUP BY cefr_level)x),'[]'::jsonb),
 'kinds',coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY error_rate DESC,question_kind) FROM (SELECT question_kind,count(*)::integer attempts,count(*) FILTER(WHERE NOT is_correct)::integer incorrect,round(count(*) FILTER(WHERE NOT is_correct)*100.0/count(*),1) error_rate,(count(*)>=5) reliable FROM public.quiz_answer_facts WHERE user_id=auth.uid() GROUP BY question_kind)x),'[]'::jsonb)); END $$;

CREATE FUNCTION public.englify_quiz_recommendations() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE due_count integer; weak record; recommendations jsonb:='[]'::jsonb; BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 SELECT count(*) INTO due_count FROM public.quiz_mistake_progress WHERE user_id=auth.uid() AND next_review_at<=clock_timestamp();
 IF due_count>0 THEN recommendations:=recommendations||jsonb_build_array(jsonb_build_object('kind','due_review','title','Ôn lại lỗi hôm nay','reason','Bạn có '||due_count||' câu đến hạn theo lịch ôn UTC.','action','review','count',due_count)); END IF;
 FOR weak IN SELECT topic,cefr_level,count(*) attempts,count(*) FILTER(WHERE NOT is_correct) incorrect,round(count(*) FILTER(WHERE NOT is_correct)*100.0/count(*),1) rate FROM public.quiz_answer_facts WHERE user_id=auth.uid() GROUP BY topic,cefr_level HAVING count(*)>=5 AND count(*) FILTER(WHERE NOT is_correct)*100.0/count(*)>=40 ORDER BY rate DESC,attempts DESC LIMIT 3 LOOP
  recommendations:=recommendations||jsonb_build_array(jsonb_build_object('kind','weak_topic','title','Luyện thêm '||weak.topic,'reason','Tỷ lệ sai '||weak.rate||'% trên '||weak.attempts||' lượt thật ở mức '||weak.cefr_level||'.','action','practice','topic',weak.topic,'cefr_level',weak.cefr_level));
 END LOOP; RETURN recommendations; END $$;

REVOKE ALL ON FUNCTION public.englify_quiz_mistake_summary(),public.englify_quiz_mistakes(integer,text,text,text,text),public.englify_quiz_review_view(uuid),public.englify_quiz_start_review(uuid,integer),public.englify_quiz_review_session(uuid),public.englify_quiz_submit_review(uuid,uuid,uuid,jsonb),public.englify_quiz_weakness_analytics(),public.englify_quiz_recommendations() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_quiz_mistake_summary(),public.englify_quiz_mistakes(integer,text,text,text,text),public.englify_quiz_start_review(uuid,integer),public.englify_quiz_review_session(uuid),public.englify_quiz_submit_review(uuid,uuid,uuid,jsonb),public.englify_quiz_weakness_analytics(),public.englify_quiz_recommendations() TO authenticated;
