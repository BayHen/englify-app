-- V2.4 hardening after local integration: duplicate-safe ingestion and actionable recommendations.
CREATE OR REPLACE FUNCTION public.englify_quiz_ingest_answer(
 p_user uuid,p_question_source text,p_question_id uuid,p_source_mode text,p_source_attempt_id uuid,p_given jsonb,p_correct boolean,
 p_question jsonb,p_answer jsonb,p_explanation text,p_cefr text,p_topic text,p_kind text,p_attempted_at timestamptz
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE inserted_count integer;
BEGIN
 IF p_user IS NULL OR p_question_id IS NULL OR p_source_attempt_id IS NULL OR p_given IS NULL OR p_correct IS NULL OR p_question IS NULL OR p_answer IS NULL THEN RETURN; END IF;
 INSERT INTO public.quiz_answer_facts(user_id,question_source,question_id,source_mode,source_attempt_id,given_answer,is_correct,cefr_level,topic,question_kind,attempted_at)
 VALUES(p_user,p_question_source,p_question_id,p_source_mode,p_source_attempt_id,p_given,p_correct,p_cefr,p_topic,p_kind,p_attempted_at)
 ON CONFLICT(source_mode,source_attempt_id,question_id) DO NOTHING;
 GET DIAGNOSTICS inserted_count=ROW_COUNT;
 IF inserted_count=0 OR p_correct THEN RETURN; END IF;
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

CREATE OR REPLACE FUNCTION public.englify_quiz_recommendations() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE due_count integer; weak record; recommendations jsonb:='[]'::jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 SELECT count(*) INTO due_count FROM public.quiz_mistake_progress WHERE user_id=auth.uid() AND next_review_at<=clock_timestamp();
 IF due_count>0 THEN recommendations:=recommendations||jsonb_build_array(jsonb_build_object('kind','due_review','title','Ôn lại lỗi hôm nay','reason','Bạn có '||due_count||' câu đến hạn theo lịch ôn UTC.','action','review','count',due_count)); END IF;
 FOR weak IN
  SELECT f.topic,f.cefr_level,count(*) attempts,count(*) FILTER(WHERE NOT f.is_correct) incorrect,
   round(count(*) FILTER(WHERE NOT f.is_correct)*100.0/count(*),1) rate
  FROM public.quiz_answer_facts f
  WHERE f.user_id=auth.uid() AND EXISTS(SELECT 1 FROM public.arena_questions q WHERE q.is_published AND q.topic=f.topic AND q.cefr_level=f.cefr_level)
  GROUP BY f.topic,f.cefr_level
  HAVING count(*)>=5 AND count(*) FILTER(WHERE NOT f.is_correct)*100.0/count(*)>=40
  ORDER BY rate DESC,attempts DESC LIMIT 3
 LOOP
  recommendations:=recommendations||jsonb_build_array(jsonb_build_object('kind','weak_topic','title','Luyện thêm '||weak.topic,'reason','Tỷ lệ sai '||weak.rate||'% trên '||weak.attempts||' lượt thật ở mức '||weak.cefr_level||'.','action','practice','topic',weak.topic,'cefr_level',weak.cefr_level));
 END LOOP;
 RETURN recommendations;
END $$;
REVOKE ALL ON FUNCTION public.englify_quiz_recommendations() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_quiz_recommendations() TO authenticated;
