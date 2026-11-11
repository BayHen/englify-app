"""Bridge the tested Supabase writing RPCs to the current live database."""

from pathlib import Path

from alembic import op

revision = "20261110_22"
down_revision = "20261110_21"
branch_labels = None
depends_on = None


def upgrade() -> None:
    sql = (
        Path(__file__).resolve().parents[3]
        / "supabase/migrations/20261110160000_writing_rpc.sql"
    ).read_text(encoding="utf-8")
    op.execute(sql)


def downgrade() -> None:
    raise RuntimeError("Writing history must not be removed by downgrade")
