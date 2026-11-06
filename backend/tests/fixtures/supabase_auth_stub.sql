-- Test-only stand-in for the Supabase-managed Auth schema, in a disposable DB.
-- Never apply this file to a Supabase project or production database.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY, raw_user_meta_data jsonb NOT NULL DEFAULT '{}'::jsonb);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
CREATE ROLE rls_tester LOGIN;
GRANT authenticated, anon TO rls_tester;
GRANT CONNECT ON DATABASE englify_test TO rls_tester;
GRANT USAGE ON SCHEMA public TO rls_tester;
