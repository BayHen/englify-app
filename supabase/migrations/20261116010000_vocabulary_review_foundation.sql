-- Server-authoritative, idempotent saved-vocabulary scheduling.
ALTER TABLE public.saved_vocabulary
  ADD COLUMN last_reviewed_at timestamptz,
  ADD COLUMN review_count integer NOT NULL DEFAULT 0,
  ADD COLUMN lapse_count integer NOT NULL DEFAULT 0,
  ADD COLUMN stability numeric(8,3) NOT NULL DEFAULT 0,
  ADD COLUMN difficulty numeric(5,3) NOT NULL DEFAULT 5,
  ADD COLUMN algorithm_version integer NOT NULL DEFAULT 1;
ALTER TABLE public.saved_vocabulary
  ADD CONSTRAINT saved_vocabulary_review_count_check CHECK (review_count>=0 AND lapse_count>=0),
  ADD CONSTRAINT saved_vocabulary_memory_check CHECK (stability>=0 AND difficulty BETWEEN 1 AND 10),
  ADD CONSTRAINT saved_vocabulary_algorithm_check CHECK (algorithm_version>0);
UPDATE public.saved_vocabulary SET next_review_at=coalesce(next_review_at,created_at);
ALTER TABLE public.saved_vocabulary ALTER COLUMN next_review_at SET DEFAULT now();

-- Learners may save a word or edit their note, but cannot manufacture due
-- dates, counts or memory state. Scheduling changes go through the RPC below.
REVOKE INSERT,UPDATE ON public.saved_vocabulary FROM authenticated;
GRANT INSERT(user_id,entry_id,note) ON public.saved_vocabulary TO authenticated;
GRANT UPDATE(note) ON public.saved_vocabulary TO authenticated;

ALTER TABLE public.review_history
  ADD COLUMN request_id uuid,
  ADD COLUMN next_review_at timestamptz,
  ADD COLUMN interval_days numeric(8,3),
  ADD COLUMN state_after jsonb NOT NULL DEFAULT '{}'::jsonb;
CREATE UNIQUE INDEX review_history_request_idx ON public.review_history(user_id,request_id) WHERE request_id IS NOT NULL;
CREATE INDEX saved_vocabulary_due_v2_idx ON public.saved_vocabulary(user_id,next_review_at,id) INCLUDE (entry_id,review_count,stability,difficulty);

CREATE OR REPLACE FUNCTION public.englify_due_vocabulary(p_limit integer DEFAULT 20) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path='' STABLE AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',s.id,'entry_id',s.entry_id,'term',d.term,'translation',d.translation,
    'definition',d.definition,'ipa',d.ipa,'part_of_speech',d.part_of_speech,'example',d.example,'example_vi',NULL,
    'next_review_at',s.next_review_at,'review_count',s.review_count,'stability',s.stability,'difficulty',s.difficulty)
    ORDER BY s.next_review_at,s.id),'[]'::jsonb)
  FROM (SELECT * FROM public.saved_vocabulary WHERE user_id=auth.uid() AND coalesce(next_review_at,created_at)<=now()
    ORDER BY next_review_at,id LIMIT least(100,greatest(1,coalesce(p_limit,20)))) s
  JOIN public.dictionary_entries d ON d.id=s.entry_id AND d.is_published AND d.archived_at IS NULL
$$;
REVOKE ALL ON FUNCTION public.englify_due_vocabulary(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_due_vocabulary(integer) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.englify_review_vocabulary(p_saved_vocabulary_id uuid,p_rating integer,p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_uid uuid:=auth.uid(); v_saved public.saved_vocabulary%ROWTYPE; v_existing jsonb; v_days numeric(8,3); v_next timestamptz;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
  IF p_rating NOT BETWEEN 1 AND 4 OR p_request_id IS NULL THEN RAISE EXCEPTION 'Invalid review' USING ERRCODE='22023'; END IF;
  SELECT state_after INTO v_existing FROM public.review_history WHERE user_id=v_uid AND request_id=p_request_id;
  IF FOUND THEN RETURN v_existing; END IF;
  SELECT * INTO v_saved FROM public.saved_vocabulary WHERE id=p_saved_vocabulary_id AND user_id=v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Saved vocabulary not found' USING ERRCODE='P0002'; END IF;
  v_days := CASE p_rating WHEN 1 THEN 0.007 WHEN 2 THEN greatest(1,v_saved.stability*1.2)
    WHEN 3 THEN CASE WHEN v_saved.review_count=0 THEN 1 ELSE greatest(2,v_saved.stability*(2.5-v_saved.difficulty/10)) END
    ELSE CASE WHEN v_saved.review_count=0 THEN 4 ELSE greatest(4,v_saved.stability*(3.2-v_saved.difficulty/12)) END END;
  v_next := now() + make_interval(secs => round(v_days*86400)::integer);
  UPDATE public.saved_vocabulary SET last_reviewed_at=now(),next_review_at=v_next,review_count=review_count+1,
    lapse_count=lapse_count+CASE WHEN p_rating=1 THEN 1 ELSE 0 END,
    stability=CASE WHEN p_rating=1 THEN 0.5 ELSE v_days END,
    difficulty=least(10,greatest(1,difficulty+CASE p_rating WHEN 1 THEN 0.8 WHEN 2 THEN 0.3 WHEN 3 THEN -0.1 ELSE -0.4 END)),
    algorithm_version=1 WHERE id=v_saved.id RETURNING * INTO v_saved;
  v_existing := jsonb_build_object('saved_vocabulary_id',v_saved.id,'rating',p_rating,'next_review_at',v_saved.next_review_at,
    'review_count',v_saved.review_count,'lapse_count',v_saved.lapse_count,'stability',v_saved.stability,'difficulty',v_saved.difficulty,'algorithm_version',1);
  INSERT INTO public.review_history(user_id,saved_vocabulary_id,rating,request_id,next_review_at,interval_days,state_after)
    VALUES(v_uid,v_saved.id,p_rating,p_request_id,v_next,v_days,v_existing);
  RETURN v_existing;
END $$;
REVOKE ALL ON FUNCTION public.englify_review_vocabulary(uuid,integer,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_review_vocabulary(uuid,integer,uuid) TO authenticated,service_role;
NOTIFY pgrst, 'reload schema';
