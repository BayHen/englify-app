"""Structured writing exercises and separately stored feedback."""
# ruff: noqa: E501 -- SQL kept intact for review.

from alembic import op

revision = "20261107_10"
down_revision = "20261107_09"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE TABLE public.writing_exercises (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          slug text NOT NULL UNIQUE,
          kind text NOT NULL CHECK (kind IN ('sentence','fill_blank','sentence_order','paragraph')),
          prompt text NOT NULL,
          hint text NOT NULL DEFAULT '',
          tokens jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(tokens) = 'array'),
          is_published boolean NOT NULL DEFAULT false,
          created_at timestamptz NOT NULL DEFAULT now(),
          updated_at timestamptz NOT NULL DEFAULT now()
        )
    """)
    op.execute(
        "CREATE INDEX writing_exercises_published_kind_idx ON public.writing_exercises(kind) WHERE is_published"
    )
    op.execute("""
        CREATE TABLE public.writing_answer_keys (
          exercise_id uuid PRIMARY KEY REFERENCES public.writing_exercises(id) ON DELETE CASCADE,
          accepted_answers jsonb NOT NULL CHECK (jsonb_typeof(accepted_answers) = 'array')
        )
    """)
    op.execute(
        "ALTER TABLE public.writing_submissions ADD COLUMN exercise_id uuid REFERENCES public.writing_exercises(id) ON DELETE SET NULL"
    )
    op.execute("ALTER TABLE public.writing_submissions ADD COLUMN request_id uuid")
    op.execute(
        "CREATE UNIQUE INDEX writing_submissions_user_request_idx ON public.writing_submissions(user_id, request_id) WHERE request_id IS NOT NULL"
    )
    op.execute("""
        CREATE TABLE public.writing_feedback (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          submission_id uuid NOT NULL UNIQUE REFERENCES public.writing_submissions(id) ON DELETE CASCADE,
          rule_result text NOT NULL CHECK (rule_result IN ('matched','needs_revision','self_review')),
          suggestions jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(suggestions) = 'array'),
          grammar_status text NOT NULL CHECK (grammar_status IN ('not_requested','available','unavailable')),
          grammar_matches jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(grammar_matches) = 'array'),
          created_at timestamptz NOT NULL DEFAULT now()
        )
    """)
    op.execute("ALTER TABLE public.writing_exercises ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE public.writing_answer_keys ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE public.writing_feedback ENABLE ROW LEVEL SECURITY")
    op.execute("GRANT SELECT ON public.writing_exercises, public.writing_feedback TO authenticated")
    op.execute(
        "CREATE POLICY writing_exercises_read ON public.writing_exercises FOR SELECT TO authenticated USING (is_published)"
    )
    op.execute(
        "CREATE POLICY writing_feedback_own_read ON public.writing_feedback FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.writing_submissions s WHERE s.id = submission_id AND s.user_id = (select auth.uid())))"
    )


def downgrade() -> None:
    op.execute("DROP TABLE public.writing_feedback")
    op.execute("DROP INDEX public.writing_submissions_user_request_idx")
    op.execute("ALTER TABLE public.writing_submissions DROP COLUMN request_id")
    op.execute("ALTER TABLE public.writing_submissions DROP COLUMN exercise_id")
    op.execute("DROP TABLE public.writing_answer_keys")
    op.execute("DROP TABLE public.writing_exercises")
