-- Gamification reads and reward claims use server-owned totals and per-user transactions.
CREATE FUNCTION public.englify_gamification_overview()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid(); v_total int; v_level int; v_step int; v_spent int;
  v_day date := (transaction_timestamp() AT TIME ZONE 'UTC')::date;
  v_quests jsonb; v_badges jsonb; v_rewards jsonb; v_stats jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  SELECT level_xp_step INTO v_step FROM public.gamification_config WHERE id=1;
  IF v_step IS NULL THEN RAISE EXCEPTION 'Gamification rules unavailable' USING ERRCODE='P0001'; END IF;
  SELECT total_xp, level INTO v_total, v_level FROM public.user_levels WHERE user_id=v_uid;
  IF NOT FOUND THEN
    SELECT greatest(0,coalesce(sum(amount),0)) INTO v_total FROM public.xp_events WHERE user_id=v_uid;
    v_level := v_total / v_step + 1;
  END IF;
  SELECT coalesce(sum(xp_cost),0) INTO v_spent FROM public.reward_claims WHERE user_id=v_uid;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',q.id,'title',q.title,'description',q.description,
    'period',q.period,'progress',least(q.progress,q.target_lessons),'target',q.target_lessons,
    'reward_xp',q.reward_xp,'completed',q.claimed) ORDER BY q.period,q.id),'[]'::jsonb)
  INTO v_quests FROM (
    SELECT q.*, (SELECT count(*) FROM public.learning_progress p WHERE p.user_id=v_uid
      AND p.completed_at >= (CASE WHEN q.period='daily' THEN v_day ELSE v_day-(extract(isodow from v_day)::int-1) END)::timestamp AT TIME ZONE 'UTC'
      AND p.completed_at < ((CASE WHEN q.period='daily' THEN v_day+1 ELSE v_day-(extract(isodow from v_day)::int-1)+7 END)::timestamp AT TIME ZONE 'UTC')) AS progress,
      EXISTS (SELECT 1 FROM public.quest_claims qc WHERE qc.user_id=v_uid AND qc.quest_id=q.id
        AND qc.period_start=CASE WHEN q.period='daily' THEN v_day ELSE v_day-(extract(isodow from v_day)::int-1) END) AS claimed
    FROM public.quests q WHERE q.is_active
  ) q;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',b.id,'title',b.title,'description',b.description,
    'unlocked',b.awarded_at IS NOT NULL,'unlocked_at',b.awarded_at) ORDER BY b.target,b.title),'[]'::jsonb)
  INTO v_badges FROM (
    SELECT b.id,b.title,b.description,br.target,ub.awarded_at FROM public.badges b
    JOIN public.badge_rules br ON br.badge_id=b.id
    LEFT JOIN public.user_badges ub ON ub.badge_id=b.id AND ub.user_id=v_uid
    WHERE b.is_published AND b.archived_at IS NULL
  ) b;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',r.id,'title',r.title,'description',r.description,
    'xp_cost',r.xp_cost,'required_level',r.required_level,'claimed',r.claim_id IS NOT NULL,
    'eligible',r.claim_id IS NULL AND v_level>=r.required_level AND greatest(0,v_total-v_spent)>=r.xp_cost)
    ORDER BY r.xp_cost,r.title),'[]'::jsonb)
  INTO v_rewards FROM (
    SELECT r.id,r.title,r.description,r.xp_cost,r.required_level,rc.id AS claim_id
    FROM public.reward_items r LEFT JOIN public.reward_claims rc ON rc.reward_id=r.id AND rc.user_id=v_uid
    WHERE r.is_active
  ) r;
  v_stats := jsonb_build_object(
    'completed_lessons',(SELECT count(*) FROM public.learning_progress WHERE user_id=v_uid AND status IN ('completed','mastered')),
    'mastered_lessons',(SELECT count(*) FROM public.learning_progress WHERE user_id=v_uid AND status='mastered'),
    'quiz_attempts',(SELECT count(*) FROM public.lesson_attempts WHERE user_id=v_uid),
    'correct_answers',(SELECT coalesce(sum(correct_count),0) FROM public.lesson_attempts WHERE user_id=v_uid));
  RETURN jsonb_build_object('total_xp',v_total,'level',v_level,'xp_into_level',v_total%v_step,
    'xp_for_next_level',v_step,'available_xp',greatest(0,v_total-v_spent),
    'quests',v_quests,'badges',v_badges,'rewards',v_rewards,'statistics',v_stats);
END $$;
REVOKE ALL ON FUNCTION public.englify_gamification_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_gamification_overview() TO authenticated;

CREATE FUNCTION public.englify_claim_reward(p_reward_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_uid uuid := auth.uid(); v_reward record; v_claim record;
  v_total int; v_level int; v_step int; v_spent int;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(v_uid::text));
  SELECT id,title,xp_cost,required_level INTO v_reward FROM public.reward_items WHERE id=p_reward_id AND is_active;
  IF NOT FOUND THEN RAISE EXCEPTION 'Reward unavailable' USING ERRCODE='P0002'; END IF;
  SELECT level_xp_step INTO v_step FROM public.gamification_config WHERE id=1;
  SELECT total_xp,level INTO v_total,v_level FROM public.user_levels WHERE user_id=v_uid;
  IF NOT FOUND THEN
    SELECT greatest(0,coalesce(sum(amount),0)) INTO v_total FROM public.xp_events WHERE user_id=v_uid;
    v_level := v_total/v_step+1;
  END IF;
  SELECT coalesce(sum(xp_cost),0) INTO v_spent FROM public.reward_claims WHERE user_id=v_uid;
  SELECT id,claimed_at INTO v_claim FROM public.reward_claims WHERE user_id=v_uid AND reward_id=p_reward_id;
  IF FOUND THEN RETURN jsonb_build_object('claim_id',v_claim.id,'reward_id',p_reward_id,
    'claimed_at',v_claim.claimed_at,'newly_claimed',false,'available_xp',greatest(0,v_total-v_spent)); END IF;
  IF v_level<v_reward.required_level THEN RAISE EXCEPTION 'Required level not reached' USING ERRCODE='P0001'; END IF;
  IF v_total-v_spent<v_reward.xp_cost THEN RAISE EXCEPTION 'Insufficient available XP' USING ERRCODE='P0001'; END IF;
  INSERT INTO public.reward_claims(user_id,reward_id,xp_cost) VALUES(v_uid,p_reward_id,v_reward.xp_cost)
    RETURNING id,claimed_at INTO v_claim;
  INSERT INTO public.reward_notifications(user_id,kind,source_id,title,message)
    VALUES(v_uid,'reward',v_claim.id,v_reward.title,'Reward claimed!')
    ON CONFLICT (user_id,kind,source_id) DO NOTHING;
  RETURN jsonb_build_object('claim_id',v_claim.id,'reward_id',p_reward_id,'claimed_at',v_claim.claimed_at,
    'newly_claimed',true,'available_xp',v_total-v_spent-v_reward.xp_cost);
END $$;
REVOKE ALL ON FUNCTION public.englify_claim_reward(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_claim_reward(uuid) TO authenticated;

CREATE FUNCTION public.englify_mark_reward_read(p_notification_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_uid uuid := auth.uid(); v_count int;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
  UPDATE public.reward_notifications SET read_at=coalesce(read_at,now())
    WHERE id=p_notification_id AND user_id=v_uid;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('read',v_count=1);
END $$;
REVOKE ALL ON FUNCTION public.englify_mark_reward_read(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.englify_mark_reward_read(uuid) TO authenticated;