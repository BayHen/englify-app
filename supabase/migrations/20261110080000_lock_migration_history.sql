-- Alembic metadata is not an application API. Supabase's public schema default
-- grants otherwise make this unprotected table writable by every client.
REVOKE ALL PRIVILEGES ON TABLE public.alembic_version FROM PUBLIC, anon, authenticated;
ALTER TABLE public.alembic_version ENABLE ROW LEVEL SECURITY;
