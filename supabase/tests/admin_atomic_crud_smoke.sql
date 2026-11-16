-- Run only against a disposable Supabase database after db reset.
-- Every row and test-only trigger is rolled back.
BEGIN;

INSERT INTO auth.users(id) VALUES
  ('81111111-1111-4111-8111-111111111111'),
  ('82222222-2222-4222-8222-222222222222');
INSERT INTO public.admin_members(user_id)
VALUES ('81111111-1111-4111-8111-111111111111');

INSERT INTO public.lessons(id, course_id, unit_id, slug, title, objective, position)
SELECT '83333333-3333-4333-8333-333333333333', u.course_id, u.id,
       'atomic-admin-smoke', 'Atomic Admin Smoke', 'Transaction safety', 999
FROM public.learning_units AS u
ORDER BY u.created_at
LIMIT 1;

CREATE FUNCTION public.englify_test_reject_answer()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.answer = '["force-rollback"]'::jsonb THEN
    RAISE EXCEPTION 'forced dependent write failure';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER englify_test_reject_answer
BEFORE INSERT OR UPDATE ON public.quiz_answer_keys
FOR EACH ROW EXECUTE FUNCTION public.englify_test_reject_answer();

SELECT set_config('request.jwt.claim.sub', '82222222-2222-4222-8222-222222222222', true);
SET LOCAL ROLE authenticated;
DO $$
BEGIN
  BEGIN
    PERFORM public.englify_admin_upsert_badge(
      '84444444-4444-4444-8444-444444444444',
      '85555555-5555-4555-8555-555555555555',
      '{"code":"blocked-badge","title":"Blocked","metric":"total_xp","target":10}'::jsonb
    );
    RAISE EXCEPTION 'learner called an Admin mutation RPC';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END;
$$;

SELECT set_config('request.jwt.claim.sub', '81111111-1111-4111-8111-111111111111', true);

DO $$
DECLARE
  v_first jsonb;
  v_retry jsonb;
BEGIN
  v_first := public.englify_admin_upsert_badge(
    '86666666-6666-4666-8666-666666666666',
    '87777777-7777-4777-8777-777777777777',
    '{"code":"atomic-badge","title":"Atomic Badge","description":"Smoke test","metric":"total_xp","target":25}'::jsonb
  );
  v_retry := public.englify_admin_upsert_badge(
    '86666666-6666-4666-8666-666666666666',
    '88888888-8888-4888-8888-888888888888',
    '{"code":"must-not-exist","title":"Duplicate","metric":"total_xp","target":50}'::jsonb
  );
  IF v_first <> v_retry THEN
    RAISE EXCEPTION 'idempotent retry returned a different response';
  END IF;
  IF (SELECT count(*) FROM public.badges WHERE id = '87777777-7777-4777-8777-777777777777') <> 1
    OR EXISTS (SELECT 1 FROM public.badges WHERE id = '88888888-8888-4888-8888-888888888888')
    OR (SELECT count(*) FROM public.badge_rules WHERE badge_id = '87777777-7777-4777-8777-777777777777') <> 1 THEN
    RAISE EXCEPTION 'badge retry created inconsistent dependent rows';
  END IF;
END;
$$;

DO $$
DECLARE
  v_failed boolean := false;
BEGIN
  BEGIN
    PERFORM public.englify_admin_upsert_quiz_question(
      '89999999-9999-4999-8999-999999999999',
      '8aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      jsonb_build_object(
        'lesson_id', '83333333-3333-4333-8333-333333333333',
        'position', 1,
        'kind', 'fill_blank',
        'prompt', 'This write must roll back.',
        'payload', '{}'::jsonb,
        'answer', '["force-rollback"]'::jsonb
      )
    );
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'forced dependent write failure' THEN
      RAISE;
    END IF;
    v_failed := true;
  END;
  IF NOT v_failed THEN
    RAISE EXCEPTION 'forced dependent write unexpectedly succeeded';
  END IF;
END;
$$;

RESET ROLE;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.quiz_questions WHERE id = '8aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
    OR EXISTS (SELECT 1 FROM public.quiz_answer_keys WHERE question_id = '8aaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
    OR EXISTS (SELECT 1 FROM public.admin_mutation_requests WHERE request_id = '89999999-9999-4999-8999-999999999999') THEN
    RAISE EXCEPTION 'failed dependent write left partial data';
  END IF;
END;
$$;
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_first jsonb;
  v_retry jsonb;
BEGIN
  v_first := public.englify_admin_upsert_quiz_question(
    '8bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    '8ccccccc-cccc-4ccc-8ccc-cccccccccccc',
    jsonb_build_object(
      'lesson_id', '83333333-3333-4333-8333-333333333333',
      'position', 1,
      'kind', 'fill_blank',
      'prompt', 'Complete the sentence.',
      'explanation', 'Use the expected word.',
      'payload', '{}'::jsonb,
      'answer', '["answer"]'::jsonb
    )
  );
  v_retry := public.englify_admin_upsert_quiz_question(
    '8bbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    '8ddddddd-dddd-4ddd-8ddd-dddddddddddd',
    jsonb_build_object(
      'lesson_id', '83333333-3333-4333-8333-333333333333',
      'position', 2,
      'kind', 'fill_blank',
      'prompt', 'Duplicate request.',
      'payload', '{}'::jsonb,
      'answer', '["duplicate"]'::jsonb
    )
  );
  IF v_first <> v_retry
    OR (SELECT count(*) FROM public.quiz_questions WHERE id = '8ccccccc-cccc-4ccc-8ccc-cccccccccccc') <> 1
    OR (SELECT count(*) FROM public.quiz_answer_keys WHERE question_id = '8ccccccc-cccc-4ccc-8ccc-cccccccccccc') <> 1
    OR EXISTS (SELECT 1 FROM public.quiz_questions WHERE id = '8ddddddd-dddd-4ddd-8ddd-dddddddddddd') THEN
    RAISE EXCEPTION 'quiz retry was not idempotent';
  END IF;
END;
$$;

RESET ROLE;
ROLLBACK;
