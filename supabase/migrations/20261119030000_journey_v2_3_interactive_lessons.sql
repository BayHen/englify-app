-- Journey V2.3: versioned structured lesson content, private resume/notes/bookmarks,
-- curated hints and post-submission feedback. Existing items, attempts and XP remain intact.

CREATE TABLE public.journey_lesson_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  version integer NOT NULL CHECK(version>0), status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published','retired')),
  source text NOT NULL DEFAULT 'curated' CHECK(source IN ('curated','legacy','ai_draft')),
  content_hash text NOT NULL, created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(), published_at timestamptz,
  UNIQUE(lesson_id,version), UNIQUE(id,lesson_id), CHECK((status='published')=(published_at IS NOT NULL))
);
CREATE UNIQUE INDEX journey_lesson_one_published_revision ON public.journey_lesson_revisions(lesson_id) WHERE status='published';

CREATE TABLE public.journey_lesson_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), revision_id uuid NOT NULL REFERENCES public.journey_lesson_revisions(id) ON DELETE CASCADE,
  lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE, position integer NOT NULL CHECK(position>0),
  block_type text NOT NULL CHECK(block_type IN ('introduction','objective','theory','example','vocabulary','grammar','dialogue','audio','practice','summary')),
  content jsonb NOT NULL CHECK(jsonb_typeof(content)='object'), created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(revision_id,position), FOREIGN KEY(revision_id,lesson_id) REFERENCES public.journey_lesson_revisions(id,lesson_id) ON DELETE CASCADE,
  CHECK(length(coalesce(content->>'text_en',content->>'word',content->>'title',''))<=10000),
  CHECK(NOT content ? 'html')
);
CREATE INDEX journey_lesson_blocks_lesson_revision_idx ON public.journey_lesson_blocks(lesson_id,revision_id,position);

CREATE TABLE public.journey_lesson_resume (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  revision_id uuid NOT NULL, block_id uuid NOT NULL REFERENCES public.journey_lesson_blocks(id) ON DELETE CASCADE,
  answers jsonb NOT NULL DEFAULT '{}' CHECK(jsonb_typeof(answers)='object'), updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id,lesson_id), FOREIGN KEY(revision_id,lesson_id) REFERENCES public.journey_lesson_revisions(id,lesson_id) ON DELETE CASCADE
);
CREATE INDEX journey_lesson_resume_recent_idx ON public.journey_lesson_resume(user_id,updated_at DESC);

