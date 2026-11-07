"""Server-owned XP rules, quests, levels, badges and reward notifications.

Revision ID: 20261106_07
Revises: 20261106_06
"""
# ruff: noqa: E501 -- migration SQL is deliberately kept intact.

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision = "20261106_07"
down_revision = "20261106_06"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "gamification_config",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("level_xp_step", sa.Integer(), nullable=False),
        sa.Column("lesson_multiplier_percent", sa.Integer(), nullable=False),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("id = 1"),
        sa.CheckConstraint("level_xp_step BETWEEN 10 AND 10000"),
        sa.CheckConstraint("lesson_multiplier_percent BETWEEN 0 AND 200"),
        schema="public",
    )
    op.execute("""
        INSERT INTO public.gamification_config(id, level_xp_step, lesson_multiplier_percent)
        VALUES (1, 100, 100)
    """)
    op.create_table(
        "user_levels",
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("public.profiles.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("total_xp", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("level", sa.Integer(), nullable=False, server_default="1"),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("total_xp >= 0 AND level >= 1"),
        schema="public",
    )
    op.execute("""
        INSERT INTO public.user_levels(user_id, total_xp, level)
        SELECT p.id, greatest(0, coalesce(sum(x.amount), 0))::integer,
               (greatest(0, coalesce(sum(x.amount), 0)) / 100)::integer + 1
        FROM public.profiles p LEFT JOIN public.xp_events x ON x.user_id = p.id
        GROUP BY p.id
    """)
    op.drop_constraint("xp_events_source_type_check", "xp_events", type_="check")
    op.create_check_constraint(
        "xp_events_source_type_check",
        "xp_events",
        "source_type IN ('lesson', 'quiz', 'review', 'speaking', 'writing', 'adjustment', 'quest')",
    )
    op.create_table(
        "quests",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("code", sa.Text(), nullable=False, unique=True),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("period", sa.Text(), nullable=False),
        sa.Column("target_lessons", sa.Integer(), nullable=False),
        sa.Column("reward_xp", sa.Integer(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.CheckConstraint("period IN ('daily', 'weekly')"),
        sa.CheckConstraint("target_lessons BETWEEN 1 AND 100"),
        sa.CheckConstraint("reward_xp BETWEEN 0 AND 1000"),
        schema="public",
    )
    op.create_index("ix_quests_active_period", "quests", ["is_active", "period"])
    op.execute("""
        INSERT INTO public.quests(id, code, title, description, period, target_lessons, reward_xp)
        VALUES
          ('aaaaaaaa-0000-4000-8000-000000000001', 'daily-lesson', 'One step today',
           'Complete one new lesson today.', 'daily', 1, 5),
          ('aaaaaaaa-0000-4000-8000-000000000002', 'weekly-three-lessons', 'Keep learning',
           'Complete three new lessons this week.', 'weekly', 3, 15)
    """)
    op.create_table(
        "quest_claims",
        sa.Column(
            "id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")
        ),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("public.profiles.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "quest_id",
            UUID(as_uuid=True),
            sa.ForeignKey("public.quests.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("period_start", sa.Date(), nullable=False),
        sa.Column("awarded_xp", sa.Integer(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.UniqueConstraint("user_id", "quest_id", "period_start"),
        sa.CheckConstraint("awarded_xp >= 0"),
        schema="public",
    )
    op.create_index("ix_quest_claims_user_recent", "quest_claims", ["user_id", "period_start"])
    op.create_table(
        "badge_rules",
        sa.Column(
            "badge_id",
            UUID(as_uuid=True),
            sa.ForeignKey("public.badges.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("metric", sa.Text(), nullable=False),
        sa.Column("target", sa.Integer(), nullable=False),
        sa.CheckConstraint("metric IN ('completed_lessons', 'total_xp')"),
        sa.CheckConstraint("target > 0"),
        schema="public",
    )
    op.execute("""
        INSERT INTO public.badges(id, code, title, description) VALUES
          ('66666666-6666-4666-8666-666666666601', 'first-step', 'First step', 'Complete your first lesson.'),
          ('66666666-6666-4666-8666-666666666602', 'four-lessons', 'Pathfinder', 'Complete four lessons.'),
          ('66666666-6666-4666-8666-666666666603', 'hundred-xp', 'Rising star', 'Earn 100 XP.')
        ON CONFLICT (id) DO NOTHING
    """)
    op.execute("""
        INSERT INTO public.badge_rules(badge_id, metric, target) VALUES
          ('66666666-6666-4666-8666-666666666601', 'completed_lessons', 1),
          ('66666666-6666-4666-8666-666666666602', 'completed_lessons', 4),
          ('66666666-6666-4666-8666-666666666603', 'total_xp', 100)
    """)
    op.add_column(
        "reward_items",
        sa.Column("required_level", sa.Integer(), nullable=False, server_default="1"),
    )
    op.create_check_constraint("ck_reward_required_level", "reward_items", "required_level >= 1")
    op.add_column(
        "lesson_attempts",
        sa.Column("reward_payload", JSONB(), nullable=False, server_default=sa.text("'[]'::jsonb")),
    )
    op.create_table(
        "reward_notifications",
        sa.Column(
            "id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")
        ),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("public.profiles.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("kind", sa.Text(), nullable=False),
        sa.Column("source_id", UUID(as_uuid=True), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.Column("read_at", sa.DateTime(timezone=True)),
        sa.UniqueConstraint("user_id", "kind", "source_id"),
        sa.CheckConstraint("kind IN ('xp', 'level', 'badge', 'quest', 'reward')"),
        schema="public",
    )
    op.create_index(
        "ix_reward_notifications_user_unread",
        "reward_notifications",
        ["user_id", "read_at", "created_at"],
    )
    for table in (
        "gamification_config",
        "user_levels",
        "quests",
        "quest_claims",
        "badge_rules",
        "reward_notifications",
    ):
        op.execute(f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY")
        op.execute(f"REVOKE ALL ON public.{table} FROM anon, authenticated")
    op.execute(
        "GRANT SELECT ON public.quests, public.user_levels, public.quest_claims, public.reward_notifications TO authenticated"
    )
    op.execute(
        "CREATE POLICY quests_read ON public.quests FOR SELECT TO authenticated USING (is_active)"
    )
    for table in ("user_levels", "quest_claims", "reward_notifications"):
        op.execute(
            f"CREATE POLICY {table}_own_read ON public.{table} FOR SELECT TO authenticated USING ((select auth.uid()) = user_id)"
        )


def downgrade() -> None:
    op.drop_table("reward_notifications", schema="public")
    op.drop_column("lesson_attempts", "reward_payload")
    op.drop_constraint("ck_reward_required_level", "reward_items", type_="check")
    op.drop_column("reward_items", "required_level")
    op.drop_table("badge_rules", schema="public")
    op.drop_table("quest_claims", schema="public")
    op.drop_index("ix_quests_active_period", table_name="quests")
    op.drop_table("quests", schema="public")
    op.drop_constraint("xp_events_source_type_check", "xp_events", type_="check")
    op.create_check_constraint(
        "xp_events_source_type_check",
        "xp_events",
        "source_type IN ('lesson', 'quiz', 'review', 'speaking', 'writing', 'adjustment')",
    )
    op.drop_table("user_levels", schema="public")
    op.drop_table("gamification_config", schema="public")
