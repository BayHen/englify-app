"""Server-authoritative gamification reads and reward claims."""

from pathlib import Path

from alembic import op

revision = "20261110_19"
down_revision = "20261110_18"
branch_labels = None
depends_on = None


def upgrade() -> None:
    sql = (
        Path(__file__).resolve().parents[3]
        / "supabase/migrations/20261110130000_gamification_rpc.sql"
    ).read_text(encoding="utf-8")
    op.execute(sql)


def downgrade() -> None:
    raise RuntimeError("Reward history and permissions must not be removed by downgrade")