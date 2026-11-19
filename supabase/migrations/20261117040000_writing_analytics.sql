-- Writing V2.4: secure server-side analytics over authoritative Writing records.

CREATE FUNCTION public.englify_writing_word_count(p_body text)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path='' AS $$
  SELECT CASE WHEN btrim(coalesce(p_body,''))='' THEN 0
    ELSE cardinality(regexp_split_to_array(btrim(p_body),'\s+')) END
$$;
REVOKE ALL ON FUNCTION public.englify_writing_word_count(text) FROM PUBLIC,anon,authenticated;

ALTER TABLE public.writing_submissions
  ADD COLUMN word_count integer GENERATED ALWAYS AS (public.englify_writing_word_count(body)) STORED,
  ADD COLUMN cefr_level_snapshot text CHECK (cefr_level_snapshot IS NULL OR cefr_level_snapshot IN ('A1','A2','B1','B2','C1')),
  ADD COLUMN topic_id_snapshot uuid REFERENCES public.writing_topics(id) ON DELETE SET NULL,
  ADD COLUMN exercise_kind_snapshot text CHECK (exercise_kind_snapshot IS NULL OR exercise_kind_snapshot IN
    ('sentence','fill_blank','sentence_order','paragraph','email','opinion','essay')),
  ADD COLUMN timezone_name_snapshot text,
  ADD COLUMN analytics_metadata_source text NOT NULL DEFAULT 'captured'
    CHECK (analytics_metadata_source IN ('captured','backfilled','unavailable'));

UPDATE public.writing_submissions s SET
  cefr_level_snapshot=e.cefr_level,
  topic_id_snapshot=e.topic_id,
  exercise_kind_snapshot=e.kind,
  timezone_name_snapshot=coalesce(
    (SELECT p.writing_timezone FROM public.user_preferences p WHERE p.user_id=s.user_id),
    'Asia/Ho_Chi_Minh'
  ),
  analytics_metadata_source='backfilled'
FROM public.writing_exercises e
WHERE e.id=s.exercise_id;
UPDATE public.writing_submissions SET timezone_name_snapshot='Asia/Ho_Chi_Minh',analytics_metadata_source='unavailable'
WHERE timezone_name_snapshot IS NULL;

CREATE FUNCTION public.englify_capture_writing_analytics_metadata()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  IF NEW.exercise_id IS NOT NULL THEN
    SELECT cefr_level,topic_id,kind INTO NEW.cefr_level_snapshot,NEW.topic_id_snapshot,NEW.exercise_kind_snapshot
      FROM public.writing_exercises WHERE id=NEW.exercise_id;
  END IF;
  SELECT coalesce(writing_timezone,'Asia/Ho_Chi_Minh') INTO NEW.timezone_name_snapshot
    FROM public.user_preferences WHERE user_id=NEW.user_id;
  NEW.timezone_name_snapshot:=coalesce(NEW.timezone_name_snapshot,'Asia/Ho_Chi_Minh');
  NEW.analytics_metadata_source:=CASE WHEN NEW.cefr_level_snapshot IS NULL THEN 'unavailable' ELSE 'captured' END;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_capture_writing_analytics_metadata() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER capture_writing_analytics_metadata BEFORE INSERT ON public.writing_submissions
  FOR EACH ROW EXECUTE FUNCTION public.englify_capture_writing_analytics_metadata();

CREATE INDEX writing_submissions_user_analytics_date_idx
  ON public.writing_submissions(user_id,created_at DESC,id);
CREATE INDEX writing_submissions_user_cefr_topic_idx
  ON public.writing_submissions(user_id,cefr_level_snapshot,topic_id_snapshot,created_at DESC);
CREATE INDEX writing_ai_feedback_user_analytics_idx
  ON public.writing_ai_feedback(user_id,created_at DESC,submission_id);

CREATE FUNCTION public.englify_writing_submission_qualifies(p_rule text,p_min_words integer,p_word_count integer)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $$
  SELECT p_rule='matched' OR (p_rule='self_review' AND p_word_count>=coalesce(p_min_words,1))
