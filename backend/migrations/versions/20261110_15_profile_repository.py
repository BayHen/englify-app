"""Add safe direct profile writes during Supabase migration."""

from pathlib import Path

from alembic import op

revision = "20261110_15"
down_revision = "20261110_14"
branch_labels = None
depends_on = None


def upgrade() -> None:
    sql = (
        Path(__file__).resolve().parents[3]
        / "supabase/migrations/20261110090000_profile_repository.sql"
    ).read_text(encoding="utf-8")
    op.execute(sql)


def downgrade() -> None:
    raise RuntimeError("Profile migration is additive; do not drop ownership checks on live data")
