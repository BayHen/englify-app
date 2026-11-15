"""Allow owned expression saves and trusted context quiz grading via RPC."""

from pathlib import Path

from alembic import op

revision = "20261110_16"
down_revision = "20261110_15"
branch_labels = None
depends_on = None


def upgrade() -> None:
    sql = (
        Path(__file__).resolve().parents[3]
        / "supabase/migrations/20261110100000_real_english_rpc.sql"
    ).read_text(encoding="utf-8")
    op.execute(sql)


def downgrade() -> None:
    raise RuntimeError("Real English RPC migration is additive and protects learner history")
