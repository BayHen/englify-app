-- Count lessons that still qualify for editorial review. A later archive or
-- rejection must not make the daily five-lesson target appear complete.
CREATE OR REPLACE FUNCTION public.englify_refresh_real_english_batch(p_date date) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_target integer;
BEGIN
  SELECT daily_generation_target INTO v_target FROM public.real_english_generation_settings WHERE id=true;
  INSERT INTO public.real_english_generation_batches(generation_date,target_count)
  VALUES (p_date,coalesce(v_target,5)) ON CONFLICT (generation_date) DO NOTHING;
  UPDATE public.real_english_generation_batches b SET
    target_count=coalesce(v_target,5),
    success_count=(SELECT count(*)::integer FROM public.real_english_lessons l
      WHERE (l.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date
        AND l.generation_source='hybrid_ai' AND l.status IN ('pending_review','approved','published')),
    failure_count=(SELECT count(*)::integer FROM public.real_english_generation_jobs j
      WHERE (j.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date AND j.status IN ('failed','quota_blocked')),
    pending_count=(SELECT count(*)::integer FROM public.real_english_generation_jobs j
      WHERE (j.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date AND j.status IN ('queued','running')),
    latest_error=(SELECT j.error_message FROM public.real_english_generation_jobs j
      WHERE (j.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date
        AND j.error_message IS NOT NULL ORDER BY j.created_at DESC LIMIT 1),
    completed_at=CASE WHEN (SELECT count(*) FROM public.real_english_lessons l
      WHERE (l.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date=p_date
        AND l.generation_source='hybrid_ai' AND l.status IN ('pending_review','approved','published')) >= coalesce(v_target,5)
      THEN coalesce(b.completed_at,now()) ELSE NULL END,
    updated_at=now()
  WHERE b.generation_date=p_date;
END $$;

CREATE FUNCTION public.englify_real_english_batch_lesson_trigger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF NEW.generation_source='hybrid_ai' THEN
    PERFORM public.englify_refresh_real_english_batch((NEW.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date);
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_real_english_batch_lesson_trigger() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER real_english_batch_lesson AFTER INSERT OR UPDATE OF status
  ON public.real_english_lessons FOR EACH ROW
  EXECUTE FUNCTION public.englify_real_english_batch_lesson_trigger();

-- Claims are serialized by englify_claim_real_english_job's settings row lock.
-- Reserve only the remaining successful slots, including work already running.
CREATE FUNCTION public.englify_real_english_batch_target_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_target integer; v_reserved integer; v_date date; v_new_claim boolean;
BEGIN
  IF TG_OP='INSERT' THEN v_new_claim:=NEW.status='running';
  ELSE v_new_claim:=NEW.status='running' AND OLD.status IS DISTINCT FROM NEW.status; END IF;
  IF v_new_claim THEN
    v_date:=(NEW.created_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
    SELECT daily_generation_target INTO v_target FROM public.real_english_generation_settings WHERE id=true;
    SELECT success_count+pending_count INTO v_reserved FROM public.real_english_generation_batches
      WHERE generation_date=v_date;
    IF coalesce(v_reserved,0)>=coalesce(v_target,5) THEN
      RAISE EXCEPTION 'Daily valid lesson target already reserved' USING ERRCODE='P0001';
    END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_real_english_batch_target_guard() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER real_english_batch_target BEFORE INSERT OR UPDATE OF status
  ON public.real_english_generation_jobs FOR EACH ROW
  EXECUTE FUNCTION public.englify_real_english_batch_target_guard();

SELECT public.englify_refresh_real_english_batch((now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date);
