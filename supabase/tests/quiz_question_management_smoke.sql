BEGIN;
INSERT INTO auth.users(id) VALUES('a2588888-8888-4888-8888-888888888888'),('a2599999-9999-4999-8999-999999999999');
INSERT INTO public.admin_members(user_id) VALUES('a2588888-8888-4888-8888-888888888888');
SELECT set_config('request.jwt.claim.sub','a2588888-8888-4888-8888-888888888888',true);
DO $$ DECLARE q jsonb;id uuid;before_xp integer;before_rating integer;batch jsonb;row_id uuid;v_session uuid:=gen_random_uuid();revision uuid;BEGIN
 before_xp:=(SELECT count(*) FROM public.xp_events);before_rating:=(SELECT count(*) FROM public.arena_rating_events);
 BEGIN PERFORM public.englify_admin_save_arena_question(gen_random_uuid(),NULL,'{"cefr_level":"A1","topic":"grammar","kind":"multiple_choice","difficulty":1,"prompt":"Broken","options":[],"left_items":[],"right_items":[],"answer":"x","explanation_vi":"Giải thích"}', 'invalid');RAISE EXCEPTION 'Invalid question accepted';EXCEPTION WHEN SQLSTATE '22023' THEN NULL;END;
 q:=public.englify_admin_save_arena_question(gen_random_uuid(),NULL,'{"external_id":"smoke-v25","cefr_level":"A1","topic":"grammar","kind":"multiple_choice","difficulty":1,"prompt":"Choose the correct smoke answer.","passage":null,"options":[{"id":"a","text":"Correct"},{"id":"b","text":"Wrong"}],"left_items":[],"right_items":[],"answer":"a","explanation_vi":"Đáp án A đúng.","origin":"editorial"}','Initial draft');id:=(q->>'id')::uuid;
 IF q->>'status'<>'draft' OR (q->>'current_version')::integer<>1 THEN RAISE EXCEPTION 'Draft creation failed: %',q;END IF;
 q:=public.englify_admin_transition_arena_question(id,'in_review','ready');q:=public.englify_admin_transition_arena_question(id,'published','approved');
 IF q->>'status'<>'published' OR NOT (q->>'is_published')::boolean THEN RAISE EXCEPTION 'Publish lifecycle failed';END IF;
 INSERT INTO public.arena_sessions(id,user_id,request_id,cefr_level,question_count,status)VALUES(v_session,'a2599999-9999-4999-8999-999999999999',gen_random_uuid(),'A1',5,'completed');
 INSERT INTO public.arena_session_questions(session_id,question_id,position,question,answer,explanation_vi)VALUES(v_session,id,1,jsonb_build_object('id',id,'prompt','Choose the correct smoke answer.','kind','multiple_choice','topic','grammar','cefr_level','A1','difficulty',1,'passage',NULL,'options','[{"id":"a","text":"Correct"},{"id":"b","text":"Wrong"}]'::jsonb,'left_items','[]'::jsonb,'right_items','[]'::jsonb),'"a"','Đáp án A đúng.') RETURNING revision_id INTO revision;
 q:=public.englify_admin_save_arena_question(gen_random_uuid(),id,'{"external_id":"smoke-v25","cefr_level":"A1","topic":"grammar","kind":"multiple_choice","difficulty":1,"prompt":"Choose the edited smoke answer.","passage":null,"options":[{"id":"a","text":"Correct"},{"id":"b","text":"Wrong"}],"left_items":[],"right_items":[],"answer":"b","explanation_vi":"Bản sửa cần review.","origin":"editorial"}','Edit published');
 IF q->>'status'<>'draft' OR (q->>'current_version')::integer<>2 OR (SELECT question->>'prompt' FROM public.arena_session_questions WHERE session_id=v_session)<>'Choose the correct smoke answer.' THEN RAISE EXCEPTION 'Versioning changed active/history snapshot';END IF;
 batch:=public.englify_admin_stage_arena_import(gen_random_uuid(),'smoke.csv','csv',jsonb_build_array('{"external_id":"smoke-import","cefr_level":"A1","topic":"grammar","kind":"fill_blank","difficulty":1,"prompt":"Imported UTF-8 café question","passage":null,"options":[],"left_items":[],"right_items":[],"answer":["café"],"explanation_vi":"Giải thích tiếng Việt","origin":"import"}'::jsonb,'{"external_id":"duplicate","cefr_level":"A1","topic":"grammar","kind":"multiple_choice","difficulty":1,"prompt":"Choose the edited smoke answer.","passage":null,"options":[{"id":"a","text":"A"},{"id":"b","text":"B"}],"left_items":[],"right_items":[],"answer":"a","explanation_vi":"Bị trùng","origin":"import"}'::jsonb));
 IF (batch->>'row_count')::integer<>2 OR (batch->>'duplicate_count')::integer<>1 THEN RAISE EXCEPTION 'Import validation/duplicate detection failed: %',batch;END IF;
 SELECT (value->>'id')::uuid INTO row_id FROM jsonb_array_elements(batch->'rows') WHERE value->>'duplicate_question_id' IS NULL;
 PERFORM public.englify_admin_commit_arena_import((batch->>'batch_id')::uuid,ARRAY[row_id],gen_random_uuid());IF NOT EXISTS(SELECT 1 FROM public.arena_questions WHERE external_id='smoke-import' AND status='draft') THEN RAISE EXCEPTION 'Import did not create draft';END IF;
 IF (SELECT count(*) FROM public.xp_events)<>before_xp OR (SELECT count(*) FROM public.arena_rating_events)<>before_rating THEN RAISE EXCEPTION 'Content management changed XP/rating';END IF;
END $$;
CREATE TEMP TABLE question_management_fixture AS SELECT s.id session_id,q.question_id FROM public.arena_sessions s JOIN public.arena_session_questions q ON q.session_id=s.id WHERE s.user_id='a2599999-9999-4999-8999-999999999999' LIMIT 1;
GRANT SELECT ON question_management_fixture TO authenticated;

SELECT set_config('request.jwt.claim.sub','a2599999-9999-4999-8999-999999999999',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE report jsonb;BEGIN
 BEGIN PERFORM public.englify_admin_question_list();RAISE EXCEPTION 'Learner accessed admin question list';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 IF EXISTS(SELECT 1 FROM public.arena_questions WHERE status<>'published') THEN RAISE EXCEPTION 'Learner can read drafts';END IF;
 report:=public.englify_report_arena_question((SELECT session_id FROM question_management_fixture),(SELECT question_id FROM question_management_fixture),'unclear','Needs review');
 IF report ? 'reporter_id' OR report->>'reason'<>'unclear' THEN RAISE EXCEPTION 'Unsafe question report response';END IF;
END $$;
RESET ROLE;
ROLLBACK;
