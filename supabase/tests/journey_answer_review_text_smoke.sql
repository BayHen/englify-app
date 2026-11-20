BEGIN;
INSERT INTO auth.users(id) VALUES ('b6444444-4444-4444-8444-444444444444');
INSERT INTO public.courses(id,slug,title,level,cefr_level,is_published) VALUES('b6400000-0000-4000-8000-000000000001','journey-review-text','Review text',64,'A1',true);
INSERT INTO public.learning_units(id,course_id,slug,title,position,is_published) VALUES('b6400000-0000-4000-8000-000000000002','b6400000-0000-4000-8000-000000000001','unit','Unit',1,true);
INSERT INTO public.lessons(id,course_id,unit_id,slug,title,objective,position,is_published) VALUES('b6400000-0000-4000-8000-000000000003','b6400000-0000-4000-8000-000000000001','b6400000-0000-4000-8000-000000000002','lesson','Greeting review','Choose a greeting',1,true);
INSERT INTO public.journey_lesson_revisions(id,lesson_id,version,status,source,content_hash,published_at) VALUES('b6400000-0000-4000-8000-000000000004','b6400000-0000-4000-8000-000000000003',1,'published','curated','review-text-v1',now());
INSERT INTO public.journey_lesson_blocks(id,revision_id,lesson_id,position,block_type,content) VALUES('b6400000-0000-4000-8000-000000000005','b6400000-0000-4000-8000-000000000004','b6400000-0000-4000-8000-000000000003',1,'introduction','{"text_en":"Choose a natural greeting."}');
INSERT INTO public.quiz_questions(id,lesson_id,position,kind,prompt,explanation,is_published,explanation_en,explanation_vi) VALUES('b6400000-0000-4000-8000-000000000006','b6400000-0000-4000-8000-000000000003',1,'multiple_choice','Which is a greeting?','A greeting starts a conversation.',false,'This phrase is a greeting.','Cụm từ này là lời chào.');
INSERT INTO public.quiz_options(id,question_id,position,answer_text,is_correct) VALUES
 ('b6400000-0000-4000-8000-000000000007','b6400000-0000-4000-8000-000000000006',1,'How is it going?',true),
 ('b6400000-0000-4000-8000-000000000008','b6400000-0000-4000-8000-000000000006',2,'Close the door.',false);
UPDATE public.quiz_questions SET is_published=true WHERE id='b6400000-0000-4000-8000-000000000006';
SELECT set_config('request.jwt.claim.sub','b6444444-4444-4444-8444-444444444444',true); SET LOCAL ROLE authenticated;
DO $$ DECLARE result jsonb; BEGIN
 result:=public.englify_submit_lesson('b6400000-0000-4000-8000-000000000003','b6400000-0000-4000-8000-000000000009','{"b6400000-0000-4000-8000-000000000006":"b6400000-0000-4000-8000-000000000007"}',NULL);
 IF result#>>'{review,0,learner_answer}' <> 'How is it going?' OR result#>>'{review,0,correct_answer}' <> 'How is it going?' THEN
   RAISE EXCEPTION 'Review exposed an option ID instead of display text: %',result->'review';
 END IF;
END $$;
ROLLBACK;

