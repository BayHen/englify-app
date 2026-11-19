-- Fix the published-column projection used by explainable weak-topic recommendations.
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
