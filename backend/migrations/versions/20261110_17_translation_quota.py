"""Reserve bounded Google translation usage through Supabase RPC."""

from pathlib import Path

from alembic import op

revision = "20261110_17"
down_revision = "20261110_16"
branch_labels = None
depends_on = None


def upgrade() -> None:
    sql = (
        Path(__file__).resolve().parents[3]
        / "supabase/migrations/20261110110000_translation_quota.sql"
    ).read_text(encoding="utf-8")
    op.execute(sql)


def downgrade() -> None:
    raise RuntimeError("Usage records protect provider quotas; no destructive downgrade")