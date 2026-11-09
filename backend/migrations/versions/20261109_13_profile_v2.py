"""Add editable profile details and learning preferences without touching history."""
# ruff: noqa: E501 -- SQL policies are easier to audit as complete statements.

from alembic import op

revision = "20261109_13"
down_revision = "20261107_12"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE public.profiles ADD COLUMN username text")
    op.execute("ALTER TABLE public.profiles ADD COLUMN bio text")
    op.execute("ALTER TABLE public.profiles ADD CONSTRAINT profiles_username_format CHECK (username IS NULL OR username ~ '^[a-z0-9_]{3,30}$')")
    op.execute("ALTER TABLE public.profiles ADD CONSTRAINT profiles_bio_length CHECK (bio IS NULL OR char_length(bio) <= 160)")
    op.execute("CREATE UNIQUE INDEX profiles_username_ci_unique ON public.profiles (lower(username)) WHERE username IS NOT NULL")
    op.execute("ALTER TABLE public.user_preferences ADD COLUMN current_cefr text")
    op.execute("ALTER TABLE public.user_preferences ADD COLUMN preferred_accent text NOT NULL DEFAULT 'en-US'")
    op.execute("ALTER TABLE public.user_preferences ADD COLUMN interface_language text NOT NULL DEFAULT 'en'")
    op.execute("ALTER TABLE public.user_preferences DROP CONSTRAINT ck_preferences_learning_goal")
    op.execute("ALTER TABLE public.user_preferences ADD CONSTRAINT ck_preferences_learning_goal CHECK (learning_goal IS NULL OR learning_goal IN ('conversation', 'travel', 'work', 'exams', 'real_english'))")
    op.execute("ALTER TABLE public.user_preferences ADD CONSTRAINT preferences_cefr_check CHECK (current_cefr IS NULL OR current_cefr IN ('A1','A2','B1','B2','C1','C2'))")
    op.execute("ALTER TABLE public.user_preferences ADD CONSTRAINT preferences_accent_check CHECK (preferred_accent IN ('en-US','en-GB','en-AU'))")
    op.execute("ALTER TABLE public.user_preferences ADD CONSTRAINT preferences_interface_check CHECK (interface_language IN ('en','vi'))")
    op.execute("GRANT UPDATE (username, bio) ON public.profiles TO authenticated")
    op.execute("GRANT UPDATE (current_cefr, preferred_accent, interface_language) ON public.user_preferences TO authenticated")
    op.execute("""
        DO $$ BEGIN
          IF to_regclass('storage.buckets') IS NOT NULL AND to_regclass('storage.objects') IS NOT NULL THEN
            INSERT INTO storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
            VALUES ('avatars', 'avatars', false, 2097152, ARRAY['image/jpeg'])
            ON CONFLICT (id) DO NOTHING;
            IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='englify_avatar_read_own') THEN
              EXECUTE 'CREATE POLICY englify_avatar_read_own ON storage.objects FOR SELECT TO authenticated USING (bucket_id = ''avatars'' AND (storage.foldername(name))[1] = (select auth.uid())::text)';
            END IF;
            IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='englify_avatar_insert_own') THEN
              EXECUTE 'CREATE POLICY englify_avatar_insert_own ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = ''avatars'' AND (storage.foldername(name))[1] = (select auth.uid())::text AND storage.extension(name) = ''jpg'')';
            END IF;
            IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='englify_avatar_delete_own') THEN
              EXECUTE 'CREATE POLICY englify_avatar_delete_own ON storage.objects FOR DELETE TO authenticated USING (bucket_id = ''avatars'' AND (storage.foldername(name))[1] = (select auth.uid())::text)';
            END IF;
          END IF;
        END $$
    """)


def downgrade() -> None:
    from sqlalchemy import text

    bind = op.get_bind()
    if bind.execute(text("""
        SELECT EXISTS (SELECT 1 FROM public.profiles WHERE username IS NOT NULL OR bio IS NOT NULL)
            OR EXISTS (SELECT 1 FROM public.user_preferences
                       WHERE current_cefr IS NOT NULL OR learning_goal = 'real_english'
                          OR preferred_accent <> 'en-US' OR interface_language <> 'en')
    """)).scalar_one():
        raise RuntimeError("Cannot downgrade Profile V2 while user settings exist")
    op.execute("""
        DO $$ BEGIN
          IF to_regclass('storage.objects') IS NOT NULL THEN
            EXECUTE 'DROP POLICY IF EXISTS englify_avatar_delete_own ON storage.objects';
            EXECUTE 'DROP POLICY IF EXISTS englify_avatar_insert_own ON storage.objects';
            EXECUTE 'DROP POLICY IF EXISTS englify_avatar_read_own ON storage.objects';
          END IF;
        END $$
    """)
    op.execute("ALTER TABLE public.user_preferences DROP CONSTRAINT ck_preferences_learning_goal")
    op.execute("ALTER TABLE public.user_preferences ADD CONSTRAINT ck_preferences_learning_goal CHECK (learning_goal IS NULL OR learning_goal IN ('conversation', 'travel', 'work', 'exams'))")
    op.execute("REVOKE UPDATE (current_cefr, preferred_accent, interface_language) ON public.user_preferences FROM authenticated")
    op.execute("REVOKE UPDATE (username, bio) ON public.profiles FROM authenticated")
    op.execute("ALTER TABLE public.user_preferences DROP COLUMN interface_language")
    op.execute("ALTER TABLE public.user_preferences DROP COLUMN preferred_accent")
    op.execute("ALTER TABLE public.user_preferences DROP COLUMN current_cefr")
    op.execute("DROP INDEX public.profiles_username_ci_unique")
    op.execute("ALTER TABLE public.profiles DROP CONSTRAINT profiles_bio_length")
    op.execute("ALTER TABLE public.profiles DROP CONSTRAINT profiles_username_format")
    op.execute("ALTER TABLE public.profiles DROP COLUMN bio")
    op.execute("ALTER TABLE public.profiles DROP COLUMN username")
