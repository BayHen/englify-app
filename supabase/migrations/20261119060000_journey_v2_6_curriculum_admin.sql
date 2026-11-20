-- Journey V2.6: version-aware curriculum administration. Existing learner rows are never rewritten.
ALTER TABLE public.journey_chapters ADD COLUMN learning_objectives jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(learning_objectives)='array'), ADD COLUMN lifecycle_status text NOT NULL DEFAULT 'draft' CHECK(lifecycle_status IN ('draft','in_review','approved','published','archived'));
ALTER TABLE public.learning_units ADD COLUMN description text NOT NULL DEFAULT '', ADD COLUMN learning_objectives jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(learning_objectives)='array'), ADD COLUMN estimated_minutes smallint NOT NULL DEFAULT 60 CHECK(estimated_minutes BETWEEN 1 AND 1440), ADD COLUMN lifecycle_status text NOT NULL DEFAULT 'draft' CHECK(lifecycle_status IN ('draft','in_review','approved','published','archived'));
ALTER TABLE public.lessons ADD COLUMN lifecycle_status text NOT NULL DEFAULT 'draft' CHECK(lifecycle_status IN ('draft','in_review','approved','published','archived'));
UPDATE public.journey_chapters SET lifecycle_status='published' WHERE is_published AND archived_at IS NULL;
UPDATE public.learning_units SET lifecycle_status='published' WHERE is_published AND archived_at IS NULL;
UPDATE public.lessons SET lifecycle_status='published' WHERE is_published AND archived_at IS NULL;

ALTER TABLE public.journey_lesson_revisions DROP CONSTRAINT journey_lesson_revisions_status_check;
ALTER TABLE public.journey_lesson_revisions ADD CONSTRAINT journey_lesson_revisions_status_check CHECK(status IN ('draft','in_review','approved','published','retired','archived'));

CREATE TABLE public.journey_content_reviews(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), resource_type text NOT NULL CHECK(resource_type IN ('chapter','unit','lesson','revision','checkpoint')),
 resource_id uuid NOT NULL, version integer NOT NULL DEFAULT 1 CHECK(version>0), decision text NOT NULL CHECK(decision IN ('submitted','approved','rejected','revision_requested','published','archived')),
 reason text NOT NULL DEFAULT '' CHECK(length(reason)<=1000), reviewer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX journey_content_reviews_resource_idx ON public.journey_content_reviews(resource_type,resource_id,created_at DESC);
CREATE TABLE public.journey_import_batches(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT, request_id uuid NOT NULL,
 filename text NOT NULL CHECK(length(filename) BETWEEN 1 AND 180), format text NOT NULL CHECK(format IN ('csv','xlsx')), status text NOT NULL DEFAULT 'staged' CHECK(status IN ('staged','committed')),
 row_count integer NOT NULL CHECK(row_count BETWEEN 1 AND 500), created_at timestamptz NOT NULL DEFAULT now(), committed_at timestamptz, UNIQUE(created_by,request_id)
);
CREATE TABLE public.journey_import_rows(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), batch_id uuid NOT NULL REFERENCES public.journey_import_batches(id) ON DELETE CASCADE, row_number integer NOT NULL CHECK(row_number>1),
 raw_data jsonb NOT NULL CHECK(jsonb_typeof(raw_data)='object'), validation_errors jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(validation_errors)='array'), imported_id uuid, UNIQUE(batch_id,row_number)
);
ALTER TABLE public.journey_content_reviews ENABLE ROW LEVEL SECURITY; ALTER TABLE public.journey_import_batches ENABLE ROW LEVEL SECURITY; ALTER TABLE public.journey_import_rows ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.journey_content_reviews,public.journey_import_batches,public.journey_import_rows FROM anon,authenticated;
GRANT ALL ON public.journey_content_reviews,public.journey_import_batches,public.journey_import_rows TO service_role;
GRANT SELECT ON public.journey_content_reviews,public.journey_import_batches,public.journey_import_rows TO authenticated;
CREATE POLICY journey_reviews_admin ON public.journey_content_reviews FOR SELECT TO authenticated USING(public.englify_is_admin());
CREATE POLICY journey_import_batches_admin ON public.journey_import_batches FOR SELECT TO authenticated USING(public.englify_is_admin());
CREATE POLICY journey_import_rows_admin ON public.journey_import_rows FOR SELECT TO authenticated USING(public.englify_is_admin());

