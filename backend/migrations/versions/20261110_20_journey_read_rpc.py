"""Bridge the tested Supabase Journey read migration to the current live database."""

from pathlib import Path

from alembic import op

revision = "20261110_20"
down_revision = "20261110_19"
branch_labels = None
depends_on = None


def upgrade() -> None:
    sql = (
        Path(__file__).resolve().parents[3]
        / "supabase/migrations/20261110140000_journey_read_rpc.sql"
    ).read_text(encoding="utf-8")
    op.execute(sql)


def downgrade() -> None:
    raise RuntimeError("Learner progress and permissions must not be removed by downgrade")
