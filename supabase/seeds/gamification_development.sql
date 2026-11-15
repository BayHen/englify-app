-- Local development only; mirrors original Alembic revision 07 defaults.
INSERT INTO public.gamification_config(id,level_xp_step,lesson_multiplier_percent)
VALUES (1,100,100) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.quests(id,code,title,description,period,target_lessons,reward_xp)
VALUES
 ('aaaaaaaa-0000-4000-8000-000000000001','daily-lesson','One step today','Complete one new lesson today.','daily',1,5),
 ('aaaaaaaa-0000-4000-8000-000000000002','weekly-three-lessons','Keep learning','Complete three new lessons this week.','weekly',3,15)
ON CONFLICT (id) DO NOTHING;
UPDATE public.badges SET is_published=true
WHERE id='66666666-6666-4666-8666-666666666601';
INSERT INTO public.badges(id,code,title,description,is_published) VALUES
 ('66666666-6666-4666-8666-666666666602','four-lessons','Pathfinder','Complete four lessons.',true),
 ('66666666-6666-4666-8666-666666666603','hundred-xp','Rising star','Earn 100 XP.',true)
ON CONFLICT (id) DO UPDATE SET is_published=true;
INSERT INTO public.badge_rules(badge_id,metric,target)
VALUES ('66666666-6666-4666-8666-666666666601','completed_lessons',1),
 ('66666666-6666-4666-8666-666666666602','completed_lessons',4),
 ('66666666-6666-4666-8666-666666666603','total_xp',100)
ON CONFLICT (badge_id) DO NOTHING;
