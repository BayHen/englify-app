-- DEV topics only. No synthetic Tatoeba references or AI-generated lessons.
INSERT INTO public.real_english_topics (id,slug,title,description,search_keyword,difficulty,is_active) VALUES
  ('00000000-0000-4000-8000-000000000301','daily-conversation','Daily conversation','Natural everyday exchanges','hello','A1',true),
  ('00000000-0000-4000-8000-000000000302','shopping','Shopping','Requests and replies while shopping','buy','A2',true),
  ('00000000-0000-4000-8000-000000000303','workplace','Workplace','Polite workplace communication','work','B1',true),
  ('00000000-0000-4000-8000-000000000304','travel','Travel','Travel situations and directions','train','A2',true),
  ('00000000-0000-4000-8000-000000000305','friends','Friends','Casual conversations with friends','friend','B1',true)
ON CONFLICT (slug) DO NOTHING;
