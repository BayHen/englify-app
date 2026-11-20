"""Compile a complete set of reviewed Unit drafts into one SQL migration."""

import argparse
import json
from pathlib import Path

from build_journey_v27_curriculum import LEVELS, q, uid
from generate_journey_unit_questions import validate


def compile_rows(directory, only=None):
    rows = []
    prompts = set()
    for level, _, _, _, units in LEVELS:
        for number, _ in enumerate(units, 1):
            if only and (level, number) != only:
                continue
            path = directory / f"level-{level:02}-unit-{number:02}.json"
            questions = validate(json.loads(path.read_text(encoding="utf-8")))
            for index, question in enumerate(questions):
                # Preserve the two sets already curated and deployed.
                if level == 1 and number in {2, 3} and index < 9:
                    continue
                scope = f"lesson:{index // 3 + 1}" if index < 9 else "checkpoint"
                position = index % 3 + 1 if index < 9 else index - 8
                lesson_key = f"level:{level}:unit:{number}:{scope}"
                old_id = uid(f"{uid(lesson_key)}:question:{position}")
                prompt = " ".join(question["prompt"].casefold().split())
                if prompt in prompts:
                    raise ValueError(f"Repeated prompt across drafts: {path}: {question['prompt']}")
                prompts.add(prompt)
                rows.append(dict(question, old_id=old_id, new_id=uid(f"{old_id}:context-v1")))
    return rows


SQL = """-- Reviewed Journey Unit exercises. Preserve attempted question and option IDs.
DO $journey$
DECLARE
  item record;
  original public.quiz_questions%ROWTYPE;
BEGIN
  FOR item IN SELECT * FROM jsonb_to_recordset(DRAFTS)
    AS draft(old_id uuid, new_id uuid, prompt text, choices jsonb, correct_index integer, explanation_vi text)
  LOOP
    IF EXISTS (SELECT 1 FROM public.quiz_questions WHERE id=item.new_id AND is_published AND archived_at IS NULL) THEN
      CONTINUE;
    END IF;
    UPDATE public.quiz_questions
    SET archived_at=transaction_timestamp(), is_published=false
    WHERE id=item.old_id AND archived_at IS NULL AND is_published AND kind='multiple_choice'
    RETURNING * INTO original;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Expected published generated question %', item.old_id;
    END IF;

    INSERT INTO public.quiz_questions(id, lesson_id, position, kind, prompt, explanation, explanation_vi, is_published)
    VALUES(item.new_id, original.lesson_id, original.position+20, 'multiple_choice',
      item.prompt, item.explanation_vi, item.explanation_vi, false);

    INSERT INTO public.quiz_options(question_id, position, answer_text, is_correct)
    SELECT item.new_id, choice.position::int, choice.answer, choice.position=item.correct_index+1
    FROM jsonb_array_elements_text(item.choices) WITH ORDINALITY AS choice(answer, position);

    UPDATE public.quiz_questions SET is_published=true WHERE id=item.new_id;
  END LOOP;
END
$journey$;
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reviewed_drafts", type=Path)
    parser.add_argument("migration", type=Path)
    parser.add_argument("--unit", nargs=2, type=int, metavar=("LEVEL", "UNIT"))
    args = parser.parse_args()
    only = tuple(args.unit) if args.unit else None
    rows = compile_rows(args.reviewed_drafts, only)
    expected = (6 if only in {(1, 2), (1, 3)} else 15) if only else 882
    if len(rows) != expected:
        raise ValueError(f"Expected {expected} replacements, found {len(rows)}")
    with args.migration.open("x", encoding="utf-8") as migration:
        payload = q(json.dumps(rows, ensure_ascii=False, indent=2)) + "::jsonb"
        migration.write(SQL.replace("DRAFTS", payload))
    print(f"Compiled {len(rows)} replacement questions")


if __name__ == "__main__":
    main()
