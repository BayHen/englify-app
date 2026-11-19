-- Review selections/events belong to the learner and must not block account deletion.
ALTER TABLE public.quiz_review_session_items DROP CONSTRAINT quiz_review_session_items_progress_id_fkey;
ALTER TABLE public.quiz_review_session_items ADD CONSTRAINT quiz_review_session_items_progress_id_fkey
 FOREIGN KEY(progress_id) REFERENCES public.quiz_mistake_progress(id) ON DELETE CASCADE;
ALTER TABLE public.quiz_review_events DROP CONSTRAINT quiz_review_events_progress_id_fkey;
ALTER TABLE public.quiz_review_events ADD CONSTRAINT quiz_review_events_progress_id_fkey
 FOREIGN KEY(progress_id) REFERENCES public.quiz_mistake_progress(id) ON DELETE CASCADE;
