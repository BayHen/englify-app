"""Hide locked lesson content from direct Supabase Data API reads.

Revision ID: 20261106_06
Revises: 20261106_05
"""

from alembic import op

revision = "20261106_06"
down_revision = "20261106_05"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE FUNCTION public.lesson_unlocked(target_lesson_id uuid)
        RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
          SELECT EXISTS (
            SELECT 1 FROM public.lessons current_lesson
            JOIN public.learning_units current_unit ON current_unit.id = current_lesson.unit_id
            JOIN public.courses course ON course.id = current_unit.course_id
            WHERE current_lesson.id = target_lesson_id
              AND current_lesson.is_published AND course.is_published
              AND (select auth.uid()) IS NOT NULL
              AND NOT EXISTS (
                SELECT 1 FROM public.lessons prior
                JOIN public.learning_units prior_unit ON prior_unit.id = prior.unit_id
                LEFT JOIN public.learning_progress progress
                  ON progress.lesson_id = prior.id AND progress.user_id = (select auth.uid())
                WHERE prior_unit.course_id = course.id AND prior.is_published
                  AND (prior_unit.position < current_unit.position OR
                       (prior_unit.position = current_unit.position
                        AND prior.position < current_lesson.position))
                  AND (progress.status IS NULL OR progress.status NOT IN ('completed', 'mastered'))
              )
          )
        $$
    """)
    op.execute("REVOKE ALL ON FUNCTION public.lesson_unlocked(uuid) FROM PUBLIC, anon")
    op.execute("GRANT EXECUTE ON FUNCTION public.lesson_unlocked(uuid) TO authenticated")
    op.execute("DROP POLICY questions_read ON public.quiz_questions")
    op.execute("""
        CREATE POLICY questions_read ON public.quiz_questions FOR SELECT TO authenticated
        USING ((select public.lesson_unlocked(lesson_id)))
    """)
    op.execute("DROP POLICY items_read ON public.lesson_items")
    op.execute("""
        CREATE POLICY items_read ON public.lesson_items FOR SELECT TO authenticated
        USING ((select public.lesson_unlocked(lesson_id)))
    """)


def downgrade() -> None:
    op.execute("DROP POLICY items_read ON public.lesson_items")
    op.execute("""
        CREATE POLICY items_read ON public.lesson_items FOR SELECT TO authenticated
        USING (EXISTS (SELECT 1 FROM public.lessons l JOIN public.courses c
          ON c.id = l.course_id WHERE l.id = lesson_id AND l.is_published AND c.is_published))
    """)
    op.execute("DROP POLICY questions_read ON public.quiz_questions")
    op.execute("""
        CREATE POLICY questions_read ON public.quiz_questions FOR SELECT TO authenticated
        USING (EXISTS (SELECT 1 FROM public.lessons l
          WHERE l.id = lesson_id AND l.is_published))
    """)
    op.execute("DROP FUNCTION public.lesson_unlocked(uuid)")