CREATE TABLE public.journey_lesson_bookmarks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE, block_id uuid REFERENCES public.journey_lesson_blocks(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX journey_lesson_bookmark_unique ON public.journey_lesson_bookmarks(user_id,lesson_id,coalesce(block_id,'00000000-0000-0000-0000-000000000000'::uuid));
CREATE INDEX journey_lesson_bookmarks_user_idx ON public.journey_lesson_bookmarks(user_id,created_at DESC);

CREATE TABLE public.journey_lesson_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE, block_id uuid REFERENCES public.journey_lesson_blocks(id) ON DELETE SET NULL,
  note text NOT NULL CHECK(length(btrim(note)) BETWEEN 1 AND 1000), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX journey_lesson_notes_user_lesson_idx ON public.journey_lesson_notes(user_id,lesson_id,updated_at DESC);

ALTER TABLE public.quiz_questions ADD COLUMN hint_en text, ADD COLUMN hint_vi text, ADD COLUMN explanation_en text, ADD COLUMN explanation_vi text;
ALTER TABLE public.lesson_attempts ADD COLUMN revision_id uuid REFERENCES public.journey_lesson_revisions(id) ON DELETE SET NULL;

-- Publish a compatibility revision for every existing lesson. Legacy reading/tip rows remain untouched.
INSERT INTO public.journey_lesson_revisions(lesson_id,version,status,source,content_hash,published_at)
SELECT l.id,1,'published','legacy',encode(extensions.digest(l.id::text||':'||coalesce(jsonb_agg(i.body ORDER BY i.position)::text,''),'sha256'),'hex'),transaction_timestamp()
FROM public.lessons l LEFT JOIN public.lesson_items i ON i.lesson_id=l.id GROUP BY l.id;
INSERT INTO public.journey_lesson_blocks(revision_id,lesson_id,position,block_type,content)
SELECT r.id,i.lesson_id,i.position,CASE i.kind WHEN 'tip' THEN 'grammar' ELSE 'theory' END,
  jsonb_build_object('text_en',coalesce(i.body->>'text',''),'text_vi',coalesce(i.body->>'text_vi',''),'legacy_item_id',i.id)
FROM public.lesson_items i JOIN public.journey_lesson_revisions r ON r.lesson_id=i.lesson_id AND r.status='published'
WHERE i.is_published AND i.archived_at IS NULL;

ALTER TABLE public.journey_lesson_revisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_lesson_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_lesson_resume ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_lesson_bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journey_lesson_notes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.journey_lesson_revisions,public.journey_lesson_blocks,public.journey_lesson_resume,
 public.journey_lesson_bookmarks,public.journey_lesson_notes FROM anon,authenticated;
GRANT ALL ON public.journey_lesson_revisions,public.journey_lesson_blocks,public.journey_lesson_resume,
 public.journey_lesson_bookmarks,public.journey_lesson_notes TO service_role;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.journey_lesson_revisions,public.journey_lesson_blocks TO authenticated;
GRANT SELECT ON public.journey_lesson_resume,public.journey_lesson_bookmarks,public.journey_lesson_notes TO authenticated;
CREATE POLICY journey_revisions_published_read ON public.journey_lesson_revisions FOR SELECT TO authenticated USING(status='published' OR public.englify_is_admin());
CREATE POLICY journey_blocks_published_read ON public.journey_lesson_blocks FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.journey_lesson_revisions r WHERE r.id=revision_id AND (r.status='published' OR public.englify_is_admin())));
CREATE POLICY journey_revisions_admin_write ON public.journey_lesson_revisions FOR ALL TO authenticated USING(public.englify_is_admin()) WITH CHECK(public.englify_is_admin());
CREATE POLICY journey_blocks_admin_write ON public.journey_lesson_blocks FOR ALL TO authenticated USING(public.englify_is_admin()) WITH CHECK(public.englify_is_admin());
CREATE POLICY journey_resume_own_read ON public.journey_lesson_resume FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
CREATE POLICY journey_bookmarks_own_read ON public.journey_lesson_bookmarks FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
CREATE POLICY journey_notes_own_read ON public.journey_lesson_notes FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));

CREATE FUNCTION public.englify_journey_validate_block(p_type text,p_content jsonb) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT jsonb_typeof(p_content)='object' AND NOT p_content ? 'html' AND CASE p_type
  WHEN 'vocabulary' THEN length(btrim(coalesce(p_content->>'word','')))>0 AND length(btrim(coalesce(p_content->>'meaning_vi','')))>0
  WHEN 'dialogue' THEN jsonb_typeof(p_content->'lines')='array'
  WHEN 'audio' THEN length(btrim(coalesce(p_content->>'text_en','')))>0 OR length(btrim(coalesce(p_content->>'audio_url','')))>0
  WHEN 'practice' THEN p_content ? 'question_id'
  ELSE length(btrim(coalesce(p_content->>'text_en',p_content->>'title','')))>0 END
$$;
ALTER TABLE public.journey_lesson_blocks ADD CONSTRAINT journey_block_payload_check CHECK(public.englify_journey_validate_block(block_type,content));

