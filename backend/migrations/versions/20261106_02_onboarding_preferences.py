"""Persist selected learning goal and initial proficiency.

Revision ID: 20261106_02
Revises: 20261106_01
"""

import sqlalchemy as sa
from alembic import op

revision = "20261106_02"
down_revision = "20261106_01"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("user_preferences", sa.Column("learning_goal", sa.Text(), nullable=True))
    op.add_column("user_preferences", sa.Column("initial_proficiency", sa.Text(), nullable=True))
    op.add_column(
        "user_preferences",
        sa.Column("onboarding_completed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_check_constraint(
        "ck_preferences_learning_goal",
        "user_preferences",
        "learning_goal IS NULL OR learning_goal IN ('conversation', 'travel', 'work', 'exams')",
    )
    op.create_check_constraint(
        "ck_preferences_initial_proficiency",
        "user_preferences",
        "initial_proficiency IS NULL OR "
        "initial_proficiency IN ('beginner', 'intermediate', 'advanced')",
    )
    op.create_check_constraint(
        "ck_preferences_onboarding_complete",
        "user_preferences",
        "onboarding_completed_at IS NULL OR "
        "(learning_goal IS NOT NULL AND initial_proficiency IS NOT NULL)",
    )


def downgrade() -> None:
    op.drop_constraint("ck_preferences_onboarding_complete", "user_preferences", type_="check")
    op.drop_constraint("ck_preferences_initial_proficiency", "user_preferences", type_="check")
    op.drop_constraint("ck_preferences_learning_goal", "user_preferences", type_="check")
    op.drop_column("user_preferences", "onboarding_completed_at")
    op.drop_column("user_preferences", "initial_proficiency")
    op.drop_column("user_preferences", "learning_goal")
