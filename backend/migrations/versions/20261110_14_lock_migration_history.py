"""Restrict direct client access to Alembic metadata during the transition."""

from pathlib import Path

from alembic import op

revision = "20261110_14"
down_revision = "20261109_13"
branch_labels = None
depends_on = None


def upgrade() -> None:
    sql = (
        Path(__file__).resolve().parents[3]
        / "supabase/migrations/20261110080000_lock_migration_history.sql"
    ).read_text(encoding="utf-8")
    op.execute(sql)


def downgrade() -> None:
    raise RuntimeError("Do not restore client write access to Alembic metadata")
