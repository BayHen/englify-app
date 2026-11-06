"""Initial learning schema using Supabase Auth identities.

Revision ID: 20261106_01
Revises:
"""

from pathlib import Path

from alembic import op

revision = "20261106_01"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Supabase supplies auth.users, auth.uid(), anon, and authenticated.
    sql = Path(__file__).with_name("20261106_01_initial_learning_schema.sql").read_text(
        encoding="utf-8"
    )
    op.execute(sql)


def downgrade() -> None:
    # Explicit reverse dependency order. This drops application data only.
    op.execute("DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users")
    for table in (
        "reward_claims", "user_badges", "xp_events", "writing_submissions",
        "speaking_attempts", "quiz_attempts", "review_history", "saved_vocabulary",
        "learning_plans", "learning_progress", "user_preferences", "profiles",
        "reward_items", "badges", "quiz_options", "quiz_questions", "lessons",
        "courses", "dictionary_entries",
    ):
        op.execute(f"DROP TABLE public.{table}")
    op.execute("DROP FUNCTION IF EXISTS public.touch_updated_at()")
    op.execute("DROP FUNCTION IF EXISTS public.provision_profile()")
