import { describe, expect, it } from 'vitest';
import { normalizePublishedLessonRelations } from './lesson-relations';

describe('published Real English relations', () => {
  it('normalizes a single embedded dialogue and nested lines', () => {
    const result = normalizePublishedLessonRelations({ id: 'lesson-1',
      real_english_dialogues: { id: 'dialogue-1', real_english_dialogue_lines: [{ id: 'line-1' }] },
      real_english_phrases: [{ id: 'phrase-1' }], real_english_source_references: { id: 'source-1' } });
    expect(result.real_english_dialogues).toHaveLength(1);
    expect(result.real_english_dialogues[0].real_english_dialogue_lines).toHaveLength(1);
    expect(result.real_english_source_references).toHaveLength(1);
  });

  it('preserves an absent optional relation as an empty list', () => {
    expect(normalizePublishedLessonRelations({ real_english_dialogues: null }).real_english_dialogues).toEqual([]);
  });
});
