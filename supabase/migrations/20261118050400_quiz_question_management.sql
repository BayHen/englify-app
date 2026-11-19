-- Quiz Arena V2.5: versioned question management, staged imports, review and reports.
CREATE TABLE public.arena_topics (
 slug text PRIMARY KEY CHECK(slug ~ '^[a-z][a-z0-9_]{1,39}$'),
 title text NOT NULL CHECK(char_length(btrim(title)) BETWEEN 2 AND 80),
 description text NOT NULL DEFAULT '' CHECK(char_length(description)<=500),
 sort_order integer NOT NULL DEFAULT 0,
 status text NOT NULL DEFAULT 'published' CHECK(status IN ('published','archived')),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.arena_topics(slug,title,sort_order) VALUES
 ('grammar','Grammar',10),('vocabulary','Vocabulary',20),('reading','Reading',30),('everyday','Everyday English',40),
 ('business','Business',50),('travel','Travel',60),('sentence_structure','Sentence Structure',70),
 ('phrasal_verbs','Phrasal Verbs',80),('idioms','Idioms',90) ON CONFLICT DO NOTHING;

ALTER TABLE public.arena_questions ADD COLUMN status text NOT NULL DEFAULT 'draft'
 CHECK(status IN ('draft','in_review','published','archived'));
ALTER TABLE public.arena_questions ADD COLUMN current_version integer NOT NULL DEFAULT 1 CHECK(current_version>0);
ALTER TABLE public.arena_questions ADD COLUMN normalized_prompt text NOT NULL DEFAULT '';
ALTER TABLE public.arena_questions ADD COLUMN origin text NOT NULL DEFAULT 'editorial' CHECK(origin IN ('editorial','import','ai'));
ALTER TABLE public.arena_questions ADD COLUMN external_id text;
ALTER TABLE public.arena_questions ADD COLUMN created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.arena_questions ADD COLUMN updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.arena_questions ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
UPDATE public.arena_questions SET status=CASE WHEN archived_at IS NOT NULL THEN 'archived' WHEN is_published THEN 'published' ELSE 'draft' END,
 normalized_prompt=lower(regexp_replace(regexp_replace(btrim(prompt),'[^[:alnum:][:space:]]','','g'),'\s+',' ','g'));
CREATE UNIQUE INDEX arena_question_external_id ON public.arena_questions(external_id) WHERE external_id IS NOT NULL;
CREATE INDEX arena_question_admin_list ON public.arena_questions(status,updated_at DESC,id);
CREATE INDEX arena_question_normalized ON public.arena_questions(normalized_prompt,cefr_level,topic,kind);
ALTER TABLE public.arena_questions ADD CONSTRAINT arena_question_topic_fk FOREIGN KEY(topic) REFERENCES public.arena_topics(slug) ON UPDATE CASCADE;

CREATE TABLE public.arena_question_revisions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),question_id uuid NOT NULL REFERENCES public.arena_questions(id) ON DELETE RESTRICT,
 version integer NOT NULL CHECK(version>0),content jsonb NOT NULL CHECK(jsonb_typeof(content)='object'),answer jsonb NOT NULL,
 explanation_vi text NOT NULL,status text NOT NULL CHECK(status IN ('draft','in_review','published','archived')),
 change_note text NOT NULL DEFAULT '' CHECK(char_length(change_note)<=500),created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
 created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(question_id,version)
);
CREATE INDEX arena_question_revision_history ON public.arena_question_revisions(question_id,version DESC);