CREATE FUNCTION public.englify_admin_journey_overview() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('chapters',(SELECT count(*) FROM public.journey_chapters WHERE archived_at IS NULL),'units',(SELECT count(*) FROM public.learning_units WHERE archived_at IS NULL),
 'lessons',(SELECT count(*) FROM public.lessons WHERE archived_at IS NULL),'published_lessons',(SELECT count(*) FROM public.lessons WHERE lifecycle_status='published' AND archived_at IS NULL),
 'draft_lessons',(SELECT count(*) FROM public.lessons WHERE lifecycle_status='draft' AND archived_at IS NULL),'pending_reviews',(SELECT count(*) FROM public.lessons WHERE lifecycle_status='in_review' AND archived_at IS NULL),'reported_content',0,
 'checkpoints',(SELECT count(*) FROM public.journey_checkpoint_configs),'tree',(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY cefr_level,chapter_position,unit_position,lesson_position),'[]') FROM (
 SELECT c.cefr_level,c.id course_id,c.title course_title,ch.id chapter_id,ch.title chapter_title,ch.position chapter_position,ch.lifecycle_status chapter_status,
 u.id unit_id,u.title unit_title,u.position unit_position,u.lifecycle_status unit_status,l.id lesson_id,l.title lesson_title,l.position lesson_position,l.lesson_kind,l.lifecycle_status lesson_status,l.estimated_minutes
 FROM public.courses c LEFT JOIN public.journey_chapters ch ON ch.course_id=c.id AND ch.archived_at IS NULL LEFT JOIN public.learning_units u ON u.chapter_id=ch.id AND u.archived_at IS NULL LEFT JOIN public.lessons l ON l.unit_id=u.id AND l.archived_at IS NULL WHERE c.archived_at IS NULL)x)); END $$;

CREATE FUNCTION public.englify_admin_save_journey_lesson(p_request_id uuid,p_id uuid,p_data jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE old public.lessons%ROWTYPE; saved public.lessons%ROWTYPE; revision_id uuid; next_version integer; blocks jsonb; block jsonb; pos integer:=0;
BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR jsonb_typeof(p_data)<>'object' OR length(btrim(coalesce(p_data->>'title',''))) NOT BETWEEN 1 AND 120 OR coalesce(p_data->>'slug','') !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' THEN RAISE EXCEPTION 'Invalid lesson draft' USING ERRCODE='22023'; END IF;
 SELECT * INTO old FROM public.lessons WHERE id=p_id FOR UPDATE;
 IF old.id IS NULL THEN INSERT INTO public.lessons(id,course_id,unit_id,slug,title,objective,position,xp_reward,is_required,estimated_minutes,lesson_kind,lifecycle_status,is_published)
 VALUES(coalesce(p_id,gen_random_uuid()),(p_data->>'course_id')::uuid,(p_data->>'unit_id')::uuid,p_data->>'slug',p_data->>'title',coalesce(p_data->>'objective',''),(p_data->>'position')::int,coalesce((p_data->>'xp_reward')::int,0),coalesce((p_data->>'is_required')::boolean,true),coalesce((p_data->>'estimated_minutes')::int,10),coalesce(p_data->>'lesson_kind','lesson'),'draft',false) RETURNING * INTO saved;
 ELSE IF old.lifecycle_status='published' THEN RAISE EXCEPTION 'Published lesson metadata is immutable; duplicate a draft revision' USING ERRCODE='PT409'; END IF;
 UPDATE public.lessons SET title=p_data->>'title',objective=coalesce(p_data->>'objective',objective),position=coalesce((p_data->>'position')::int,position),estimated_minutes=coalesce((p_data->>'estimated_minutes')::int,estimated_minutes),updated_at=now() WHERE id=old.id RETURNING * INTO saved; END IF;
 blocks:=coalesce(p_data->'blocks','[]'); IF jsonb_typeof(blocks)<>'array' OR jsonb_array_length(blocks)>100 THEN RAISE EXCEPTION 'Invalid lesson blocks' USING ERRCODE='22023'; END IF;
 SELECT coalesce(max(version),0)+1 INTO next_version FROM public.journey_lesson_revisions WHERE lesson_id=saved.id;
 INSERT INTO public.journey_lesson_revisions(lesson_id,version,status,source,content_hash,created_by) VALUES(saved.id,next_version,'draft',coalesce(p_data->>'source','curated'),encode(extensions.digest(blocks::text,'sha256'),'hex'),auth.uid()) RETURNING id INTO revision_id;
 FOR block IN SELECT value FROM jsonb_array_elements(blocks) LOOP pos:=pos+1; IF NOT public.englify_journey_validate_block(block->>'type',block->'content') THEN RAISE EXCEPTION 'Invalid block at position %',pos USING ERRCODE='22023'; END IF; INSERT INTO public.journey_lesson_blocks(revision_id,lesson_id,position,block_type,content) VALUES(revision_id,saved.id,pos,block->>'type',block->'content'); END LOOP;
 INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data) VALUES(auth.uid(),CASE WHEN old.id IS NULL THEN 'create' ELSE 'update' END,'journey-lesson',saved.id,CASE WHEN old.id IS NULL THEN NULL ELSE to_jsonb(old) END,to_jsonb(saved)||jsonb_build_object('revision_id',revision_id));
 RETURN to_jsonb(saved)||jsonb_build_object('revision_id',revision_id,'revision_version',next_version); END $$;

