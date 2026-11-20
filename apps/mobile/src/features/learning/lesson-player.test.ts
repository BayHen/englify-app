import { describe, expect, it } from 'vitest';
import { initialBlockIndex } from './lesson-player-model';
import type { LessonBlock } from './api';

const blocks: LessonBlock[] = [
  { id: 'intro', type: 'introduction', position: 1, content: { text_en: 'Hello', text_vi: 'Xin chào' } },
  { id: 'theory', type: 'theory', position: 2, content: { text_en: 'Rule' } },
];

describe('interactive lesson resume', () => {
  it('restores a valid published block', () => expect(initialBlockIndex(blocks, 'theory')).toBe(1));
  it('falls back safely when a revision no longer contains the saved block', () => expect(initialBlockIndex(blocks, 'retired-block')).toBe(0));
  it('starts at the beginning without resume data', () => expect(initialBlockIndex(blocks)).toBe(0));
});
