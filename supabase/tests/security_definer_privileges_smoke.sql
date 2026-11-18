-- Run only against a disposable database after every migration is applied.
BEGIN;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef
      AND EXISTS (
        SELECT 1
        FROM pg_catalog.aclexplode(coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))) AS privilege
        WHERE privilege.grantee = 0 AND privilege.privilege_type = 'EXECUTE'
      )
  ) THEN
    RAISE EXCEPTION 'PUBLIC can execute a SECURITY DEFINER function';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef
      AND NOT EXISTS (
        SELECT 1 FROM pg_catalog.unnest(coalesce(p.proconfig, ARRAY[]::text[])) AS setting
        WHERE setting IN ('search_path=', 'search_path=""')
      )
  ) THEN
    RAISE EXCEPTION 'SECURITY DEFINER function is missing an empty search_path';
  END IF;
  IF pg_catalog.has_table_privilege('anon', 'public.admin_mutation_requests', 'SELECT')
    OR pg_catalog.has_table_privilege('authenticated', 'public.admin_mutation_requests', 'SELECT')
    OR pg_catalog.has_table_privilege('authenticated', 'public.admin_mutation_requests', 'INSERT') THEN
    RAISE EXCEPTION 'Admin idempotency records are exposed to clients';
  END IF;
  IF pg_catalog.has_table_privilege('authenticated', 'public.xp_events', 'INSERT')
    OR pg_catalog.has_table_privilege('authenticated', 'public.xp_events', 'UPDATE')
    OR pg_catalog.has_table_privilege('authenticated', 'public.xp_events', 'DELETE') THEN
    RAISE EXCEPTION 'Learners can mutate XP directly';
  END IF;
  IF pg_catalog.has_table_privilege('authenticated', 'public.writing_daily_assignments', 'INSERT')
    OR pg_catalog.has_table_privilege('authenticated', 'public.writing_daily_assignments', 'UPDATE')
    OR pg_catalog.has_table_privilege('authenticated', 'public.writing_daily_completions', 'INSERT')
    OR pg_catalog.has_table_privilege('authenticated', 'public.writing_daily_completions', 'UPDATE')
    OR pg_catalog.has_table_privilege('authenticated', 'public.writing_daily_completions', 'DELETE') THEN
    RAISE EXCEPTION 'Daily Writing assignment or completion ledger is client-mutable';
  END IF;
  IF pg_catalog.has_table_privilege('authenticated', 'public.writing_ai_feedback', 'INSERT')
    OR pg_catalog.has_table_privilege('authenticated', 'public.writing_ai_feedback', 'UPDATE')
    OR pg_catalog.has_table_privilege('authenticated', 'public.writing_ai_rewrites', 'INSERT')
    OR pg_catalog.has_table_privilege('authenticated', 'public.writing_ai_usage', 'SELECT')
    OR pg_catalog.has_table_privilege('authenticated', 'public.writing_revisions', 'INSERT') THEN
    RAISE EXCEPTION 'Writing AI server-owned data is mutable or exposed to learners';
  END IF;
  IF pg_catalog.has_table_privilege('anon', 'public.quiz_answer_keys', 'SELECT')
    OR pg_catalog.has_table_privilege('anon', 'public.writing_answer_keys', 'SELECT') THEN
    RAISE EXCEPTION 'Anonymous users can read private answer keys';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS c
    JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN ('quiz_answer_keys', 'writing_answer_keys')
      AND NOT c.relrowsecurity
  ) THEN
    RAISE EXCEPTION 'Private answer key table is missing RLS';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_policies AS policy
    WHERE policy.schemaname = 'public'
      AND policy.tablename IN ('quiz_answer_keys', 'writing_answer_keys')
      AND 'authenticated'::name = ANY(policy.roles)
      AND pg_catalog.strpos(coalesce(policy.qual, ''), 'englify_is_admin') = 0
  ) OR EXISTS (
    SELECT table_name
    FROM (VALUES ('quiz_answer_keys'), ('writing_answer_keys')) AS private_table(table_name)
    WHERE NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_policies AS policy
      WHERE policy.schemaname = 'public'
        AND policy.tablename = private_table.table_name
        AND 'authenticated'::name = ANY(policy.roles)
        AND pg_catalog.strpos(coalesce(policy.qual, ''), 'englify_is_admin') > 0
    )
  ) THEN
    RAISE EXCEPTION 'Private answer key policy is broader than Admin-only access';
  END IF;
END;
$$;

ROLLBACK;