$$;
REVOKE ALL ON FUNCTION public.englify_writing_submission_qualifies(text,integer,integer) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.englify_writing_progress_summary()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_timezone text; v_today date; v_streak jsonb; v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT coalesce(writing_timezone,'Asia/Ho_Chi_Minh') INTO v_timezone FROM public.user_preferences WHERE user_id=v_uid;
  v_timezone:=coalesce(v_timezone,'Asia/Ho_Chi_Minh');
  v_today:=public.englify_writing_local_date(v_timezone,transaction_timestamp());
  v_streak:=public.englify_writing_streak_summary(v_uid,v_today);
  WITH qualifying AS (
    SELECT s.* FROM public.writing_submissions s JOIN public.writing_feedback f ON f.submission_id=s.id
      LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
    WHERE s.user_id=v_uid AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count)
  ), latest_ai AS (
    SELECT DISTINCT ON (a.submission_id) a.submission_id,a.overall_score FROM public.writing_ai_feedback a
      JOIN qualifying q ON q.id=a.submission_id WHERE a.user_id=v_uid
      ORDER BY a.submission_id,a.created_at DESC,a.id DESC
  )
  SELECT jsonb_build_object(
    'total_exercises',count(DISTINCT q.exercise_id) FILTER(WHERE q.exercise_id IS NOT NULL),
    'total_submissions',count(q.id),'total_words',coalesce(sum(q.word_count),0),
    'practice_days',count(DISTINCT ((q.created_at AT TIME ZONE coalesce(q.timezone_name_snapshot,v_timezone))::date)),
    'current_streak',(v_streak->>'current_streak')::integer,'longest_streak',(v_streak->>'longest_streak')::integer,
    'total_challenge_days',(v_streak->>'total_completed_days')::integer,
    'average_ai_score',round(avg(ai.overall_score),1),'ai_score_samples',count(ai.submission_id),
    'ai_trend_reliable',count(ai.submission_id)>=3,
    'writing_cefr_level',(SELECT writing_cefr_level FROM public.user_preferences WHERE user_id=v_uid),
    'timezone',v_timezone,'local_date',v_today)
    INTO v_result FROM qualifying q LEFT JOIN latest_ai ai ON ai.submission_id=q.id;
  RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_progress_summary() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_progress_summary() TO authenticated;

