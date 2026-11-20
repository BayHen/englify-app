BEGIN;
INSERT INTO auth.users(id) VALUES('b8111111-1111-4111-8111-111111111111'),('b8222222-2222-4222-8222-222222222222'); INSERT INTO public.admin_members(user_id) VALUES('b8111111-1111-4111-8111-111111111111');
INSERT INTO public.courses(id,slug,title,level,cefr_level) VALUES('b8100000-0000-4000-8000-000000000001','v26-complete','V2.6 Complete',26,'A1');
SELECT set_config('request.jwt.claim.sub','b8111111-1111-4111-8111-111111111111',true); SET LOCAL ROLE authenticated;
DO $$ DECLARE c jsonb;u jsonb;b jsonb;summary jsonb; BEGIN
 c:=public.englify_admin_save_journey_node('chapter',NULL,jsonb_build_object('course_id','b8100000-0000-4000-8000-000000000001','slug','chapter','title','Chapter','position',1));
 u:=public.englify_admin_save_journey_node('unit',NULL,jsonb_build_object('course_id','b8100000-0000-4000-8000-000000000001','chapter_id',c->>'id','slug','unit','title','Unit','position',1));
 IF c->>'lifecycle_status'<>'draft' OR u->>'lifecycle_status'<>'draft' THEN RAISE EXCEPTION 'Nodes must remain drafts'; END IF;
 PERFORM public.englify_admin_reorder_journey('chapter','b8100000-0000-4000-8000-000000000001',ARRAY[(c->>'id')::uuid]);
 b:=public.englify_admin_stage_journey_import(gen_random_uuid(),'journey.csv','csv',jsonb_build_array(jsonb_build_object('entity','chapter','external_id','import-ch','course_id','b8100000-0000-4000-8000-000000000001','slug','imported','title','Imported','position',2)));
 summary:=public.englify_admin_commit_journey_import((b->>'batch_id')::uuid,gen_random_uuid()); IF (summary->>'imported')::int<>1 OR NOT EXISTS(SELECT 1 FROM public.journey_chapters WHERE external_id='import-ch' AND lifecycle_status='draft' AND NOT is_published) THEN RAISE EXCEPTION 'Safe import failed'; END IF;
 IF (public.englify_admin_journey_analytics() ? 'lesson_completions') IS NOT TRUE THEN RAISE EXCEPTION 'Analytics contract missing'; END IF;
END $$;
RESET ROLE; SELECT set_config('request.jwt.claim.sub','b8222222-2222-4222-8222-222222222222',true); SET LOCAL ROLE authenticated;
DO $$ BEGIN PERFORM public.englify_admin_journey_analytics(); RAISE EXCEPTION 'Learner accessed analytics'; EXCEPTION WHEN insufficient_privilege THEN NULL; END $$;
ROLLBACK;
