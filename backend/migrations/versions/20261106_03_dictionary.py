"""Dictionary pronunciation and content provenance.

Revision ID: 20261106_03
Revises: 20261106_02
"""

import sqlalchemy as sa
from alembic import op

revision = "20261106_03"
down_revision = "20261106_02"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("dictionary_entries", sa.Column("ipa", sa.Text(), nullable=True))
    op.add_column("dictionary_entries", sa.Column("audio_url", sa.Text(), nullable=True))
    op.add_column(
        "dictionary_entries",
        sa.Column(
            "source_name", sa.Text(), server_default="Englify Quest editorial", nullable=False
        ),
    )
    op.add_column(
        "dictionary_entries",
        sa.Column("license_id", sa.Text(), server_default="project-owned", nullable=False),
    )
    op.create_check_constraint(
        "ck_dictionary_audio_https",
        "dictionary_entries",
        "audio_url IS NULL OR audio_url LIKE 'https://%'",
    )
    op.create_index(
        "ix_dictionary_english_prefix",
        "dictionary_entries",
        ["normalized_term"],
        postgresql_where=sa.text("language = 'en'"),
        postgresql_ops={"normalized_term": "text_pattern_ops"},
    )


def downgrade() -> None:
    op.drop_index("ix_dictionary_english_prefix", table_name="dictionary_entries")
    op.drop_constraint("ck_dictionary_audio_https", "dictionary_entries", type_="check")
    for column in ("license_id", "source_name", "audio_url", "ipa"):
        op.drop_column("dictionary_entries", column)