CREATE FUNCTION public.englify_writing_activity_stats(p_range text DEFAULT '30d')
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_timezone text; v_today date; v_start date; v_items jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_range NOT IN ('7d','30d','90d','all') THEN RAISE EXCEPTION 'Invalid activity range' USING ERRCODE='22023'; END IF;
  SELECT coalesce(writing_timezone,'Asia/Ho_Chi_Minh') INTO v_timezone FROM public.user_preferences WHERE user_id=v_uid;
  v_timezone:=coalesce(v_timezone,'Asia/Ho_Chi_Minh');
  v_today:=public.englify_writing_local_date(v_timezone,transaction_timestamp());
  v_start:=CASE p_range WHEN '7d' THEN v_today-6 WHEN '30d' THEN v_today-29 WHEN '90d' THEN v_today-89 ELSE NULL END;
  WITH qualifying AS (
    SELECT s.*,(s.created_at AT TIME ZONE coalesce(s.timezone_name_snapshot,v_timezone))::date AS activity_date
    FROM public.writing_submissions s JOIN public.writing_feedback f ON f.submission_id=s.id
      LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
    WHERE s.user_id=v_uid AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count)
  ), writing_days AS (
    SELECT activity_date,count(*)::integer submissions,sum(word_count)::integer words
      FROM qualifying WHERE v_start IS NULL OR activity_date>=v_start GROUP BY activity_date
  ), challenge_days AS (
    SELECT challenge_date,count(*)::integer challenges FROM public.writing_daily_completions
      WHERE user_id=v_uid AND (v_start IS NULL OR challenge_date>=v_start) GROUP BY challenge_date
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('date',coalesce(w.activity_date,c.challenge_date),
    'submissions',coalesce(w.submissions,0),'words',coalesce(w.words,0),
    'daily_challenges',coalesce(c.challenges,0)) ORDER BY coalesce(w.activity_date,c.challenge_date)),'[]'::jsonb)
    INTO v_items FROM writing_days w FULL JOIN challenge_days c ON c.challenge_date=w.activity_date;
  RETURN jsonb_build_object('range',p_range,'start_date',v_start,'end_date',v_today,'items',v_items);
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_activity_stats(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_activity_stats(text) TO authenticated;

CREATE FUNCTION public.englify_writing_score_analytics(p_range text DEFAULT '90d',p_level text DEFAULT NULL,p_kind text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_timezone text; v_today date; v_start date; v_trends jsonb; v_groups jsonb; v_recent jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_range NOT IN ('7d','30d','90d','all')
    OR (p_level IS NOT NULL AND p_level NOT IN ('A1','A2','B1','B2','C1'))
    OR (p_kind IS NOT NULL AND p_kind NOT IN ('sentence','fill_blank','sentence_order','paragraph','email','opinion','essay')) THEN
    RAISE EXCEPTION 'Invalid score analytics filter' USING ERRCODE='22023'; END IF;
  SELECT coalesce(writing_timezone,'Asia/Ho_Chi_Minh') INTO v_timezone FROM public.user_preferences WHERE user_id=v_uid;
  v_timezone:=coalesce(v_timezone,'Asia/Ho_Chi_Minh'); v_today:=public.englify_writing_local_date(v_timezone,transaction_timestamp());
  v_start:=CASE p_range WHEN '7d' THEN v_today-6 WHEN '30d' THEN v_today-29 WHEN '90d' THEN v_today-89 ELSE NULL END;
  WITH latest AS (
    SELECT DISTINCT ON (a.submission_id) a.*,s.created_at AS submitted_at,s.exercise_id,s.cefr_level_snapshot,
      s.exercise_kind_snapshot,s.timezone_name_snapshot,e.title,t.title AS topic_title
    FROM public.writing_ai_feedback a JOIN public.writing_submissions s ON s.id=a.submission_id
      JOIN public.writing_feedback f ON f.submission_id=s.id LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
      LEFT JOIN public.writing_topics t ON t.id=s.topic_id_snapshot
    WHERE a.user_id=v_uid AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count)
      AND (p_level IS NULL OR s.cefr_level_snapshot=p_level) AND (p_kind IS NULL OR s.exercise_kind_snapshot=p_kind)
      AND (v_start IS NULL OR (s.created_at AT TIME ZONE coalesce(s.timezone_name_snapshot,v_timezone))::date>=v_start)
    ORDER BY a.submission_id,a.created_at DESC,a.id DESC
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('submission_id',submission_id,'date',
      (submitted_at AT TIME ZONE coalesce(timezone_name_snapshot,v_timezone))::date,'cefr_level',cefr_level_snapshot,
      'kind',exercise_kind_snapshot,'group',coalesce(cefr_level_snapshot,'NA')||':'||coalesce(exercise_kind_snapshot,'unknown'),
      'overall_score',overall_score,'grammar_score',grammar_score,'vocabulary_score',vocabulary_score,
      'coherence_score',coherence_score,'task_score',task_score) ORDER BY submitted_at),'[]'::jsonb)
    INTO v_trends FROM latest;
  WITH latest AS (
    SELECT DISTINCT ON (a.submission_id) a.*,s.cefr_level_snapshot,s.exercise_kind_snapshot,s.created_at,s.timezone_name_snapshot
    FROM public.writing_ai_feedback a JOIN public.writing_submissions s ON s.id=a.submission_id
      JOIN public.writing_feedback f ON f.submission_id=s.id
      LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
    WHERE a.user_id=v_uid AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count)
      AND (p_level IS NULL OR s.cefr_level_snapshot=p_level)
      AND (p_kind IS NULL OR s.exercise_kind_snapshot=p_kind)
      AND (v_start IS NULL OR (s.created_at AT TIME ZONE coalesce(s.timezone_name_snapshot,v_timezone))::date>=v_start)
    ORDER BY a.submission_id,a.created_at DESC,a.id DESC
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('cefr_level',cefr_level_snapshot,'kind',exercise_kind_snapshot,
    'sample_size',sample_size,'reliable_trend',sample_size>=3,'overall_score',overall_score,
    'grammar_score',grammar_score,'vocabulary_score',vocabulary_score,'coherence_score',coherence_score,
    'task_score',task_score) ORDER BY cefr_level_snapshot,exercise_kind_snapshot),'[]'::jsonb) INTO v_groups FROM (
      SELECT cefr_level_snapshot,exercise_kind_snapshot,count(*)::integer sample_size,round(avg(overall_score),1) overall_score,
        round(avg(grammar_score),1) grammar_score,round(avg(vocabulary_score),1) vocabulary_score,
        round(avg(coherence_score),1) coherence_score,round(avg(task_score),1) task_score
      FROM latest GROUP BY cefr_level_snapshot,exercise_kind_snapshot) grouped;
  WITH latest AS (
    SELECT DISTINCT ON (a.submission_id) a.*,s.created_at AS submitted_at,s.cefr_level_snapshot,s.exercise_kind_snapshot,
      coalesce(e.title,s.prompt) AS exercise_title
    FROM public.writing_ai_feedback a JOIN public.writing_submissions s ON s.id=a.submission_id
      LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
      JOIN public.writing_feedback f ON f.submission_id=s.id
    WHERE a.user_id=v_uid AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count)
      AND (p_level IS NULL OR s.cefr_level_snapshot=p_level)
      AND (p_kind IS NULL OR s.exercise_kind_snapshot=p_kind)
    ORDER BY a.submission_id,a.created_at DESC,a.id DESC
  ) SELECT coalesce(jsonb_agg(to_jsonb(recent) ORDER BY submitted_at DESC),'[]'::jsonb) INTO v_recent
    FROM (SELECT submission_id,exercise_title,cefr_level_snapshot AS cefr_level,exercise_kind_snapshot AS kind,
      submitted_at,overall_score FROM latest ORDER BY submitted_at DESC LIMIT 10) recent;
  RETURN jsonb_build_object('range',p_range,'scoring_basis','latest_ai_feedback_per_original_submission',
    'trends',v_trends,'groups',v_groups,'recent',v_recent);
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_score_analytics(text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_score_analytics(text,text,text) TO authenticated;

CREATE FUNCTION public.englify_writing_mistake_summary(p_range text DEFAULT '90d')
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_timezone text; v_today date; v_start date; v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_range NOT IN ('7d','30d','90d','all') THEN RAISE EXCEPTION 'Invalid mistake range' USING ERRCODE='22023'; END IF;
  SELECT coalesce(writing_timezone,'Asia/Ho_Chi_Minh') INTO v_timezone FROM public.user_preferences WHERE user_id=v_uid;
  v_timezone:=coalesce(v_timezone,'Asia/Ho_Chi_Minh'); v_today:=public.englify_writing_local_date(v_timezone,transaction_timestamp());
  v_start:=CASE p_range WHEN '7d' THEN v_today-6 WHEN '30d' THEN v_today-29 WHEN '90d' THEN v_today-89 ELSE NULL END;
  WITH latest AS (
    SELECT DISTINCT ON (a.submission_id) a.submission_id,a.errors,s.created_at,s.timezone_name_snapshot
    FROM public.writing_ai_feedback a JOIN public.writing_submissions s ON s.id=a.submission_id
      JOIN public.writing_feedback f ON f.submission_id=s.id
      LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
    WHERE a.user_id=v_uid AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count)
      AND (v_start IS NULL OR (s.created_at AT TIME ZONE coalesce(s.timezone_name_snapshot,v_timezone))::date>=v_start)
    ORDER BY a.submission_id,a.created_at DESC,a.id DESC
  ), issues AS (
    SELECT l.submission_id,error_item,
      CASE error_item->>'type' WHEN 'vocabulary' THEN 'vocabulary_word_choice' WHEN 'spelling' THEN 'spelling'
        WHEN 'sentence_structure' THEN 'sentence_structure' WHEN 'grammar' THEN 'other_grammar'
        ELSE 'other' END AS category
    FROM latest l CROSS JOIN LATERAL jsonb_array_elements(l.errors) error_item
  ), ranked AS (
    SELECT *,row_number() OVER(PARTITION BY category ORDER BY submission_id) AS example_rank FROM issues
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('category',category,'issue_count',issue_count,
    'examples',examples) ORDER BY issue_count DESC,category),'[]'::jsonb) INTO v_result FROM (
      SELECT category,count(*)::integer issue_count,coalesce(jsonb_agg(jsonb_build_object('submission_id',submission_id,
        'original',error_item->>'original','corrected',error_item->>'corrected',
        'explanation_vi',error_item->>'explanation_vi') ORDER BY submission_id) FILTER(WHERE example_rank<=3),'[]'::jsonb) examples
      FROM ranked GROUP BY category) grouped;
  RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_mistake_summary(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_mistake_summary(text) TO authenticated;

CREATE FUNCTION public.englify_writing_cefr_progress()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  WITH levels(level,position) AS (VALUES('A1',1),('A2',2),('B1',3),('B2',4),('C1',5)),
  qualifying AS (
    SELECT s.* FROM public.writing_submissions s JOIN public.writing_feedback f ON f.submission_id=s.id
      LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
    WHERE s.user_id=v_uid AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count)
  ), latest_ai AS (
    SELECT DISTINCT ON (a.submission_id) a.submission_id,a.overall_score,q.cefr_level_snapshot
    FROM public.writing_ai_feedback a JOIN qualifying q ON q.id=a.submission_id
    WHERE a.user_id=v_uid ORDER BY a.submission_id,a.created_at DESC,a.id DESC
  )
  SELECT jsonb_agg(jsonb_build_object('cefr_level',l.level,
    'available_exercises',(SELECT count(*) FROM public.writing_exercises e WHERE e.cefr_level=l.level AND e.is_published AND e.archived_at IS NULL),
    'distinct_exercises',(SELECT count(DISTINCT q.exercise_id) FROM qualifying q WHERE q.cefr_level_snapshot=l.level),
    'submissions',(SELECT count(*) FROM qualifying q WHERE q.cefr_level_snapshot=l.level),
    'average_ai_score',(SELECT round(avg(a.overall_score),1) FROM latest_ai a WHERE a.cefr_level_snapshot=l.level),
    'ai_score_samples',(SELECT count(*) FROM latest_ai a WHERE a.cefr_level_snapshot=l.level),
    'daily_challenges',(SELECT count(*) FROM public.writing_daily_completions c JOIN public.writing_daily_assignments d ON d.id=c.assignment_id
      WHERE c.user_id=v_uid AND d.assigned_cefr_level=l.level),
    'last_practiced_at',(SELECT max(q.created_at) FROM qualifying q WHERE q.cefr_level_snapshot=l.level)) ORDER BY l.position)
    INTO v_result FROM levels l;
  RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_cefr_progress() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_cefr_progress() TO authenticated;