CREATE TABLE public.arena_question_import_batches (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 request_id uuid NOT NULL,filename text NOT NULL CHECK(char_length(filename) BETWEEN 1 AND 180),format text NOT NULL CHECK(format IN ('csv','xlsx')),
 status text NOT NULL DEFAULT 'staged' CHECK(status IN ('staged','committed','cancelled')),
 row_count integer NOT NULL CHECK(row_count BETWEEN 1 AND 500),valid_count integer NOT NULL DEFAULT 0,duplicate_count integer NOT NULL DEFAULT 0,
 created_at timestamptz NOT NULL DEFAULT now(),committed_at timestamptz,UNIQUE(created_by,request_id)
);
CREATE TABLE public.arena_question_import_rows (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),batch_id uuid NOT NULL REFERENCES public.arena_question_import_batches(id) ON DELETE CASCADE,
 row_number integer NOT NULL CHECK(row_number>1),raw_data jsonb NOT NULL CHECK(jsonb_typeof(raw_data)='object'),normalized_data jsonb,
 validation_errors jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(validation_errors)='array'),duplicate_question_id uuid REFERENCES public.arena_questions(id),
 selected boolean NOT NULL DEFAULT true,created_question_id uuid REFERENCES public.arena_questions(id),UNIQUE(batch_id,row_number)
);
CREATE INDEX arena_import_rows_batch ON public.arena_question_import_rows(batch_id,row_number);

CREATE TABLE public.arena_question_generation_jobs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,request_id uuid NOT NULL,
 cefr_level text NOT NULL CHECK(cefr_level IN ('A1','A2','B1','B2','C1')),topic text NOT NULL REFERENCES public.arena_topics(slug),
 kind text NOT NULL CHECK(kind IN ('multiple_choice','fill_blank','matching','grammar_correction','sentence_order','reading')),
 difficulty integer NOT NULL CHECK(difficulty BETWEEN 1 AND 3),requested_count integer NOT NULL CHECK(requested_count BETWEEN 1 AND 10),
 learning_objective text NOT NULL CHECK(char_length(btrim(learning_objective)) BETWEEN 3 AND 500),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','processing','pending_review','failed','quota_blocked')),
 provider_model text,error_kind text,created_at timestamptz NOT NULL DEFAULT now(),completed_at timestamptz,UNIQUE(created_by,request_id)
);

CREATE TABLE public.arena_question_reports (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),reporter_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 question_id uuid NOT NULL REFERENCES public.arena_questions(id) ON DELETE RESTRICT,revision_id uuid NOT NULL REFERENCES public.arena_question_revisions(id) ON DELETE RESTRICT,
 reason text NOT NULL CHECK(reason IN ('incorrect_answer','unclear','grammar_error','wrong_cefr','duplicate','other')),
 details text NOT NULL DEFAULT '' CHECK(char_length(details)<=1000),status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','resolved','dismissed')),
 resolved_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,resolution_note text NOT NULL DEFAULT '' CHECK(char_length(resolution_note)<=1000),
 created_at timestamptz NOT NULL DEFAULT now(),resolved_at timestamptz,UNIQUE(reporter_id,revision_id,reason)
);
CREATE INDEX arena_reports_admin ON public.arena_question_reports(status,created_at DESC,id);

DO $$ DECLARE t text; BEGIN FOREACH t IN ARRAY ARRAY['arena_topics','arena_question_revisions','arena_question_import_batches','arena_question_import_rows','arena_question_generation_jobs','arena_question_reports'] LOOP
 EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);EXECUTE format('REVOKE ALL ON public.%I FROM anon,authenticated',t);EXECUTE format('GRANT ALL ON public.%I TO service_role',t);END LOOP;END $$;
GRANT SELECT ON public.arena_topics TO authenticated;
GRANT SELECT ON public.arena_question_revisions,public.arena_question_import_batches,public.arena_question_import_rows,public.arena_question_generation_jobs,public.arena_question_reports TO authenticated;
CREATE POLICY arena_topic_read ON public.arena_topics FOR SELECT TO authenticated USING(status='published' OR public.englify_is_admin());
CREATE POLICY arena_revision_admin ON public.arena_question_revisions FOR SELECT TO authenticated USING(public.englify_is_admin());
CREATE POLICY arena_import_batch_admin ON public.arena_question_import_batches FOR SELECT TO authenticated USING(public.englify_is_admin());
CREATE POLICY arena_import_row_admin ON public.arena_question_import_rows FOR SELECT TO authenticated USING(public.englify_is_admin());
CREATE POLICY arena_generation_admin ON public.arena_question_generation_jobs FOR SELECT TO authenticated USING(public.englify_is_admin());
CREATE POLICY arena_report_owner_admin ON public.arena_question_reports FOR SELECT TO authenticated USING(reporter_id=auth.uid() OR public.englify_is_admin());

