"""Persist versioned weekly learning plans without removing learning history."""
# ruff: noqa: E501 -- SQL definitions remain intact for review.

from alembic import op

revision = "20261107_08"
down_revision = "20261106_07"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE public.user_preferences ADD COLUMN preferred_topics text[] NOT NULL DEFAULT '{}'"
    )
    op.execute(
        "ALTER TABLE public.learning_plans ADD COLUMN algorithm_version integer NOT NULL DEFAULT 1"
    )
    op.execute("ALTER TABLE public.learning_plans ADD COLUMN starts_on date")
    op.execute(
        "ALTER TABLE public.learning_plans ADD CONSTRAINT learning_plans_id_user_unique UNIQUE (id, user_id)"
    )
    op.execute("""
        CREATE TABLE public.learning_plan_tasks (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          plan_id uuid NOT NULL,
          user_id uuid NOT NULL,
          lesson_id uuid REFERENCES public.lessons(id) ON DELETE SET NULL,
          kind text NOT NULL CHECK (kind IN ('lesson', 'vocabulary', 'review', 'speaking', 'writing')),
          title text NOT NULL,
          scheduled_on date NOT NULL,
          original_date date NOT NULL,
          duration_minutes integer NOT NULL CHECK (duration_minutes BETWEEN 1 AND 180),
          target_count integer CHECK (target_count > 0),
          topic text,
          status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
          completed_at timestamptz,
          position integer NOT NULL,
          created_at timestamptz NOT NULL DEFAULT now(),
          updated_at timestamptz NOT NULL DEFAULT now(),
          CONSTRAINT plan_task_owner_fk FOREIGN KEY (plan_id, user_id)
            REFERENCES public.learning_plans(id, user_id) ON DELETE CASCADE,
          CONSTRAINT plan_task_completed_consistency CHECK (
            (status = 'completed' AND completed_at IS NOT NULL) OR
            (status = 'pending' AND completed_at IS NULL)
          )
        )
    """)
    op.execute(
        "CREATE INDEX plan_tasks_user_date_idx ON public.learning_plan_tasks(user_id, scheduled_on, position)"
    )
    op.execute("CREATE INDEX plan_tasks_plan_idx ON public.learning_plan_tasks(plan_id)")
    op.execute("ALTER TABLE public.learning_plan_tasks ENABLE ROW LEVEL SECURITY")
    op.execute(
        "CREATE POLICY plan_tasks_own_read ON public.learning_plan_tasks FOR SELECT TO authenticated USING ((select auth.uid()) = user_id)"
    )
    op.execute("GRANT SELECT ON public.learning_plan_tasks TO authenticated")


def downgrade() -> None:
    op.execute("DROP TABLE public.learning_plan_tasks")
    op.execute("ALTER TABLE public.learning_plans DROP CONSTRAINT learning_plans_id_user_unique")
    op.execute("ALTER TABLE public.learning_plans DROP COLUMN starts_on")
    op.execute("ALTER TABLE public.learning_plans DROP COLUMN algorithm_version")
    op.execute("ALTER TABLE public.user_preferences DROP COLUMN preferred_topics")