CREATE FUNCTION public.englify_writing_topic_progress()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  WITH qualifying AS (
    SELECT s.* FROM public.writing_submissions s JOIN public.writing_feedback f ON f.submission_id=s.id
      LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
    WHERE s.user_id=v_uid AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count)
  ), latest_ai AS (
    SELECT DISTINCT ON (a.submission_id) a.submission_id,a.overall_score,q.topic_id_snapshot
    FROM public.writing_ai_feedback a JOIN qualifying q ON q.id=a.submission_id WHERE a.user_id=v_uid
    ORDER BY a.submission_id,a.created_at DESC,a.id DESC
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('topic_id',t.id,'slug',t.slug,'title',t.title,
    'available_exercises',(SELECT count(*) FROM public.writing_exercises e WHERE e.topic_id=t.id AND e.is_published AND e.archived_at IS NULL),
    'distinct_exercises',(SELECT count(DISTINCT q.exercise_id) FROM qualifying q WHERE q.topic_id_snapshot=t.id),
    'submissions',(SELECT count(*) FROM qualifying q WHERE q.topic_id_snapshot=t.id),
    'average_ai_score',(SELECT round(avg(a.overall_score),1) FROM latest_ai a WHERE a.topic_id_snapshot=t.id),
    'ai_score_samples',(SELECT count(*) FROM latest_ai a WHERE a.topic_id_snapshot=t.id),
    'last_practiced_at',(SELECT max(q.created_at) FROM qualifying q WHERE q.topic_id_snapshot=t.id))
    ORDER BY t.sort_order,t.title),'[]'::jsonb) INTO v_result
  FROM public.writing_topics t WHERE t.is_published AND t.archived_at IS NULL;
  RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_topic_progress() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_topic_progress() TO authenticated;

