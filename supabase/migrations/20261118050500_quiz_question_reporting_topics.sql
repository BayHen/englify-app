-- Attach learner reports to the exact immutable revision snapshotted by a session.
ALTER TABLE public.arena_session_questions ADD COLUMN revision_id uuid REFERENCES public.arena_question_revisions(id) ON DELETE RESTRICT;
UPDATE public.arena_session_questions s SET revision_id=r.id FROM public.arena_questions q JOIN public.arena_question_revisions r ON r.question_id=q.id AND r.version=q.current_version WHERE q.id=s.question_id AND s.revision_id IS NULL;
CREATE FUNCTION public.englify_arena_snapshot_revision() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN IF NEW.revision_id IS NULL THEN SELECT r.id INTO NEW.revision_id FROM public.arena_questions q JOIN public.arena_question_revisions r ON r.question_id=q.id AND r.version=q.current_version WHERE q.id=NEW.question_id;END IF;RETURN NEW;END $$;
CREATE TRIGGER arena_snapshot_revision BEFORE INSERT ON public.arena_session_questions FOR EACH ROW EXECUTE FUNCTION public.englify_arena_snapshot_revision();
REVOKE ALL ON FUNCTION public.englify_arena_snapshot_revision() FROM PUBLIC,anon,authenticated;

DROP FUNCTION public.englify_report_arena_question(uuid,text,text);
CREATE FUNCTION public.englify_report_arena_question(p_session uuid,p_question uuid,p_reason text,p_details text DEFAULT '') RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE rev uuid;r public.arena_question_reports%ROWTYPE;BEGIN IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='28000';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.arena_sessions WHERE id=p_session AND user_id=auth.uid()) THEN RAISE SQLSTATE 'PT404' USING MESSAGE='Arena session not found';END IF;
 SELECT revision_id INTO rev FROM public.arena_session_questions WHERE session_id=p_session AND question_id=p_question;IF rev IS NULL THEN RAISE SQLSTATE 'PT409' USING MESSAGE='Question revision unavailable';END IF;
 INSERT INTO public.arena_question_reports(reporter_id,question_id,revision_id,reason,details)VALUES(auth.uid(),p_question,rev,p_reason,coalesce(p_details,''))ON CONFLICT(reporter_id,revision_id,reason)DO UPDATE SET details=excluded.details RETURNING * INTO r;RETURN to_jsonb(r)-'reporter_id';END $$;
REVOKE ALL ON FUNCTION public.englify_report_arena_question(uuid,uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_report_arena_question(uuid,uuid,text,text) TO authenticated;

CREATE FUNCTION public.englify_admin_upsert_arena_topic(p_slug text,p_title text,p_description text,p_sort_order integer,p_status text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE t public.arena_topics%ROWTYPE;old jsonb;BEGIN IF NOT public.englify_is_admin() THEN RAISE EXCEPTION 'Administrator access required' USING ERRCODE='42501';END IF;SELECT to_jsonb(x) INTO old FROM public.arena_topics x WHERE slug=p_slug;INSERT INTO public.arena_topics(slug,title,description,sort_order,status)VALUES(p_slug,p_title,coalesce(p_description,''),p_sort_order,p_status)ON CONFLICT(slug)DO UPDATE SET title=excluded.title,description=excluded.description,sort_order=excluded.sort_order,status=excluded.status,updated_at=clock_timestamp()RETURNING * INTO t;INSERT INTO public.admin_audit_logs(actor_id,action,resource,record_id,before_data,after_data)VALUES(auth.uid(),CASE WHEN old IS NULL THEN 'create' ELSE 'update' END,'arena-topic',NULL,old,to_jsonb(t));RETURN to_jsonb(t)||jsonb_build_object('question_count',(SELECT count(*) FROM public.arena_questions WHERE topic=t.slug));END $$;
REVOKE ALL ON FUNCTION public.englify_admin_upsert_arena_topic(text,text,text,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.englify_admin_upsert_arena_topic(text,text,text,integer,text) TO authenticated;
