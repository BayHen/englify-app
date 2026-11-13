-- Disposable PostgreSQL only: compile the Cron selection without pg_cron/pg_net.
CREATE SCHEMA vault;
CREATE TABLE vault.decrypted_secrets(name text PRIMARY KEY,decrypted_secret text);
INSERT INTO vault.decrypted_secrets VALUES
  ('real_english_generate_url','https://example.supabase.co/functions/v1/real-english-generate'),
  ('real_english_cron_anon_jwt',repeat('a',100)),
  ('real_english_cron_secret',repeat('b',40));
CREATE SCHEMA net;
CREATE FUNCTION net.http_post(url text,headers jsonb,body jsonb,timeout_milliseconds integer)
RETURNS bigint LANGUAGE sql AS $$ SELECT 1::bigint $$;