CREATE OR REPLACE FUNCTION public.englify_lesson_content_version(p_lesson_id uuid) RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE snapshot jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 IF public.englify_lesson_state(p_lesson_id) IS NULL THEN RAISE EXCEPTION 'Published lesson not found' USING ERRCODE='P0002'; END IF;
 SELECT jsonb_build_object('lesson',jsonb_build_object('id',l.id,'title',l.title,'objective',l.objective,'updated_at',l.updated_at),
   'revision',jsonb_build_object('id',r.id,'version',r.version,'hash',r.content_hash),
   'blocks',coalesce((SELECT jsonb_agg(jsonb_build_object('id',b.id,'position',b.position,'type',b.block_type,'content',b.content) ORDER BY b.position,b.id) FROM public.journey_lesson_blocks b WHERE b.revision_id=r.id),'[]'),
   'questions',coalesce((SELECT jsonb_agg(jsonb_build_object('id',q.id,'position',q.position,'kind',q.kind,'prompt',q.prompt,'payload',q.payload,'updated_at',q.updated_at) ORDER BY q.position,q.id) FROM public.quiz_questions q WHERE q.lesson_id=l.id AND q.is_published AND q.archived_at IS NULL),'[]'),
   'options',coalesce((SELECT jsonb_agg(jsonb_build_object('id',o.id,'question_id',o.question_id,'position',o.position,'answer_text',o.answer_text) ORDER BY o.question_id,o.position,o.id) FROM public.quiz_options o JOIN public.quiz_questions q ON q.id=o.question_id WHERE q.lesson_id=l.id AND q.is_published AND q.archived_at IS NULL),'[]'))
 INTO snapshot FROM public.lessons l LEFT JOIN public.journey_lesson_revisions r ON r.lesson_id=l.id AND r.status='published' WHERE l.id=p_lesson_id;
 RETURN encode(extensions.digest(snapshot::text,'sha256'),'hex');
END $$;

CREATE FUNCTION public.englify_save_lesson_resume(p_lesson uuid,p_revision uuid,p_block uuid,p_answers jsonb DEFAULT '{}') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); active_revision uuid;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 IF jsonb_typeof(p_answers)<>'object' OR pg_column_size(p_answers)>65536 THEN RAISE EXCEPTION 'Invalid answer draft' USING ERRCODE='22023'; END IF;
 SELECT id INTO active_revision FROM public.journey_lesson_revisions WHERE lesson_id=p_lesson AND status='published';
 IF active_revision IS NULL OR active_revision<>p_revision OR NOT EXISTS(SELECT 1 FROM public.journey_lesson_blocks WHERE id=p_block AND revision_id=p_revision AND lesson_id=p_lesson)
   OR public.englify_lesson_state(p_lesson)='locked' THEN RAISE EXCEPTION 'Active lesson block not found' USING ERRCODE='P0002'; END IF;
 INSERT INTO public.journey_lesson_resume(user_id,lesson_id,revision_id,block_id,answers) VALUES(uid,p_lesson,p_revision,p_block,p_answers)
 ON CONFLICT(user_id,lesson_id) DO UPDATE SET revision_id=excluded.revision_id,block_id=excluded.block_id,answers=excluded.answers,updated_at=now()
 WHERE public.journey_lesson_resume.updated_at<=now();
 RETURN jsonb_build_object('saved',true,'updated_at',(SELECT updated_at FROM public.journey_lesson_resume WHERE user_id=uid AND lesson_id=p_lesson));
END $$;

CREATE FUNCTION public.englify_toggle_lesson_bookmark(p_lesson uuid,p_block uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); removed int; saved_id uuid;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lessons l WHERE l.id=p_lesson AND l.is_published AND l.archived_at IS NULL) OR (p_block IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.journey_lesson_blocks b JOIN public.journey_lesson_revisions r ON r.id=b.revision_id WHERE b.id=p_block AND b.lesson_id=p_lesson AND r.status='published')) THEN RAISE EXCEPTION 'Published lesson content not found' USING ERRCODE='P0002'; END IF;
 DELETE FROM public.journey_lesson_bookmarks WHERE user_id=uid AND lesson_id=p_lesson AND block_id IS NOT DISTINCT FROM p_block; GET DIAGNOSTICS removed=ROW_COUNT;
 IF removed>0 THEN RETURN jsonb_build_object('bookmarked',false); END IF;
 INSERT INTO public.journey_lesson_bookmarks(user_id,lesson_id,block_id) VALUES(uid,p_lesson,p_block) RETURNING id INTO saved_id;
 RETURN jsonb_build_object('bookmarked',true,'id',saved_id);
