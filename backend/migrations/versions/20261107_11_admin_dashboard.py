"""Admin allowlist, audit trail, and draft flags for catalog content."""
# ruff: noqa: E501 -- Migration SQL is kept intact for review.

from alembic import op

revision = "20261107_11"
down_revision = "20261107_10"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE TABLE public.admin_members (
          user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
          created_at timestamptz NOT NULL DEFAULT now()
        );
        CREATE TABLE public.admin_audit_logs (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
          action text NOT NULL CHECK (action IN ('create','update','delete','publish','unpublish')),
          resource text NOT NULL,
          record_id uuid NOT NULL,
          before_data jsonb,
          after_data jsonb,
          created_at timestamptz NOT NULL DEFAULT now()
        );
        CREATE INDEX admin_audit_logs_recent_idx ON public.admin_audit_logs(created_at DESC);
        CREATE INDEX admin_audit_logs_record_idx ON public.admin_audit_logs(resource,record_id,created_at DESC);
        ALTER TABLE public.admin_members ENABLE ROW LEVEL SECURITY;
        ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;
    """)
    # Existing records keep their current visibility; newly created admin records default to draft.
    for table in (
        "dictionary_entries",
        "learning_units",
        "lesson_items",
        "quiz_questions",
        "badges",
    ):
        op.execute(
            f"ALTER TABLE public.{table} ADD COLUMN is_published boolean NOT NULL DEFAULT true"
        )
        op.execute(f"CREATE INDEX {table}_published_idx ON public.{table}(is_published)")
    for table in (
        "dictionary_entries",
        "courses",
        "learning_units",
        "lessons",
        "lesson_items",
        "quiz_questions",
        "real_english_expressions",
        "badges",
    ):
        op.execute(f"ALTER TABLE public.{table} ADD COLUMN archived_at timestamptz")
    op.execute("ALTER TABLE public.dictionary_entries ALTER COLUMN is_published SET DEFAULT false")
    op.execute("ALTER TABLE public.learning_units ALTER COLUMN is_published SET DEFAULT false")
    op.execute("ALTER TABLE public.lesson_items ALTER COLUMN is_published SET DEFAULT false")
    op.execute("ALTER TABLE public.quiz_questions ALTER COLUMN is_published SET DEFAULT false")
    op.execute("ALTER TABLE public.badges ALTER COLUMN is_published SET DEFAULT false")
    op.execute("DROP POLICY dictionary_read ON public.dictionary_entries")
    op.execute(
        "CREATE POLICY dictionary_read ON public.dictionary_entries FOR SELECT TO authenticated USING (is_published AND archived_at IS NULL)"
    )
    op.execute("DROP POLICY courses_read ON public.courses")
    op.execute(
        "CREATE POLICY courses_read ON public.courses FOR SELECT TO authenticated USING (is_published AND archived_at IS NULL)"
    )
    op.execute("DROP POLICY lessons_read ON public.lessons")
    op.execute(
        "CREATE POLICY lessons_read ON public.lessons FOR SELECT TO authenticated USING (is_published AND archived_at IS NULL AND EXISTS (SELECT 1 FROM public.courses c WHERE c.id=course_id AND c.is_published AND c.archived_at IS NULL))"
    )
    op.execute("DROP POLICY units_read ON public.learning_units")
    op.execute(
        "CREATE POLICY units_read ON public.learning_units FOR SELECT TO authenticated USING (is_published AND archived_at IS NULL AND EXISTS (SELECT 1 FROM public.courses c WHERE c.id=course_id AND c.is_published AND c.archived_at IS NULL))"
    )
    op.execute("DROP POLICY items_read ON public.lesson_items")
    op.execute(
        "CREATE POLICY items_read ON public.lesson_items FOR SELECT TO authenticated USING (is_published AND archived_at IS NULL AND (select public.lesson_unlocked(lesson_id)))"
    )
    op.execute("DROP POLICY questions_read ON public.quiz_questions")
    op.execute(
        "CREATE POLICY questions_read ON public.quiz_questions FOR SELECT TO authenticated USING (is_published AND archived_at IS NULL AND (select public.lesson_unlocked(lesson_id)))"
    )
    op.execute("DROP POLICY badges_read ON public.badges")
    op.execute(
        "CREATE POLICY badges_read ON public.badges FOR SELECT TO authenticated USING (is_published AND archived_at IS NULL)"
    )
    op.execute("DROP POLICY real_english_published_read ON public.real_english_expressions")
    op.execute(
        "CREATE POLICY real_english_published_read ON public.real_english_expressions FOR SELECT TO authenticated USING (is_published AND archived_at IS NULL)"
    )
    op.execute("""CREATE OR REPLACE FUNCTION public.lesson_unlocked(target_lesson_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
      SELECT EXISTS (SELECT 1 FROM public.lessons current_lesson
      JOIN public.learning_units current_unit ON current_unit.id=current_lesson.unit_id
      JOIN public.courses course ON course.id=current_unit.course_id
      WHERE current_lesson.id=target_lesson_id AND current_lesson.is_published AND current_lesson.archived_at IS NULL
        AND current_unit.is_published AND current_unit.archived_at IS NULL
        AND course.is_published AND course.archived_at IS NULL AND (select auth.uid()) IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM public.lessons prior
          JOIN public.learning_units prior_unit ON prior_unit.id=prior.unit_id
          LEFT JOIN public.learning_progress progress ON progress.lesson_id=prior.id AND progress.user_id=(select auth.uid())
          WHERE prior_unit.course_id=course.id AND prior.is_published AND prior.archived_at IS NULL
            AND prior_unit.is_published AND prior_unit.archived_at IS NULL
            AND (prior_unit.position<current_unit.position OR (prior_unit.position=current_unit.position AND prior.position<current_lesson.position))
            AND (progress.status IS NULL OR progress.status NOT IN ('completed','mastered')))) $$""")


def downgrade() -> None:
    # Explicit downgrade is intentionally unsupported for live content and audit history.
    raise RuntimeError(
        "Admin migration is additive; restore from a verified backup if rollback is required"
    )