CREATE FUNCTION public.englify_arena_normalize_prompt(p_value text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT lower(regexp_replace(regexp_replace(btrim(coalesce(p_value,'')),'[^[:alnum:][:space:]]','','g'),'\s+',' ','g'))
$$;
CREATE FUNCTION public.englify_arena_validate_draft(p_data jsonb) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE e jsonb:='[]';kind text:=p_data->>'kind';answer jsonb:=p_data->'answer';items jsonb;BEGIN
 IF jsonb_typeof(p_data)<>'object' THEN RETURN '["Dữ liệu câu hỏi phải là object."]';END IF;
 IF coalesce(length(btrim(p_data->>'prompt')),0)=0 OR length(p_data->>'prompt')>2000 THEN e:=e||'"Prompt là bắt buộc và tối đa 2000 ký tự."';END IF;
 IF p_data->>'cefr_level' NOT IN ('A1','A2','B1','B2','C1') THEN e:=e||'"CEFR không hợp lệ."';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.arena_topics WHERE slug=p_data->>'topic' AND status='published') THEN e:=e||'"Topic không tồn tại hoặc đã lưu trữ."';END IF;
 IF kind NOT IN ('multiple_choice','fill_blank','matching','grammar_correction','sentence_order','reading') THEN e:=e||'"Loại câu hỏi không được hỗ trợ."';END IF;
 IF coalesce((p_data->>'difficulty')::integer,0) NOT BETWEEN 1 AND 3 THEN e:=e||'"Độ khó phải từ 1 đến 3."';END IF;
 IF coalesce(length(btrim(p_data->>'explanation_vi')),0)=0 OR length(p_data->>'explanation_vi')>3000 THEN e:=e||'"Giải thích tiếng Việt là bắt buộc và tối đa 3000 ký tự."';END IF;
 FOREACH items IN ARRAY ARRAY[coalesce(p_data->'options','[]'),coalesce(p_data->'left_items','[]'),coalesce(p_data->'right_items','[]')] LOOP
  IF jsonb_typeof(items)<>'array' OR EXISTS(SELECT 1 FROM jsonb_array_elements(items)v WHERE jsonb_typeof(v)<>'object' OR coalesce(v->>'id','')='' OR coalesce(btrim(v->>'text'),'')='')
   OR (SELECT count(*) FROM jsonb_array_elements(items))<>(SELECT count(DISTINCT v->>'id') FROM jsonb_array_elements(items)v) THEN e:=e||'"Các lựa chọn cần ID duy nhất và nội dung."';EXIT;END IF;
 END LOOP;
 IF kind IN ('multiple_choice','reading') AND (jsonb_typeof(answer)<>'string' OR jsonb_array_length(coalesce(p_data->'options','[]'))<2 OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_data->'options','[]'))o WHERE o->>'id'=answer#>>'{}')) THEN e:=e||'"Đáp án trắc nghiệm phải tham chiếu một lựa chọn hợp lệ."';END IF;
 IF kind='reading' AND coalesce(length(btrim(p_data->>'passage')),0)=0 THEN e:=e||'"Reading cần đoạn văn."';END IF;
 IF kind IN ('fill_blank','grammar_correction') AND (jsonb_typeof(answer)<>'array' OR jsonb_array_length(answer)=0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(answer)v WHERE jsonb_typeof(v)<>'string' OR btrim(v#>>'{}')='')) THEN e:=e||'"Cần ít nhất một đáp án văn bản hợp lệ."';END IF;
 IF kind='sentence_order' AND (jsonb_typeof(answer)<>'array' OR jsonb_array_length(answer)<2 OR jsonb_array_length(answer)<>jsonb_array_length(coalesce(p_data->'options','[]')) OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(answer)v WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_data->'options')o WHERE o->>'id'=v))) THEN e:=e||'"Thứ tự câu phải tham chiếu đầy đủ token."';END IF;
 IF kind='matching' AND (jsonb_typeof(answer)<>'object' OR jsonb_array_length(coalesce(p_data->'left_items','[]'))<2 OR jsonb_array_length(p_data->'left_items')<>jsonb_array_length(coalesce(p_data->'right_items','[]')) OR (SELECT count(*) FROM jsonb_object_keys(answer))<>jsonb_array_length(p_data->'left_items')) THEN e:=e||'"Matching cần ít nhất hai cặp và mapping đầy đủ."';END IF;
 RETURN e;EXCEPTION WHEN invalid_text_representation THEN RETURN e||'"Kiểu dữ liệu không hợp lệ."';END $$;

