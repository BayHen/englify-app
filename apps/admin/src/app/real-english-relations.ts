/** PostgREST can represent a nested one-to-one relation as one object. */
export function relationItems<T extends object>(value: T | T[] | null | undefined): T[] {
  if (value == null) return [];
  if (Array.isArray(value)) {
    if (!value.every((item) => item !== null && typeof item === 'object' && !Array.isArray(item))) {
      throw new TypeError('Invalid Real English relation response.');
    }
    return value;
  }
  if (typeof value !== 'object') throw new TypeError('Invalid Real English relation response.');
  return [value];
}

export function normalizeLessonRelations(lesson: Record<string, unknown>) {
  type Row = Record<string, unknown>;
  const rows = (value: unknown) => relationItems(value as Row | Row[] | null | undefined);
  return {
    ...lesson,
    real_english_phrases: rows(lesson.real_english_phrases),
    real_english_source_references: rows(lesson.real_english_source_references),
    real_english_dialogues: rows(lesson.real_english_dialogues).map((dialogue) => ({
      ...dialogue,
      real_english_dialogue_lines: rows(dialogue.real_english_dialogue_lines),
    })),
  };
}
