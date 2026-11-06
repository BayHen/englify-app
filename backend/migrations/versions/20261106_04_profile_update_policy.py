"""Allow authenticated users to edit only their own public profile fields.

Revision ID: 20261106_04
Revises: 20261106_03
"""

from alembic import op

revision = "20261106_04"
down_revision = "20261106_03"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("GRANT UPDATE (display_name, avatar_url) ON public.profiles TO authenticated")
    op.execute("""
        CREATE POLICY profiles_own_update ON public.profiles
        FOR UPDATE TO authenticated
        USING ((select auth.uid()) = id)
        WITH CHECK ((select auth.uid()) = id)
    """)


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS profiles_own_update ON public.profiles")
    op.execute("REVOKE UPDATE (display_name, avatar_url) ON public.profiles FROM authenticated")