CREATE FUNCTION public.englify_admin_question_list(p_page integer DEFAULT 1,p_page_size integer DEFAULT 20,p_search text DEFAULT NULL,p_cefr text DEFAULT NULL,p_topic text DEFAULT NULL,p_kind text DEFAULT NULL,p_status text DEFAULT NULL,p_difficulty integer DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE items jsonb;total integer;BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';END IF;
 IF p_page<1 OR p_page_size NOT BETWEEN 1 AND 50 OR length(coalesce(p_search,''))>100 THEN RAISE EXCEPTION 'Invalid pagination or search' USING ERRCODE='22023';END IF;
 WITH f AS (SELECT q.* FROM public.arena_questions q WHERE (p_search IS NULL OR q.prompt ILIKE '%'||replace(replace(p_search,'%','\%'),'_','\_')||'%' OR q.slug ILIKE '%'||p_search||'%') AND (p_cefr IS NULL OR q.cefr_level=p_cefr) AND (p_topic IS NULL OR q.topic=p_topic) AND (p_kind IS NULL OR q.kind=p_kind) AND (p_status IS NULL OR q.status=p_status) AND (p_difficulty IS NULL OR q.difficulty=p_difficulty))
 SELECT count(*),coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY updated_at DESC,id) FROM (SELECT id,slug,prompt,kind,cefr_level,topic,difficulty,status,current_version,origin,updated_at FROM f ORDER BY updated_at DESC,id LIMIT p_page_size OFFSET(p_page-1)*p_page_size)x),'[]') INTO total,items FROM f;
 RETURN jsonb_build_object('items',items,'total',total,'page',p_page,'page_size',p_page_size);END $$;

CREATE FUNCTION public.englify_admin_question_detail(p_id uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE q public.arena_questions%ROWTYPE;k public.arena_answer_keys%ROWTYPE;BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';END IF;SELECT * INTO q FROM public.arena_questions WHERE id=p_id;IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Question not found';END IF;SELECT * INTO k FROM public.arena_answer_keys WHERE question_id=p_id;RETURN to_jsonb(q)||jsonb_build_object('answer',k.answer,'explanation_vi',k.explanation_vi,'revisions',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'version',version,'status',status,'change_note',change_note,'created_by',created_by,'created_at',created_at) ORDER BY version DESC),'[]') FROM public.arena_question_revisions WHERE question_id=q.id));END $$;