CREATE FUNCTION public.englify_writing_recommendations()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_level text; v_timezone text; v_recent integer; v_avg numeric; v_samples integer;
  v_top_issue text; v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT coalesce(writing_cefr_level,'A1'),coalesce(writing_timezone,'Asia/Ho_Chi_Minh') INTO v_level,v_timezone
    FROM public.user_preferences WHERE user_id=v_uid;
  v_level:=coalesce(v_level,'A1'); v_timezone:=coalesce(v_timezone,'Asia/Ho_Chi_Minh');
  SELECT count(*) INTO v_recent FROM public.writing_submissions s JOIN public.writing_feedback f ON f.submission_id=s.id
    LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id WHERE s.user_id=v_uid
      AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count)
      AND s.created_at>=transaction_timestamp()-interval '7 days';
  WITH latest AS (SELECT DISTINCT ON (a.submission_id) a.* FROM public.writing_ai_feedback a
    JOIN public.writing_submissions s ON s.id=a.submission_id JOIN public.writing_feedback f ON f.submission_id=s.id
    LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
    WHERE a.user_id=v_uid AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count)
    ORDER BY a.submission_id,a.created_at DESC,a.id DESC)
  SELECT round(avg(overall_score),1),count(*) INTO v_avg,v_samples FROM latest WHERE created_at>=transaction_timestamp()-interval '30 days';
  WITH latest AS (SELECT DISTINCT ON (a.submission_id) a.* FROM public.writing_ai_feedback a
    JOIN public.writing_submissions s ON s.id=a.submission_id JOIN public.writing_feedback f ON f.submission_id=s.id
    LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
    WHERE a.user_id=v_uid AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count)
    ORDER BY a.submission_id,a.created_at DESC,a.id DESC), issues AS (
      SELECT CASE error_item->>'type' WHEN 'vocabulary' THEN 'vocabulary_word_choice' WHEN 'spelling' THEN 'spelling'
        WHEN 'sentence_structure' THEN 'sentence_structure' WHEN 'grammar' THEN 'other_grammar' ELSE 'other' END category
      FROM latest l CROSS JOIN LATERAL jsonb_array_elements(l.errors) error_item)
    SELECT category INTO v_top_issue FROM issues GROUP BY category ORDER BY count(*) DESC,category LIMIT 1;
  WITH candidates AS (
    SELECT e.*,t.title topic_title,row_number() OVER(ORDER BY
      CASE WHEN v_samples>=3 AND v_avg>=85 THEN -e.difficulty ELSE e.difficulty END,
      md5(v_uid::text||':'||e.id::text)) position
    FROM public.writing_exercises e LEFT JOIN public.writing_topics t ON t.id=e.topic_id
    WHERE e.cefr_level=v_level AND e.is_published AND e.archived_at IS NULL
      AND (e.topic_id IS NULL OR (t.is_published AND t.archived_at IS NULL))
      AND NOT EXISTS(SELECT 1 FROM public.writing_submissions s JOIN public.writing_feedback f ON f.submission_id=s.id
        WHERE s.user_id=v_uid AND s.exercise_id=e.id
          AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count))
    LIMIT 3)
  SELECT coalesce(jsonb_agg(jsonb_build_object('rule',CASE WHEN position=1 AND v_recent=0 THEN 'low_frequency'
      WHEN position=1 AND v_top_issue IS NOT NULL THEN 'frequent_issue'
      WHEN v_samples>=3 AND v_avg>=85 THEN 'strong_recent_performance' ELSE 'uncompleted_exercise' END,
    'title',CASE WHEN position=1 AND v_recent=0 THEN 'Viết một bài ngắn hôm nay'
      WHEN position=1 AND v_top_issue IS NOT NULL THEN 'Luyện tập theo phản hồi gần đây'
      WHEN v_samples>=3 AND v_avg>=85 THEN 'Thử thách bản thân trong cùng cấp độ' ELSE 'Tiếp tục thư viện Writing' END,
    'explanation_vi',CASE WHEN position=1 AND v_recent=0 THEN 'Bạn chưa có hoạt động Writing hợp lệ trong 7 ngày gần đây.'
      WHEN position=1 AND v_top_issue IS NOT NULL THEN 'Phản hồi AI gần đây thường nhắc nhóm '||replace(v_top_issue,'_',' ')||'. Đây là gợi ý, không phải lỗi đã được giáo viên xác nhận.'
      WHEN v_samples>=3 AND v_avg>=85 THEN 'Ba hoặc nhiều bài gần đây có điểm AI trung bình cao; hãy thử bài khó hơn trong cùng cấp độ.'
      ELSE 'Bài này chưa có lần hoàn thành hợp lệ và phù hợp cấp độ Writing đã chọn.' END,
    'exercise',jsonb_build_object('id',id,'title',title,'cefr_level',cefr_level,'kind',kind,
      'topic_id',topic_id,'topic_title',topic_title,'difficulty',difficulty)) ORDER BY position),'[]'::jsonb)
    INTO v_result FROM candidates;
  RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_recommendations() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_recommendations() TO authenticated;

