/** Normalize PostgREST one-to-one and one-to-many embedded relations. */
function relationItems(value: unknown): Record<string, unknown>[] {
  if (value == null) return [];
  if (Array.isArray(value)) {
    if (!value.every((item) => item !== null && typeof item === 'object' && !Array.isArray(item))) {
      throw new TypeError('Invalid Real English lesson response.');
    }
    return value;
  }
  if (typeof value !== 'object') throw new TypeError('Invalid Real English lesson response.');
  return [value as Record<string, unknown>];
}

export function normalizePublishedLessonRelations(lesson: Record<string, unknown>) {
  return {
    ...lesson,
    real_english_phrases: relationItems(lesson.real_english_phrases),
    real_english_source_references: relationItems(lesson.real_english_source_references),
    real_english_dialogues: relationItems(lesson.real_english_dialogues).map((dialogue) => ({
      ...dialogue,
      real_english_dialogue_lines: relationItems(dialogue.real_english_dialogue_lines),
    })),
  };
}