CREATE FUNCTION public.englify_admin_save_arena_question(p_request_id uuid,p_id uuid,p_data jsonb,p_change_note text DEFAULT '') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE q public.arena_questions%ROWTYPE;old jsonb;errors jsonb;new_id uuid:=coalesce(p_id,gen_random_uuid());new_version integer;norm text;BEGIN
 IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';END IF;IF p_request_id IS NULL THEN RAISE EXCEPTION 'Request ID required' USING ERRCODE='22023';END IF;
 PERFORM pg_advisory_xact_lock(hashtext(auth.uid()::text||p_request_id::text));SELECT * INTO q FROM public.arena_questions WHERE id=new_id FOR UPDATE;old:=CASE WHEN FOUND THEN public.englify_admin_question_detail(new_id) ELSE NULL END;
 errors:=public.englify_arena_validate_draft(p_data);IF jsonb_array_length(errors)>0 THEN RAISE EXCEPTION 'Question validation failed: %',errors::text USING ERRCODE='22023';END IF;norm:=public.englify_arena_normalize_prompt(p_data->>'prompt');new_version:=coalesce(q.current_version,0)+1;
 IF q.id IS NULL THEN INSERT INTO public.arena_questions(id,slug,cefr_level,topic,kind,difficulty,prompt,passage,options,left_items,right_items,status,is_published,current_version,normalized_prompt,origin,external_id,created_by,updated_by)
  VALUES(new_id,coalesce(nullif(p_data->>'slug',''),'arena-'||replace(gen_random_uuid()::text,'-','')),p_data->>'cefr_level',p_data->>'topic',p_data->>'kind',(p_data->>'difficulty')::integer,p_data->>'prompt',p_data->>'passage',coalesce(p_data->'options','[]'),coalesce(p_data->'left_items','[]'),coalesce(p_data->'right_items','[]'),'draft',false,new_version,norm,coalesce(nullif(p_data->>'origin',''),'editorial'),nullif(p_data->>'external_id',''),auth.uid(),auth.uid()) RETURNING * INTO q;
 ELSE UPDATE public.arena_questions SET cefr_level=p_data->>'cefr_level',topic=p_data->>'topic',kind=p_data->>'kind',difficulty=(p_data->>'difficulty')::integer,prompt=p_data->>'prompt',passage=p_data->>'passage',options=coalesce(p_data->'options','[]'),left_items=coalesce(p_data->'left_items','[]'),right_items=coalesce(p_data->'right_items','[]'),status='draft',is_published=false,archived_at=NULL,current_version=new_version,normalized_prompt=norm,external_id=coalesce(nullif(p_data->>'external_id',''),q.external_id),updated_by=auth.uid(),updated_at=clock_timestamp() WHERE id=new_id RETURNING * INTO q;END IF;
 INSERT INTO public.arena_answer_keys(question_id,answer,explanation_vi) VALUES(new_id,p_data->'answer',p_data->>'explanation_vi') ON CONFLICT(question_id) DO UPDATE SET answer=excluded.answer,explanation_vi=excluded.explanation_vi;
 INSERT INTO public.arena_question_revisions(question_id,version,content,answer,explanation_vi,status,change_note,created_by) VALUES(new_id,new_version,to_jsonb(q)-'created_by'-'updated_by',p_data->'answer',p_data->>'explanation_vi','draft',coalesce(p_change_note,''),auth.uid());
 INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data)VALUES(auth.uid(),CASE WHEN old IS NULL THEN 'create' ELSE 'update' END,'arena-question',new_id,old,public.englify_admin_question_detail(new_id));RETURN public.englify_admin_question_detail(new_id);END $$;

