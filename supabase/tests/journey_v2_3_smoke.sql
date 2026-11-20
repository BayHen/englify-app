BEGIN;
INSERT INTO auth.users(id) VALUES ('b4111111-1111-4111-8111-111111111111'),('b4222222-2222-4222-8222-222222222222');
INSERT INTO public.courses(id,slug,title,level,cefr_level,is_published) VALUES('b4100000-0000-4000-8000-000000000001','journey-v23','Journey V2.3',23,'A1',true);
INSERT INTO public.learning_units(id,course_id,slug,title,position,is_published) VALUES('b4100000-0000-4000-8000-000000000002','b4100000-0000-4000-8000-000000000001','unit','Unit',1,true);
INSERT INTO public.lessons(id,course_id,unit_id,slug,title,objective,position,is_published) VALUES('b4100000-0000-4000-8000-000000000003','b4100000-0000-4000-8000-000000000001','b4100000-0000-4000-8000-000000000002','lesson','Interactive lesson','Learn safely',1,true);
INSERT INTO public.lesson_items(id,lesson_id,position,kind,body,is_published) VALUES('b4100000-0000-4000-8000-000000000004','b4100000-0000-4000-8000-000000000003',1,'reading','{"text":"Hello","text_vi":"Xin chào"}',true);
-- The migration compatibility backfill ran before this fixture, so add a published revision explicitly.
INSERT INTO public.journey_lesson_revisions(id,lesson_id,version,status,source,content_hash,published_at) VALUES('b4100000-0000-4000-8000-000000000005','b4100000-0000-4000-8000-000000000003',1,'published','curated','test-v1',now());
INSERT INTO public.journey_lesson_blocks(id,revision_id,lesson_id,position,block_type,content) VALUES('b4100000-0000-4000-8000-000000000006','b4100000-0000-4000-8000-000000000005','b4100000-0000-4000-8000-000000000003',1,'introduction','{"text_en":"Hello","text_vi":"Xin chào"}');
SELECT set_config('request.jwt.claim.sub','b4111111-1111-4111-8111-111111111111',true); SET LOCAL ROLE authenticated;
DO $$ DECLARE detail jsonb; BEGIN
 detail:=public.englify_lesson_detail('b4100000-0000-4000-8000-000000000003');
 IF jsonb_array_length(detail->'blocks')<>1 OR detail->'blocks'->0->>'text_vi' IS NOT NULL THEN RAISE EXCEPTION 'Structured block contract invalid'; END IF;
 PERFORM public.englify_save_lesson_resume('b4100000-0000-4000-8000-000000000003','b4100000-0000-4000-8000-000000000005','b4100000-0000-4000-8000-000000000006','{}');
 PERFORM public.englify_save_lesson_note('b4100000-0000-4000-8000-000000000003','b4100000-0000-4000-8000-000000000006','My private note');
 PERFORM public.englify_toggle_lesson_bookmark('b4100000-0000-4000-8000-000000000003',NULL);
 IF EXISTS(SELECT 1 FROM public.xp_events WHERE user_id=auth.uid()) THEN RAISE EXCEPTION 'Resume/note/bookmark awarded XP'; END IF;
END $$;
RESET ROLE; SELECT set_config('request.jwt.claim.sub','b4222222-2222-4222-8222-222222222222',true); SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.journey_lesson_resume) OR EXISTS(SELECT 1 FROM public.journey_lesson_notes) OR EXISTS(SELECT 1 FROM public.journey_lesson_bookmarks) THEN RAISE EXCEPTION 'Private lesson state leaked across users'; END IF;
END $$;
ROLLBACK;