END $$;

CREATE FUNCTION public.englify_save_lesson_note(p_lesson uuid,p_block uuid,p_note text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE uid uuid:=auth.uid(); saved public.journey_lesson_notes;
BEGIN
 IF uid IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 IF length(btrim(coalesce(p_note,''))) NOT BETWEEN 1 AND 1000 OR NOT EXISTS(SELECT 1 FROM public.journey_lesson_blocks b JOIN public.journey_lesson_revisions r ON r.id=b.revision_id WHERE b.id=p_block AND b.lesson_id=p_lesson AND r.status='published') THEN RAISE EXCEPTION 'Invalid lesson note' USING ERRCODE='22023'; END IF;
 INSERT INTO public.journey_lesson_notes(user_id,lesson_id,block_id,note) VALUES(uid,p_lesson,p_block,btrim(p_note)) RETURNING * INTO saved;
 RETURN to_jsonb(saved);
END $$;

CREATE FUNCTION public.englify_admin_publish_lesson_revision(p_revision uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE target public.journey_lesson_revisions; invalid_count int;
BEGIN
 IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 SELECT * INTO target FROM public.journey_lesson_revisions WHERE id=p_revision FOR UPDATE;
 IF target.id IS NULL OR target.status<>'draft' THEN RAISE EXCEPTION 'Draft revision not found' USING ERRCODE='P0002'; END IF;
 SELECT count(*) INTO invalid_count FROM public.journey_lesson_blocks WHERE revision_id=p_revision AND NOT public.englify_journey_validate_block(block_type,content);
 IF invalid_count>0 OR NOT EXISTS(SELECT 1 FROM public.journey_lesson_blocks WHERE revision_id=p_revision) THEN RAISE EXCEPTION 'Revision has invalid or missing blocks' USING ERRCODE='22023'; END IF;
 UPDATE public.journey_lesson_revisions SET status='retired',published_at=NULL WHERE lesson_id=target.lesson_id AND status='published';
 UPDATE public.journey_lesson_revisions SET status='published',published_at=now(),content_hash=encode(extensions.digest((SELECT jsonb_agg(jsonb_build_object('position',position,'type',block_type,'content',content) ORDER BY position)::text FROM public.journey_lesson_blocks WHERE revision_id=p_revision),'sha256'),'hex') WHERE id=p_revision;
 INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data) VALUES(auth.uid(),'publish','journey-lesson-revision',p_revision,jsonb_build_object('status','draft'),jsonb_build_object('status','published'));
 RETURN jsonb_build_object('revision_id',p_revision,'status','published');
END $$;

CREATE OR REPLACE FUNCTION public.englify_lesson_detail(p_lesson_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE state text; lesson record; items jsonb; questions jsonb; revision record; blocks jsonb; personal jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000'; END IF;
 state:=public.englify_lesson_state(p_lesson_id); IF state IS NULL THEN RAISE EXCEPTION 'Published lesson not found' USING ERRCODE='P0002'; END IF;
 IF state='locked' THEN RAISE EXCEPTION 'Complete the required lessons first' USING ERRCODE='42501'; END IF;
 SELECT l.*,c.cefr_level,u.title unit_title INTO lesson FROM public.lessons l JOIN public.courses c ON c.id=l.course_id JOIN public.learning_units u ON u.id=l.unit_id WHERE l.id=p_lesson_id;
 SELECT * INTO revision FROM public.journey_lesson_revisions WHERE lesson_id=p_lesson_id AND status='published';
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',b.id,'type',b.block_type,'position',b.position,'content',b.content) ORDER BY b.position),'[]') INTO blocks FROM public.journey_lesson_blocks b WHERE b.revision_id=revision.id;
 SELECT coalesce(jsonb_agg(jsonb_build_object('kind',i.kind,'body',i.body) ORDER BY i.position),'[]') INTO items FROM public.lesson_items i WHERE i.lesson_id=p_lesson_id AND i.is_published AND i.archived_at IS NULL;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',q.id,'kind',q.kind,'prompt',q.prompt,'payload',q.payload,'hint_en',q.hint_en,'hint_vi',q.hint_vi,
   'options',CASE WHEN q.kind='multiple_choice' THEN coalesce((SELECT jsonb_agg(jsonb_build_object('id',o.id,'text',o.answer_text) ORDER BY o.position) FROM public.quiz_options o WHERE o.question_id=q.id),'[]') ELSE '[]' END) ORDER BY q.position),'[]')
 INTO questions FROM public.quiz_questions q WHERE q.lesson_id=p_lesson_id AND q.is_published AND q.archived_at IS NULL;
 SELECT jsonb_build_object('resume',(SELECT to_jsonb(x) FROM public.journey_lesson_resume x WHERE x.user_id=auth.uid() AND x.lesson_id=p_lesson_id AND x.revision_id=revision.id),
   'bookmarked',EXISTS(SELECT 1 FROM public.journey_lesson_bookmarks x WHERE x.user_id=auth.uid() AND x.lesson_id=p_lesson_id AND x.block_id IS NULL),
   'notes',coalesce((SELECT jsonb_agg(to_jsonb(n) ORDER BY n.updated_at DESC) FROM public.journey_lesson_notes n WHERE n.user_id=auth.uid() AND n.lesson_id=p_lesson_id),'[]')) INTO personal;
 RETURN public.englify_journey_lesson_node(p_lesson_id)||jsonb_build_object('state',state,'cefr_level',lesson.cefr_level,'topic',lesson.unit_title,
   'revision_id',revision.id,'content_version',revision.content_hash,'blocks',blocks,'items',items,'questions',questions,'personal',personal);
