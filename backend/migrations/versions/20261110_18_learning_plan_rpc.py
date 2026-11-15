"""Atomic learning plan generation, completion and rescheduling RPCs."""

from pathlib import Path

from alembic import op

revision = "20261110_18"
down_revision = "20261110_17"
branch_labels = None
depends_on = None


def upgrade() -> None:
    sql = (
        Path(__file__).resolve().parents[3]
        / "supabase/migrations/20261110120000_learning_plan_rpc.sql"
    ).read_text(encoding="utf-8")
    op.execute(sql)


def downgrade() -> None:
    raise RuntimeError("Plan history must not be removed by downgrade")