BEGIN;
INSERT INTO auth.users(id) VALUES('b9111111-1111-4111-8111-111111111111'); INSERT INTO public.admin_members(user_id) VALUES('b9111111-1111-4111-8111-111111111111');
INSERT INTO public.courses(id,slug,title,level,cefr_level) VALUES('b9100000-0000-4000-8000-000000000001','v27-audit','V2.7 Audit',27,'A1');
SELECT set_config('request.jwt.claim.sub','b9111111-1111-4111-8111-111111111111',true); SET LOCAL ROLE authenticated;
DO $$ DECLARE staged jsonb; committed jsonb; lesson uuid; BEGIN
 staged:=public.englify_admin_stage_journey_import(gen_random_uuid(),'v27.csv','csv',jsonb_build_array(
  jsonb_build_object('entity','chapter','external_id','v27-ch','course_id','b9100000-0000-4000-8000-000000000001','slug','chapter','title','Chapter','position',1),
  jsonb_build_object('entity','unit','external_id','v27-unit','parent_external_id','v27-ch','course_id','b9100000-0000-4000-8000-000000000001','slug','unit','title','Unit','position',1),
  jsonb_build_object('entity','lesson','external_id','v27-lesson','parent_external_id','v27-unit','course_id','b9100000-0000-4000-8000-000000000001','slug','lesson','title','Lesson','objective','Learn','position',1),
  jsonb_build_object('entity','block','external_id','v27-block','parent_external_id','v27-lesson','position',1,'block_type','introduction','content',jsonb_build_object('text_en','Hello','text_vi','Xin chào'))));
 IF (staged->>'valid_count')::int<>4 THEN RAISE EXCEPTION 'Expected four valid rows: %',staged; END IF;
 committed:=public.englify_admin_commit_journey_import((staged->>'batch_id')::uuid,gen_random_uuid()); IF (committed->>'imported')::int<>4 THEN RAISE EXCEPTION 'Block import was silently skipped: %',committed; END IF;
 SELECT id INTO lesson FROM public.lessons WHERE external_id='v27-lesson'; IF NOT EXISTS(SELECT 1 FROM public.journey_lesson_blocks WHERE lesson_id=lesson AND block_type='introduction') THEN RAISE EXCEPTION 'Imported lesson block missing'; END IF;
END $$;
ROLLBACK;
