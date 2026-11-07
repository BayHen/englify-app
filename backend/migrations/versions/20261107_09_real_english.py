"""Original Real English content, saves, and context quiz attempts."""
# ruff: noqa: E501 -- SQL kept intact for schema review.

from alembic import op

revision = "20261107_09"
down_revision = "20261107_08"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE TABLE public.real_english_expressions (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          slug text NOT NULL UNIQUE,
          kind text NOT NULL CHECK (kind IN ('slang','idiom','phrasal_verb','casual_expression','everyday_conversation','movie_style_dialogue')),
          expression text NOT NULL,
          meaning_vi text NOT NULL,
          context_explanation text NOT NULL,
          example_en text NOT NULL,
          example_vi text NOT NULL,
          dialogue jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(dialogue) = 'array'),
          formality text NOT NULL CHECK (formality IN ('informal','neutral','formal')),
          region_note text NOT NULL,
          source_name text NOT NULL,
          license_id text NOT NULL,
          provenance_note text NOT NULL,
          is_published boolean NOT NULL DEFAULT false,
          created_at timestamptz NOT NULL DEFAULT now(),
          updated_at timestamptz NOT NULL DEFAULT now()
        )
    """)
    op.execute(
        "CREATE INDEX real_english_kind_idx ON public.real_english_expressions(kind, expression) WHERE is_published"
    )
    op.execute(
        "CREATE INDEX real_english_search_idx ON public.real_english_expressions USING gin (to_tsvector('simple', expression || ' ' || meaning_vi)) WHERE is_published"
    )
    op.execute("""
        CREATE TABLE public.real_english_quiz_questions (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          expression_id uuid NOT NULL REFERENCES public.real_english_expressions(id) ON DELETE CASCADE,
          prompt text NOT NULL,
          options jsonb NOT NULL CHECK (jsonb_typeof(options) = 'array'),
          answer_id text NOT NULL,
          explanation text NOT NULL,
          created_at timestamptz NOT NULL DEFAULT now(),
          UNIQUE (expression_id)
        )
    """)
    op.execute("""
        CREATE TABLE public.saved_expressions (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
          expression_id uuid NOT NULL REFERENCES public.real_english_expressions(id) ON DELETE CASCADE,
          created_at timestamptz NOT NULL DEFAULT now(),
          UNIQUE (user_id, expression_id)
        )
    """)
    op.execute(
        "CREATE INDEX saved_expressions_user_recent_idx ON public.saved_expressions(user_id, created_at DESC)"
    )
    op.execute("""
        CREATE TABLE public.real_english_quiz_attempts (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
          question_id uuid NOT NULL REFERENCES public.real_english_quiz_questions(id) ON DELETE CASCADE,
          request_id uuid NOT NULL,
          selected_option text NOT NULL,
          is_correct boolean NOT NULL,
          created_at timestamptz NOT NULL DEFAULT now(),
          UNIQUE (user_id, request_id)
        )
    """)
    op.execute(
        "CREATE INDEX real_english_attempts_user_recent_idx ON public.real_english_quiz_attempts(user_id, created_at DESC)"
    )
    for table in (
        "real_english_expressions",
        "real_english_quiz_questions",
        "saved_expressions",
        "real_english_quiz_attempts",
    ):
        op.execute(f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY")
    op.execute("GRANT SELECT ON public.real_english_expressions TO authenticated")
    op.execute(
        "CREATE POLICY real_english_published_read ON public.real_english_expressions FOR SELECT TO authenticated USING (is_published)"
    )
    # Quiz answer_id is in the question row, so no direct client grant.
    op.execute(
        "GRANT SELECT ON public.saved_expressions, public.real_english_quiz_attempts TO authenticated"
    )
    op.execute(
        "CREATE POLICY saved_expressions_own_read ON public.saved_expressions FOR SELECT TO authenticated USING ((select auth.uid()) = user_id)"
    )
    op.execute(
        "CREATE POLICY real_english_attempts_own_read ON public.real_english_quiz_attempts FOR SELECT TO authenticated USING ((select auth.uid()) = user_id)"
    )


def downgrade() -> None:
    op.execute("DROP TABLE public.real_english_quiz_attempts")
    op.execute("DROP TABLE public.saved_expressions")
    op.execute("DROP TABLE public.real_english_quiz_questions")
    op.execute("DROP TABLE public.real_english_expressions")
