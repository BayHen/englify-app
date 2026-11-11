import { describe, expect, it } from 'vitest';
import { ALGORITHM_VERSION, generateWeek, rescheduleMissed, type PlanInput } from '../../../../../supabase/functions/_shared/plan-rules';

const fixture: PlanInput = {
  start: '2026-11-07', proficiency: 'beginner', goal: 'conversation', daily_minutes: 30,
  topics: ['travel', 'food'], quiz_accuracy: 0.9, due_reviews: 2,
  lessons: [{ id: 'done', title: 'Done', completed: true }, { id: 'next', title: 'Next', completed: false }],
};

describe('Supabase plan rules preserve Python version 1', () => {
  it('matches the existing Python fixture for the seven-day schedule', () => {
    expect(ALGORITHM_VERSION).toBe(1);
    const tasks = generateWeek(fixture);
    expect(tasks.map(({ day, kind, minutes, target_count, topic }) => [day, kind, minutes, target_count, topic])).toEqual([
      ['2026-11-07', 'lesson', 15, null, 'travel'], ['2026-11-07', 'vocabulary', 5, 2, 'travel'],
      ['2026-11-07', 'review', 5, 3, 'travel'], ['2026-11-08', 'speaking', 10, null, 'food'],
      ['2026-11-08', 'vocabulary', 5, 2, 'food'], ['2026-11-08', 'review', 5, 3, 'food'],
      ['2026-11-09', 'vocabulary', 5, 2, 'travel'], ['2026-11-09', 'review', 5, 3, 'travel'],
      ['2026-11-10', 'writing', 10, null, 'food'], ['2026-11-10', 'vocabulary', 5, 2, 'food'],
      ['2026-11-10', 'review', 5, 3, 'food'], ['2026-11-11', 'vocabulary', 5, 2, 'travel'],
      ['2026-11-11', 'review', 5, 3, 'travel'], ['2026-11-12', 'vocabulary', 5, 2, 'food'],
      ['2026-11-12', 'review', 5, 3, 'food'], ['2026-11-13', 'review', 10, 3, 'travel'],
      ['2026-11-13', 'vocabulary', 5, 2, 'travel'],
    ]);
    expect(tasks.find((item) => item.kind === 'lesson')?.lesson_id).toBe('next');
  });
  it('adapts to weak quiz accuracy without completing any history', () => {
    const lessons = Array.from({ length: 7 }, (_, i) => ({ id: String(i), title: String(i), completed: false }));
    const strong = generateWeek({ ...fixture, lessons, due_reviews: 0, quiz_accuracy: 0.9 });
    const weak = generateWeek({ ...fixture, lessons, due_reviews: 0, quiz_accuracy: 0.4 });
    expect(weak.filter((item) => item.kind === 'lesson').length).toBeLessThan(strong.filter((item) => item.kind === 'lesson').length);
    expect(weak.filter((item) => item.kind === 'review')).toHaveLength(7);
  });
  it('handles one-minute goals and reschedules without losing tasks', () => {
    const short = generateWeek({ ...fixture, daily_minutes: 1, goal: 'work' });
    expect(short).toHaveLength(7);
    expect(short.every((item) => item.minutes === 1)).toBe(true);
    const tasks = generateWeek({ ...fixture, daily_minutes: 20, due_reviews: 0 });
    const moved = rescheduleMissed(tasks, '2026-11-09', 20);
    expect(moved).toHaveLength(tasks.length);
    expect(moved.every((item) => item.day >= '2026-11-09')).toBe(true);
    for (const day of new Set(moved.map((item) => item.day))) {
      expect(moved.filter((item) => item.day === day).reduce((sum, item) => sum + item.minutes, 0)).toBeLessThanOrEqual(20);
    }
  });
});