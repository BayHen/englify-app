"""Units, typed lesson items, and idempotent graded attempts.

Revision ID: 20261106_05
Revises: 20261106_04
"""
# ruff: noqa: E501 -- migration SQL is deliberately kept intact.

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision = "20261106_05"
down_revision = "20261106_04"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "learning_units",
        sa.Column(
            "id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")
        ),
        sa.Column(
            "course_id",
            UUID(as_uuid=True),
            sa.ForeignKey("public.courses.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("slug", sa.Text(), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.UniqueConstraint("course_id", "slug"),
        sa.UniqueConstraint("course_id", "position"),
        sa.CheckConstraint("position > 0"),
        schema="public",
    )
    op.add_column(
        "lessons",
        sa.Column(
            "unit_id",
            UUID(as_uuid=True),
            sa.ForeignKey("public.learning_units.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    # Existing published lessons remain reachable after introducing units.
    op.execute("""
        INSERT INTO public.learning_units(course_id, slug, title, position)
        SELECT DISTINCT l.course_id, 'existing-lessons', 'Existing lessons', 1000000
        FROM public.lessons l
    """)
    op.execute("""
        UPDATE public.lessons l SET unit_id = u.id
        FROM public.learning_units u
        WHERE u.course_id = l.course_id AND u.slug = 'existing-lessons'
          AND l.unit_id IS NULL
    """)
    op.create_index("ix_lessons_unit_position", "lessons", ["unit_id", "position"])
    op.create_table(
        "lesson_items",
        sa.Column(
            "id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")
        ),
        sa.Column(
            "lesson_id",
            UUID(as_uuid=True),
            sa.ForeignKey("public.lessons.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("kind", sa.Text(), nullable=False),
        sa.Column("body", JSONB(), nullable=False),
        sa.UniqueConstraint("lesson_id", "position"),
        sa.CheckConstraint("position > 0"),
        sa.CheckConstraint("kind IN ('reading', 'tip')"),
        schema="public",
    )
    op.add_column(
        "quiz_questions",
        sa.Column("kind", sa.Text(), server_default="multiple_choice", nullable=False),
    )
    op.add_column(
        "quiz_questions",
        sa.Column("payload", JSONB(), server_default=sa.text("'{}'::jsonb"), nullable=False),
    )
    op.create_check_constraint(
        "ck_quiz_question_kind",
        "quiz_questions",
        "kind IN ('multiple_choice', 'fill_blank', 'matching', 'listening', 'grammar')",
    )
    op.create_table(
        "quiz_answer_keys",
        sa.Column(
            "question_id",
            UUID(as_uuid=True),
            sa.ForeignKey("public.quiz_questions.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("answer", JSONB(), nullable=False),
        schema="public",
    )
    op.create_table(
        "lesson_attempts",
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
            "lesson_id",
            UUID(as_uuid=True),
            sa.ForeignKey("public.lessons.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("request_id", UUID(as_uuid=True), nullable=False),
        sa.Column("correct_count", sa.Integer(), nullable=False),
        sa.Column("question_count", sa.Integer(), nullable=False),
        sa.Column("passed", sa.Boolean(), nullable=False),
        sa.Column("result_state", sa.Text(), nullable=False),
        sa.Column("earned_xp", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.UniqueConstraint("user_id", "request_id"),
        sa.CheckConstraint("question_count > 0 AND correct_count BETWEEN 0 AND question_count"),
        sa.CheckConstraint("earned_xp >= 0"),
        sa.CheckConstraint("result_state IN ('in_progress', 'completed', 'mastered')"),
        schema="public",
    )
    op.create_index(
        "ix_lesson_attempts_user_lesson", "lesson_attempts", ["user_id", "lesson_id", "created_at"]
    )
    op.create_table(
        "lesson_answer_attempts",
        sa.Column(
            "id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")
        ),
        sa.Column(
            "attempt_id",
            UUID(as_uuid=True),
            sa.ForeignKey("public.lesson_attempts.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "question_id",
            UUID(as_uuid=True),
            sa.ForeignKey("public.quiz_questions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("answer", JSONB(), nullable=False),
        sa.Column("is_correct", sa.Boolean(), nullable=False),
        sa.UniqueConstraint("attempt_id", "question_id"),
        schema="public",
    )
    op.drop_constraint("learning_progress_status_check", "learning_progress", type_="check")
    op.create_check_constraint(
        "learning_progress_status_check",
        "learning_progress",
        "status IN ('not_started', 'in_progress', 'completed', 'mastered')",
    )
    op.drop_constraint("learning_progress_check", "learning_progress", type_="check")
    op.create_check_constraint(
        "learning_progress_check",
        "learning_progress",
        "(status IN ('completed', 'mastered')) = (completed_at IS NOT NULL)",
    )
    for table in (
        "learning_units",
        "lesson_items",
        "quiz_answer_keys",
        "lesson_attempts",
        "lesson_answer_attempts",
    ):
        op.execute(f"ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY")
        op.execute(f"REVOKE ALL ON public.{table} FROM anon, authenticated")
    op.execute("GRANT SELECT ON public.learning_units, public.lesson_items TO authenticated")
    op.execute(
        "CREATE POLICY units_read ON public.learning_units FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.courses c WHERE c.id = course_id AND c.is_published))"
    )
    op.execute(
        "CREATE POLICY items_read ON public.lesson_items FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.lessons l JOIN public.courses c ON c.id = l.course_id WHERE l.id = lesson_id AND l.is_published AND c.is_published))"
    )
    op.execute(
        "GRANT SELECT ON public.lesson_attempts, public.lesson_answer_attempts TO authenticated"
    )
    op.execute(
        "CREATE POLICY attempts_own_read ON public.lesson_attempts FOR SELECT TO authenticated USING ((select auth.uid()) = user_id)"
    )
    op.execute(
        "CREATE POLICY answers_own_read ON public.lesson_answer_attempts FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM public.lesson_attempts a WHERE a.id = attempt_id AND a.user_id = (select auth.uid())))"
    )


def downgrade() -> None:
    op.drop_constraint("learning_progress_check", "learning_progress", type_="check")
    op.create_check_constraint(
        "learning_progress_check",
        "learning_progress",
        "(status = 'completed') = (completed_at IS NOT NULL)",
    )
    op.drop_constraint("learning_progress_status_check", "learning_progress", type_="check")
    op.create_check_constraint(
        "learning_progress_status_check",
        "learning_progress",
        "status IN ('not_started', 'in_progress', 'completed')",
    )
    op.drop_table("lesson_answer_attempts", schema="public")
    op.drop_index("ix_lesson_attempts_user_lesson", table_name="lesson_attempts")
    op.drop_table("lesson_attempts", schema="public")
    op.drop_table("quiz_answer_keys", schema="public")
    op.drop_constraint("ck_quiz_question_kind", "quiz_questions", type_="check")
    op.drop_column("quiz_questions", "payload")
    op.drop_column("quiz_questions", "kind")
    op.drop_table("lesson_items", schema="public")
    op.drop_index("ix_lessons_unit_position", table_name="lessons")
    op.drop_column("lessons", "unit_id")
    op.drop_table("learning_units", schema="public")
