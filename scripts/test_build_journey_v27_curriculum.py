from pathlib import Path
import importlib.util

SCRIPT = Path(__file__).with_name("build_journey_v27_curriculum.py")
spec = importlib.util.spec_from_file_location("journey_builder", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(module)

sql = module.build()
assert sql.count("INSERT INTO public.courses(") == 10
assert sql.count("INSERT INTO public.journey_chapters(") == 30
assert sql.count("INSERT INTO public.learning_units(") == 60
assert sql.count("'lesson') ON CONFLICT(id) DO NOTHING;") == 180
assert sql.count("'unit_checkpoint') ON CONFLICT(id) DO NOTHING;") == 60
assert sql.count("'level_assessment') ON CONFLICT(id) DO NOTHING;") == 10
assert sql.count("'capstone') ON CONFLICT(id) DO NOTHING;") == 1
assert "UPDATE public.user_lesson_progress" not in sql
assert "DELETE FROM public." not in sql
print("Journey V2.7 curriculum builder checks passed")