END $$;

-- Preserve the proven V2.1/V2.2 transaction, then attach immutable revision and protected review.
ALTER FUNCTION public.englify_submit_lesson(uuid,uuid,jsonb,text) RENAME TO englify_submit_lesson_v2;
REVOKE ALL ON FUNCTION public.englify_submit_lesson_v2(uuid,uuid,jsonb,text) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.englify_submit_lesson(p_lesson_id uuid,p_request_id uuid,p_answers jsonb,p_content_version text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE result jsonb; attempt uuid; revision uuid; review jsonb;
BEGIN
 result:=public.englify_submit_lesson_v2(p_lesson_id,p_request_id,p_answers,p_content_version); attempt:=(result->>'attempt_id')::uuid;
 SELECT id INTO revision FROM public.journey_lesson_revisions WHERE lesson_id=p_lesson_id AND status='published';
 UPDATE public.lesson_attempts SET revision_id=revision WHERE id=attempt AND user_id=auth.uid() AND revision_id IS NULL;
 SELECT coalesce(jsonb_agg(jsonb_build_object('question_id',a.question_id,'is_correct',a.is_correct,'learner_answer',a.answer,
   'correct_answer',k.answer,'explanation_en',q.explanation_en,'explanation_vi',q.explanation_vi) ORDER BY q.position),'[]') INTO review
 FROM public.lesson_answer_attempts a JOIN public.lesson_attempts la ON la.id=a.attempt_id JOIN public.quiz_questions q ON q.id=a.question_id LEFT JOIN public.quiz_answer_keys k ON k.question_id=q.id
 WHERE a.attempt_id=attempt AND la.user_id=auth.uid();
 RETURN result||jsonb_build_object('revision_id',revision,'review',review);
END $$;

REVOKE ALL ON FUNCTION public.englify_save_lesson_resume(uuid,uuid,uuid,jsonb),public.englify_toggle_lesson_bookmark(uuid,uuid),
 public.englify_save_lesson_note(uuid,uuid,text),public.englify_admin_publish_lesson_revision(uuid),public.englify_submit_lesson(uuid,uuid,jsonb,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_save_lesson_resume(uuid,uuid,uuid,jsonb),public.englify_toggle_lesson_bookmark(uuid,uuid),
 public.englify_save_lesson_note(uuid,uuid,text),public.englify_admin_publish_lesson_revision(uuid),public.englify_submit_lesson(uuid,uuid,jsonb,text) TO authenticated;
