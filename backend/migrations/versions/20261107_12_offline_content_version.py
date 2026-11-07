"""Touch lesson/question edit timestamps when nested content changes."""

from alembic import op

revision = "20261107_12"
down_revision = "20261107_11"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE FUNCTION public.touch_offline_content_version() RETURNS trigger
        LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
        DECLARE parent_id uuid;
        BEGIN
          IF TG_TABLE_NAME = 'lesson_items' THEN
            parent_id := coalesce(NEW.lesson_id, OLD.lesson_id);
            UPDATE public.lessons SET updated_at=now() WHERE id=parent_id;
          ELSE
            parent_id := coalesce(NEW.question_id, OLD.question_id);
            UPDATE public.quiz_questions SET updated_at=now() WHERE id=parent_id;
          END IF;
          RETURN coalesce(NEW, OLD);
        END $$;
        REVOKE ALL ON FUNCTION public.touch_offline_content_version()
          FROM PUBLIC, anon, authenticated;
        CREATE TRIGGER offline_version_items AFTER INSERT OR UPDATE OR DELETE ON public.lesson_items
          FOR EACH ROW EXECUTE FUNCTION public.touch_offline_content_version();
        CREATE TRIGGER offline_version_options AFTER INSERT OR UPDATE OR DELETE
          ON public.quiz_options
          FOR EACH ROW EXECUTE FUNCTION public.touch_offline_content_version();
        CREATE TRIGGER offline_version_keys AFTER INSERT OR UPDATE OR DELETE
          ON public.quiz_answer_keys
          FOR EACH ROW EXECUTE FUNCTION public.touch_offline_content_version();
    """)


def downgrade() -> None:
    op.execute("DROP TRIGGER offline_version_keys ON public.quiz_answer_keys")
    op.execute("DROP TRIGGER offline_version_options ON public.quiz_options")
    op.execute("DROP TRIGGER offline_version_items ON public.lesson_items")
    op.execute("DROP FUNCTION public.touch_offline_content_version()")