CREATE FUNCTION public.englify_admin_transition_arena_question(p_id uuid,p_status text,p_note text DEFAULT '') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE q public.arena_questions%ROWTYPE;k public.arena_answer_keys%ROWTYPE;data jsonb;errors jsonb;BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';END IF;IF p_status NOT IN ('draft','in_review','published','archived') THEN RAISE EXCEPTION 'Invalid status' USING ERRCODE='22023';END IF;SELECT * INTO q FROM public.arena_questions WHERE id=p_id FOR UPDATE;IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Question not found';END IF;SELECT * INTO k FROM public.arena_answer_keys WHERE question_id=p_id;data:=to_jsonb(q)||jsonb_build_object('answer',k.answer,'explanation_vi',k.explanation_vi);errors:=public.englify_arena_validate_draft(data);IF p_status IN ('in_review','published') AND jsonb_array_length(errors)>0 THEN RAISE EXCEPTION 'Question validation failed: %',errors::text USING ERRCODE='22023';END IF;
 IF p_status='published' AND q.status<>'in_review' THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Submit the question for review before publishing';END IF;
 UPDATE public.arena_questions SET status=p_status,is_published=(p_status='published'),archived_at=CASE WHEN p_status='archived' THEN clock_timestamp() ELSE NULL END,updated_by=auth.uid(),updated_at=clock_timestamp() WHERE id=p_id RETURNING * INTO q;
 UPDATE public.arena_question_revisions SET status=p_status WHERE question_id=p_id AND version=q.current_version;
 INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data)VALUES(auth.uid(),'transition:'||p_status,'arena-question',p_id,NULL,jsonb_build_object('status',p_status,'note',coalesce(p_note,''),'version',q.current_version));RETURN public.englify_admin_question_detail(p_id);END $$;

