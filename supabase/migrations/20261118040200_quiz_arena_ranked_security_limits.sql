-- Bounded ranked session creation and review-only heuristics. No signal auto-bans.
CREATE FUNCTION public.englify_ranked_start_rate_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF (SELECT count(*) FROM public.arena_ranked_matches WHERE user_id=NEW.user_id AND started_at>clock_timestamp()-interval '1 hour')>=20 THEN
   RAISE SQLSTATE 'PGRST' USING MESSAGE='{"code":"ranked_rate_limited","message":"Too many ranked matches. Try again later.","status":429}';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_ranked_start_rate_guard() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER arena_ranked_start_rate_guard BEFORE INSERT ON public.arena_ranked_matches
FOR EACH ROW EXECUTE FUNCTION public.englify_ranked_start_rate_guard();

CREATE FUNCTION public.englify_ranked_security_monitor() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF OLD.status='active' AND NEW.status='abandoned' AND
   (SELECT count(*) FROM public.arena_ranked_matches WHERE user_id=NEW.user_id AND status='abandoned' AND started_at>clock_timestamp()-interval '24 hours')>=3
 THEN
   INSERT INTO public.arena_ranked_security_events(match_id,user_id,signal,severity,details)
   VALUES(NEW.id,NEW.user_id,'excessive_abandonment',2,jsonb_build_object('window_hours',24,'threshold',3)) ON CONFLICT DO NOTHING;
   UPDATE public.arena_ranked_matches SET suspicious=true WHERE id=NEW.id;
 END IF;
 IF NEW.rating_change IS NOT NULL AND
   (SELECT count(*) FROM (SELECT rating_change FROM public.arena_rating_events WHERE user_id=NEW.user_id ORDER BY created_at DESC LIMIT 5)x WHERE rating_change>=25)>=5
 THEN
   INSERT INTO public.arena_ranked_security_events(match_id,user_id,signal,severity,details)
   VALUES(NEW.id,NEW.user_id,'rating_progression',2,jsonb_build_object('consecutive_large_gains',5)) ON CONFLICT DO NOTHING;
   UPDATE public.arena_ranked_matches SET suspicious=true WHERE id=NEW.id;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.englify_ranked_security_monitor() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER arena_ranked_security_monitor AFTER UPDATE OF status,rating_change ON public.arena_ranked_matches
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.rating_change IS DISTINCT FROM NEW.rating_change)
EXECUTE FUNCTION public.englify_ranked_security_monitor();
