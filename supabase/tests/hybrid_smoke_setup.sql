-- Run ONLY on a new disposable PostgreSQL database; never on Supabase/live data.
-- Minimal Auth/admin stubs validate migration SQL and policy behavior, not full Supabase integration.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true),'')::uuid
$$;
CREATE TABLE public.admin_members (user_id uuid PRIMARY KEY REFERENCES auth.users(id));
CREATE FUNCTION public.englify_is_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS(SELECT 1 FROM public.admin_members WHERE user_id=auth.uid())
$$;
CREATE SCHEMA extensions;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
\i supabase/migrations/20261111010000_real_english_hybrid_foundation.sql