CREATE FUNCTION public.englify_admin_transition_journey_lesson(p_id uuid,p_status text,p_reason text DEFAULT '') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.lessons%ROWTYPE; revision public.journey_lesson_revisions%ROWTYPE; version int;
BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501'; END IF;
 IF p_status NOT IN ('in_review','approved','published','draft','archived') THEN RAISE EXCEPTION 'Invalid lifecycle status' USING ERRCODE='22023'; END IF;
 SELECT * INTO item FROM public.lessons WHERE id=p_id FOR UPDATE; IF item.id IS NULL THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Lesson not found'; END IF;
 SELECT * INTO revision FROM public.journey_lesson_revisions WHERE lesson_id=p_id AND status IN ('draft','in_review','approved') ORDER BY version DESC LIMIT 1 FOR UPDATE;
 IF p_status IN ('in_review','approved','published') AND revision.id IS NULL THEN RAISE EXCEPTION 'A reviewable revision is required' USING ERRCODE='22023'; END IF;
 IF p_status='approved' AND item.lifecycle_status<>'in_review' OR p_status='published' AND item.lifecycle_status<>'approved' THEN RAISE EXCEPTION 'Invalid lifecycle transition' USING ERRCODE='PT409'; END IF;
 IF p_status='published' THEN UPDATE public.journey_lesson_revisions SET status='draft' WHERE id=revision.id; PERFORM public.englify_admin_publish_lesson_revision(revision.id); UPDATE public.lessons SET lifecycle_status='published',is_published=true,archived_at=NULL,updated_at=now() WHERE id=p_id;
 ELSIF p_status='archived' THEN UPDATE public.lessons SET lifecycle_status='archived',is_published=false,archived_at=coalesce(archived_at,now()),updated_at=now() WHERE id=p_id;
 ELSE UPDATE public.lessons SET lifecycle_status=p_status,is_published=false,updated_at=now() WHERE id=p_id; UPDATE public.journey_lesson_revisions SET status=p_status WHERE id=revision.id; END IF;
 version:=coalesce(revision.version,1); INSERT INTO public.journey_content_reviews(resource_type,resource_id,version,decision,reason,reviewer_id) VALUES('lesson',p_id,version,CASE p_status WHEN 'in_review' THEN 'submitted' WHEN 'draft' THEN 'revision_requested' ELSE p_status END,coalesce(p_reason,''),auth.uid());
 INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data) VALUES(auth.uid(),CASE p_status WHEN 'approved' THEN 'update' WHEN 'published' THEN 'publish' ELSE 'transition:'||p_status END,'journey-lesson',p_id,to_jsonb(item),jsonb_build_object('status',p_status,'reason',coalesce(p_reason,'')));
 RETURN (SELECT to_jsonb(l) FROM public.lessons l WHERE id=p_id); END $$;

REVOKE ALL ON FUNCTION public.englify_admin_journey_overview(),public.englify_admin_save_journey_lesson(uuid,uuid,jsonb),public.englify_admin_transition_journey_lesson(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_admin_journey_overview(),public.englify_admin_save_journey_lesson(uuid,uuid,jsonb),public.englify_admin_transition_journey_lesson(uuid,text,text) TO authenticated;
