import { describe, expect, it } from 'vitest';
import { availableArenaQuestions, formatArenaAnswer, isArenaAnswerComplete } from './arena-model';
import type { ArenaConfig, ArenaGroup, ArenaQuestion } from './arena-api';
const choice = { id: 'q', kind: 'multiple_choice', options: [{ id: 'a', text: 'Alpha' }, { id: 'b', text: 'Beta' }], left_items: [], right_items: [] } as unknown as ArenaQuestion;
const matching = { ...choice, kind: 'matching', left_items: [{ id: 'l1', text: 'One' }, { id: 'l2', text: 'Two' }], right_items: [{ id: 'r1', text: 'Mot' }, { id: 'r2', text: 'Hai' }] } as ArenaQuestion;
describe('Arena practice completeness and configuration', () => {
  it('combines every filter and returns zero for an empty category', () => {
    const groups: ArenaGroup[] = [
      { cefr_level: 'A1', topic: 'grammar', kind: 'multiple_choice', difficulty: 1, available: 6 },
      { cefr_level: 'A1', topic: 'vocabulary', kind: 'matching', difficulty: 2, available: 5 },
      { cefr_level: 'B1', topic: 'grammar', kind: 'multiple_choice', difficulty: 1, available: 20 },
    ];
    const config: ArenaConfig = { level: 'A1', topic: null, kind: null, difficulty: null, count: 5 };
    expect(availableArenaQuestions(groups, config)).toBe(11);
    expect(availableArenaQuestions(groups, { ...config, kind: 'matching', difficulty: 2, topic: 'vocabulary' })).toBe(5);
    expect(availableArenaQuestions(groups, { ...config, topic: 'reading' })).toBe(0);
  });
  it.each(['multiple_choice', 'reading'] as const)('requires a real option for %s', kind => {
    const question = { ...choice, kind };
    expect(isArenaAnswerComplete(question, 'a')).toBe(true); expect(isArenaAnswerComplete(question, 'forged')).toBe(false);
    expect(isArenaAnswerComplete(question, undefined)).toBe(false);
  });
  it.each(['fill_blank', 'grammar_correction'] as const)('requires nonblank text for %s', kind => {
    const question = { ...choice, kind };
    expect(isArenaAnswerComplete(question, ' My answer ')).toBe(true); expect(isArenaAnswerComplete(question, '  ')).toBe(false);
  });
  it('requires a complete matching bijection', () => {
    expect(isArenaAnswerComplete(matching, { l1: 'r1', l2: 'r2' })).toBe(true);
    expect(isArenaAnswerComplete(matching, { l1: 'r1' })).toBe(false);
    expect(isArenaAnswerComplete(matching, { l1: 'r1', l2: 'r1' })).toBe(false);
    expect(isArenaAnswerComplete(matching, { l1: 'r1', l2: 'forged' })).toBe(false);
  });
  it('requires every ordering token exactly once', () => {
    const question = { ...choice, kind: 'sentence_order' as const };
    expect(isArenaAnswerComplete(question, ['b', 'a'])).toBe(true); // Completeness is independent of correctness.
    expect(isArenaAnswerComplete(question, ['a', 'a'])).toBe(false);
    expect(isArenaAnswerComplete(question, ['a'])).toBe(false);
  });
  it('formats option IDs, token order and matching into readable review answers', () => {
    expect(formatArenaAnswer(choice, 'a')).toBe('Alpha');
    expect(formatArenaAnswer(choice, ['b', 'a'])).toBe('Beta Alpha');
    expect(formatArenaAnswer(matching, { l1: 'r1', l2: 'r2' })).toBe('One → Mot\nTwo → Hai');
  });
});
