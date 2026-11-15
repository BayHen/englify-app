-- Opt-in production configuration. Run only after confirming Gemini Free tier limits,
-- Edge AI_DAILY_MAX_REQUESTS >= 10, AI_DAILY_MAX_OUTPUT_TOKENS >= 12000,
-- the editorial migration, and licensed source availability.
BEGIN;
INSERT INTO public.real_english_topics (slug,title,description,search_keyword,difficulty,is_active) VALUES
  ('daily-conversation','Daily conversation','Natural everyday exchanges','hello','A1',true),
  ('shopping','Shopping','Requests and replies while shopping','buy','A2',true),
  ('workplace','Workplace','Polite workplace communication','work','B1',true),
  ('travel','Travel','Travel situations and directions','train','A2',true),
  ('friends','Friends','Casual conversations with friends','friend','B1',true)
ON CONFLICT (slug) DO NOTHING;
UPDATE public.real_english_generation_settings SET
  daily_generation_target=5,
  maximum_daily_requests=10,
  enabled_topics=ARRAY['coffee-conversation','daily-conversation','shopping','workplace','travel','friends'],
  enabled_difficulty_levels=ARRAY['A1','A2','B1'],
  updated_at=now()
WHERE id=true;
SELECT public.englify_refresh_real_english_batch((now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date);
COMMIT;
