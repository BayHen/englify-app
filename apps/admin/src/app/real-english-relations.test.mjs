import assert from 'node:assert/strict';
import test from 'node:test';
import { normalizeLessonRelations, relationItems } from './real-english-relations.ts';

test('normalizes a PostgREST one-to-one object', () => {
  const dialogue = { id: 'dialogue-1', title: 'At a cafe' };
  assert.deepEqual(relationItems(dialogue), [dialogue]);
});

test('preserves a one-to-many array', () => {
  const phrases = [{ id: 'phrase-1' }, { id: 'phrase-2' }];
  assert.deepEqual(relationItems(phrases), phrases);
});

test('handles an absent optional relation', () => {
  assert.deepEqual(relationItems(null), []);
  assert.deepEqual(relationItems(undefined), []);
});

test('normalizes all nested lesson relations before editor rendering', () => {
  const lesson = normalizeLessonRelations({
    id: 'lesson-1',
    real_english_phrases: { id: 'phrase-1' },
    real_english_source_references: null,
    real_english_dialogues: { id: 'dialogue-1', real_english_dialogue_lines: [{ id: 'line-1' }] },
  });
  assert.equal(lesson.real_english_dialogues.length, 1);
  assert.equal(lesson.real_english_dialogues[0].real_english_dialogue_lines.length, 1);
  assert.equal(lesson.real_english_phrases.length, 1);
  assert.deepEqual(lesson.real_english_source_references, []);
});
