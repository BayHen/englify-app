import { describe, expect, it } from 'vitest';
import { completeTake, type PracticeHistory } from './practice-history';

describe('local speaking completion', () => {
  it('counts a take once and allows a new take', () => {
    const initial: PracticeHistory = { completed: 0, recordings: {}, completedTakes: {} };
    const once = completeTake(initial, 'greeting', 'file://take-1');
    expect(once.completed).toBe(1);
    expect(completeTake(once, 'greeting', 'file://take-1')).toBe(once);
    expect(completeTake(once, 'greeting', 'file://take-2').completed).toBe(2);
    expect(initial.completed).toBe(0);
  });
});