CREATE FUNCTION public.englify_writing_analytics_history(p_range text DEFAULT 'all',p_level text DEFAULT NULL,
  p_topic_id uuid DEFAULT NULL,p_kind text DEFAULT NULL,p_ai_status text DEFAULT 'all',p_page integer DEFAULT 1,p_page_size integer DEFAULT 10)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_timezone text; v_today date; v_start date; v_total integer; v_items jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_range NOT IN ('7d','30d','90d','all') OR p_page<1 OR p_page_size NOT BETWEEN 1 AND 30
    OR p_ai_status NOT IN ('all','scored','unscored')
    OR (p_level IS NOT NULL AND p_level NOT IN ('A1','A2','B1','B2','C1'))
    OR (p_kind IS NOT NULL AND p_kind NOT IN ('sentence','fill_blank','sentence_order','paragraph','email','opinion','essay')) THEN
    RAISE EXCEPTION 'Invalid Writing history filter' USING ERRCODE='22023'; END IF;
  SELECT coalesce(writing_timezone,'Asia/Ho_Chi_Minh') INTO v_timezone FROM public.user_preferences WHERE user_id=v_uid;
  v_timezone:=coalesce(v_timezone,'Asia/Ho_Chi_Minh'); v_today:=public.englify_writing_local_date(v_timezone,transaction_timestamp());
  v_start:=CASE p_range WHEN '7d' THEN v_today-6 WHEN '30d' THEN v_today-29 WHEN '90d' THEN v_today-89 ELSE NULL END;
  WITH rows AS (
    SELECT s.*,coalesce(e.title,s.prompt) exercise_title,t.title topic_title,f.rule_result,
      latest.overall_score,(SELECT count(*) FROM public.writing_revisions r WHERE r.submission_id=s.id) revision_count,
      EXISTS(SELECT 1 FROM public.writing_daily_completions c WHERE c.submission_id=s.id) is_daily,
      public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count) qualifies
    FROM public.writing_submissions s LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
      LEFT JOIN public.writing_topics t ON t.id=s.topic_id_snapshot LEFT JOIN public.writing_feedback f ON f.submission_id=s.id
      LEFT JOIN LATERAL (SELECT a.overall_score FROM public.writing_ai_feedback a WHERE a.submission_id=s.id
        ORDER BY a.created_at DESC,a.id DESC LIMIT 1) latest ON true
    WHERE s.user_id=v_uid AND (v_start IS NULL OR (s.created_at AT TIME ZONE coalesce(s.timezone_name_snapshot,v_timezone))::date>=v_start)
      AND (p_level IS NULL OR s.cefr_level_snapshot=p_level) AND (p_topic_id IS NULL OR s.topic_id_snapshot=p_topic_id)
      AND (p_kind IS NULL OR s.exercise_kind_snapshot=p_kind)
      AND (p_ai_status='all' OR (p_ai_status='scored' AND latest.overall_score IS NOT NULL)
        OR (p_ai_status='unscored' AND latest.overall_score IS NULL))
  ) SELECT count(*) INTO v_total FROM rows;
  WITH rows AS (
    SELECT s.id,s.exercise_id,coalesce(e.title,s.prompt) exercise_title,s.created_at,s.cefr_level_snapshot cefr_level,
      s.topic_id_snapshot topic_id,t.title topic_title,s.exercise_kind_snapshot kind,s.word_count,s.analytics_metadata_source,
      f.rule_result,latest.overall_score,(SELECT count(*) FROM public.writing_revisions r WHERE r.submission_id=s.id) revision_count,
      EXISTS(SELECT 1 FROM public.writing_daily_completions c WHERE c.submission_id=s.id) is_daily,
      public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count) qualifies
    FROM public.writing_submissions s LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
      LEFT JOIN public.writing_topics t ON t.id=s.topic_id_snapshot LEFT JOIN public.writing_feedback f ON f.submission_id=s.id
      LEFT JOIN LATERAL (SELECT a.overall_score FROM public.writing_ai_feedback a WHERE a.submission_id=s.id
        ORDER BY a.created_at DESC,a.id DESC LIMIT 1) latest ON true
    WHERE s.user_id=v_uid AND (v_start IS NULL OR (s.created_at AT TIME ZONE coalesce(s.timezone_name_snapshot,v_timezone))::date>=v_start)
      AND (p_level IS NULL OR s.cefr_level_snapshot=p_level) AND (p_topic_id IS NULL OR s.topic_id_snapshot=p_topic_id)
      AND (p_kind IS NULL OR s.exercise_kind_snapshot=p_kind)
      AND (p_ai_status='all' OR (p_ai_status='scored' AND latest.overall_score IS NOT NULL)
        OR (p_ai_status='unscored' AND latest.overall_score IS NULL))
    ORDER BY s.created_at DESC,s.id DESC OFFSET (p_page-1)*p_page_size LIMIT p_page_size)
  SELECT coalesce(jsonb_agg(to_jsonb(rows) ORDER BY created_at DESC,id DESC),'[]'::jsonb) INTO v_items FROM rows;
  RETURN jsonb_build_object('items',v_items,'total',v_total,'page',p_page,'page_size',p_page_size);
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_analytics_history(text,text,uuid,text,text,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_analytics_history(text,text,uuid,text,text,integer,integer) TO authenticated;

CREATE FUNCTION public.englify_writing_analytics_detail(p_submission_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT jsonb_build_object('id',s.id,'exercise_id',s.exercise_id,'exercise_title',coalesce(e.title,s.prompt),
    'prompt',s.prompt,'body',s.body,'created_at',s.created_at,'word_count',s.word_count,
    'cefr_level',s.cefr_level_snapshot,'topic_id',s.topic_id_snapshot,'topic_title',t.title,
    'kind',s.exercise_kind_snapshot,'metadata_source',s.analytics_metadata_source,
    'rule_feedback',CASE WHEN f.id IS NULL THEN NULL ELSE jsonb_build_object('rule_result',f.rule_result,
      'suggestions',f.suggestions,'grammar_status',f.grammar_status,'grammar_matches',f.grammar_matches) END,
    'is_daily',EXISTS(SELECT 1 FROM public.writing_daily_completions c WHERE c.submission_id=s.id))
    INTO v_result FROM public.writing_submissions s LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id
      LEFT JOIN public.writing_topics t ON t.id=s.topic_id_snapshot LEFT JOIN public.writing_feedback f ON f.submission_id=s.id
    WHERE s.id=p_submission_id AND s.user_id=v_uid;
  IF v_result IS NULL THEN RAISE EXCEPTION 'Writing submission not found' USING ERRCODE='P0002'; END IF;
  RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_analytics_detail(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_analytics_detail(uuid) TO authenticated;

CREATE FUNCTION public.englify_writing_report(p_period text DEFAULT 'weekly')
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_timezone text; v_today date; v_start date; v_activity jsonb; v_ai jsonb; v_issue jsonb;
  v_challenges integer; v_xp integer; v_streak jsonb; v_recommendations jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  IF p_period NOT IN ('weekly','monthly') THEN RAISE EXCEPTION 'Invalid Writing report period' USING ERRCODE='22023'; END IF;
  SELECT coalesce(writing_timezone,'Asia/Ho_Chi_Minh') INTO v_timezone FROM public.user_preferences WHERE user_id=v_uid;
  v_timezone:=coalesce(v_timezone,'Asia/Ho_Chi_Minh'); v_today:=public.englify_writing_local_date(v_timezone,transaction_timestamp());
  v_start:=v_today-CASE WHEN p_period='weekly' THEN 6 ELSE 29 END;
  WITH qualifying AS (
    SELECT s.*,(s.created_at AT TIME ZONE coalesce(s.timezone_name_snapshot,v_timezone))::date activity_date
    FROM public.writing_submissions s JOIN public.writing_feedback f ON f.submission_id=s.id
      LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id WHERE s.user_id=v_uid
      AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count))
  SELECT jsonb_build_object('practice_days',count(DISTINCT activity_date),'completed_exercises',count(DISTINCT exercise_id),
    'submissions',count(*),'total_words',coalesce(sum(word_count),0)) INTO v_activity
    FROM qualifying WHERE activity_date>=v_start;
  WITH latest AS (SELECT DISTINCT ON (a.submission_id) a.* FROM public.writing_ai_feedback a
    JOIN public.writing_submissions s ON s.id=a.submission_id JOIN public.writing_feedback f ON f.submission_id=s.id
    LEFT JOIN public.writing_exercises e ON e.id=s.exercise_id WHERE a.user_id=v_uid
      AND public.englify_writing_submission_qualifies(f.rule_result,e.min_words,s.word_count)
      AND (s.created_at AT TIME ZONE coalesce(s.timezone_name_snapshot,v_timezone))::date>=v_start
    ORDER BY a.submission_id,a.created_at DESC,a.id DESC)
  SELECT jsonb_build_object('sample_size',count(*),'average_score',round(avg(overall_score),1),
    'grammar_score',round(avg(grammar_score),1),'vocabulary_score',round(avg(vocabulary_score),1),
    'coherence_score',round(avg(coherence_score),1),'task_score',round(avg(task_score),1),
    'reliable_trend',count(*)>=3) INTO v_ai FROM latest;
  SELECT coalesce((public.englify_writing_mistake_summary(CASE WHEN p_period='weekly' THEN '7d' ELSE '30d' END)->0),'null'::jsonb) INTO v_issue;
  SELECT count(*),coalesce(sum(awarded_xp),0) INTO v_challenges,v_xp FROM public.writing_daily_completions
    WHERE user_id=v_uid AND challenge_date>=v_start;
  v_streak:=public.englify_writing_streak_summary(v_uid,v_today);
  v_recommendations:=public.englify_writing_recommendations();
  RETURN jsonb_build_object('period',p_period,'start_date',v_start,'end_date',v_today,'activity',v_activity,
    'ai_feedback',v_ai,'common_issue',v_issue,'daily_challenges',jsonb_build_object('completed',v_challenges,
      'xp_earned',v_xp,'current_streak',(v_streak->>'current_streak')::integer),
    'recommendations',coalesce(v_recommendations,'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.englify_writing_report(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_writing_report(text) TO authenticated;