CREATE FUNCTION public.englify_admin_duplicate_arena_question(p_id uuid,p_request_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE d jsonb;BEGIN d:=public.englify_admin_question_detail(p_id);d:=d||jsonb_build_object('slug',NULL,'external_id',NULL,'origin','editorial');RETURN public.englify_admin_save_arena_question(p_request_id,NULL,d,'Duplicated from '||p_id);END $$;

CREATE FUNCTION public.englify_admin_stage_arena_import(p_request_id uuid,p_filename text,p_format text,p_rows jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE b public.arena_question_import_batches%ROWTYPE;r record;d jsonb;e jsonb;dup uuid;valid integer:=0;dups integer:=0;BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';END IF;IF p_request_id IS NULL OR p_format NOT IN ('csv','xlsx') OR jsonb_typeof(p_rows)<>'array' OR jsonb_array_length(p_rows) NOT BETWEEN 1 AND 500 OR length(p_filename)>180 THEN RAISE EXCEPTION 'Invalid import batch' USING ERRCODE='22023';END IF;SELECT * INTO b FROM public.arena_question_import_batches WHERE created_by=auth.uid() AND request_id=p_request_id;IF FOUND THEN RETURN jsonb_build_object('batch_id',b.id,'replayed',true);END IF;INSERT INTO public.arena_question_import_batches(created_by,request_id,filename,format,row_count)VALUES(auth.uid(),p_request_id,p_filename,p_format,jsonb_array_length(p_rows))RETURNING * INTO b;
 FOR r IN SELECT value,ordinality FROM jsonb_array_elements(p_rows) WITH ORDINALITY LOOP d:=r.value;e:=public.englify_arena_validate_draft(d);SELECT id INTO dup FROM public.arena_questions WHERE normalized_prompt=public.englify_arena_normalize_prompt(d->>'prompt') AND cefr_level=d->>'cefr_level' AND topic=d->>'topic' AND kind=d->>'kind' LIMIT 1;IF dup IS NOT NULL THEN dups:=dups+1;END IF;IF jsonb_array_length(e)=0 THEN valid:=valid+1;END IF;INSERT INTO public.arena_question_import_rows(batch_id,row_number,raw_data,normalized_data,validation_errors,duplicate_question_id,selected)VALUES(b.id,r.ordinality+1,r.value,d,e,dup,jsonb_array_length(e)=0 AND dup IS NULL);dup:=NULL;END LOOP;UPDATE public.arena_question_import_batches SET valid_count=valid,duplicate_count=dups WHERE id=b.id;RETURN jsonb_build_object('batch_id',b.id,'row_count',b.row_count,'valid_count',valid,'duplicate_count',dups,'rows',(SELECT jsonb_agg(to_jsonb(x) ORDER BY row_number) FROM public.arena_question_import_rows x WHERE batch_id=b.id));END $$;

CREATE FUNCTION public.englify_admin_commit_arena_import(p_batch uuid,p_row_ids uuid[],p_request_id uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE b public.arena_question_import_batches%ROWTYPE;r public.arena_question_import_rows%ROWTYPE;q jsonb;count_ok integer:=0;BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';END IF;SELECT * INTO b FROM public.arena_question_import_batches WHERE id=p_batch AND created_by=auth.uid() FOR UPDATE;IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Import batch not found';END IF;IF b.status='committed' THEN RETURN jsonb_build_object('batch_id',b.id,'imported',(SELECT count(*) FROM public.arena_question_import_rows WHERE batch_id=b.id AND created_question_id IS NOT NULL),'replayed',true);END IF;FOR r IN SELECT * FROM public.arena_question_import_rows WHERE batch_id=b.id AND id=ANY(p_row_ids) ORDER BY row_number LOOP IF jsonb_array_length(r.validation_errors)>0 OR (r.duplicate_question_id IS NOT NULL AND NOT r.selected) THEN CONTINUE;END IF;q:=public.englify_admin_save_arena_question(gen_random_uuid(),NULL,r.normalized_data,'Imported from '||b.filename||' row '||r.row_number);UPDATE public.arena_question_import_rows SET created_question_id=(q->>'id')::uuid WHERE id=r.id;count_ok:=count_ok+1;END LOOP;UPDATE public.arena_question_import_batches SET status='committed',committed_at=clock_timestamp() WHERE id=b.id;RETURN jsonb_build_object('batch_id',b.id,'imported',count_ok);END $$;

CREATE FUNCTION public.englify_admin_question_management_overview() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$ SELECT CASE WHEN public.englify_is_admin() THEN jsonb_build_object('total',(SELECT count(*) FROM public.arena_questions),'published',(SELECT count(*) FROM public.arena_questions WHERE status='published'),'drafts',(SELECT count(*) FROM public.arena_questions WHERE status='draft'),'pending_review',(SELECT count(*) FROM public.arena_questions WHERE status='in_review'),'reported',(SELECT count(*) FROM public.arena_question_reports WHERE status='open'),'topics',(SELECT coalesce(jsonb_agg(to_jsonb(t)||jsonb_build_object('question_count',(SELECT count(*) FROM public.arena_questions q WHERE q.topic=t.slug)) ORDER BY sort_order,slug),'[]') FROM public.arena_topics t),'generation_jobs',(SELECT coalesce(jsonb_agg(to_jsonb(j) ORDER BY created_at DESC),'[]') FROM (SELECT * FROM public.arena_question_generation_jobs ORDER BY created_at DESC LIMIT 20)j),'reports',(SELECT coalesce(jsonb_agg(to_jsonb(r)-'reporter_id' ORDER BY created_at DESC),'[]') FROM (SELECT * FROM public.arena_question_reports WHERE status='open' ORDER BY created_at DESC LIMIT 30)r)) ELSE NULL END $$;

CREATE FUNCTION public.englify_admin_question_analytics(p_question uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';END IF;RETURN jsonb_build_object('question_id',p_question,'attempts',(SELECT count(*) FROM public.quiz_answer_facts WHERE question_source='arena' AND question_id=p_question),'correct',(SELECT count(*) FROM public.quiz_answer_facts WHERE question_source='arena' AND question_id=p_question AND is_correct),'incorrect',(SELECT count(*) FROM public.quiz_answer_facts WHERE question_source='arena' AND question_id=p_question AND NOT is_correct),'accuracy',(SELECT CASE WHEN count(*)=0 THEN NULL ELSE round(count(*)FILTER(WHERE is_correct)*100.0/count(*),1) END FROM public.quiz_answer_facts WHERE question_source='arena' AND question_id=p_question),'by_mode',(SELECT coalesce(jsonb_object_agg(source_mode,total),'{}') FROM (SELECT source_mode,count(*) total FROM public.quiz_answer_facts WHERE question_source='arena' AND question_id=p_question GROUP BY source_mode)x),'open_reports',(SELECT count(*) FROM public.arena_question_reports WHERE question_id=p_question AND status='open'));END $$;

CREATE FUNCTION public.englify_report_arena_question(p_question uuid,p_reason text,p_details text DEFAULT '') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE q public.arena_questions%ROWTYPE;rev uuid;r public.arena_question_reports%ROWTYPE;BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';END IF;SELECT * INTO q FROM public.arena_questions WHERE id=p_question AND status='published';IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Published question not found';END IF;SELECT id INTO rev FROM public.arena_question_revisions WHERE question_id=q.id AND version=q.current_version;IF rev IS NULL THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Question revision unavailable';END IF;INSERT INTO public.arena_question_reports(reporter_id,question_id,revision_id,reason,details)VALUES(auth.uid(),q.id,rev,p_reason,coalesce(p_details,''))ON CONFLICT(reporter_id,revision_id,reason)DO UPDATE SET details=excluded.details RETURNING * INTO r;RETURN to_jsonb(r)-'reporter_id';END $$;

CREATE FUNCTION public.englify_admin_resolve_question_report(p_id uuid,p_status text,p_note text DEFAULT '') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ DECLARE r public.arena_question_reports%ROWTYPE;BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';END IF;IF p_status NOT IN ('resolved','dismissed') THEN RAISE EXCEPTION 'Invalid report resolution' USING ERRCODE='22023';END IF;UPDATE public.arena_question_reports SET status=p_status,resolved_by=auth.uid(),resolution_note=coalesce(p_note,''),resolved_at=clock_timestamp() WHERE id=p_id RETURNING * INTO r;IF NOT FOUND THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Report not found';END IF;INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,after_data)VALUES(auth.uid(),'resolve:'||p_status,'arena-question-report',r.id,to_jsonb(r)-'reporter_id');RETURN to_jsonb(r)-'reporter_id';END $$;

-- Backfill an immutable revision for every existing Arena question.
INSERT INTO public.arena_question_revisions(question_id,version,content,answer,explanation_vi,status,change_note)
SELECT q.id,1,to_jsonb(q)-'created_by'-'updated_by',k.answer,k.explanation_vi,q.status,'Backfilled from V2.1–V2.4' FROM public.arena_questions q JOIN public.arena_answer_keys k ON k.question_id=q.id ON CONFLICT DO NOTHING;

REVOKE ALL ON FUNCTION public.englify_arena_normalize_prompt(text),public.englify_arena_validate_draft(jsonb),public.englify_admin_question_list(integer,integer,text,text,text,text,text,integer),public.englify_admin_question_detail(uuid),public.englify_admin_save_arena_question(uuid,uuid,jsonb,text),public.englify_admin_transition_arena_question(uuid,text,text),public.englify_admin_duplicate_arena_question(uuid,uuid),public.englify_admin_stage_arena_import(uuid,text,text,jsonb),public.englify_admin_commit_arena_import(uuid,uuid[],uuid),public.englify_admin_question_management_overview(),public.englify_admin_question_analytics(uuid),public.englify_report_arena_question(uuid,text,text),public.englify_admin_resolve_question_report(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_admin_question_list(integer,integer,text,text,text,text,text,integer),public.englify_admin_question_detail(uuid),public.englify_admin_save_arena_question(uuid,uuid,jsonb,text),public.englify_admin_transition_arena_question(uuid,text,text),public.englify_admin_duplicate_arena_question(uuid,uuid),public.englify_admin_stage_arena_import(uuid,text,text,jsonb),public.englify_admin_commit_arena_import(uuid,uuid[],uuid),public.englify_admin_question_management_overview(),public.englify_admin_question_analytics(uuid),public.englify_admin_resolve_question_report(uuid,text,text),public.englify_report_arena_question(uuid,text,text) TO authenticated;
