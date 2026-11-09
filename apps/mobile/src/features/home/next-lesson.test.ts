import { describe, expect, it } from 'vitest';
import { nextLesson } from './next-lesson';
import type { JourneyCourse } from '@/features/learning/api';

describe('home learning action', () => {
  it('offers the first server-unlocked lesson and never a locked one', () => {
    const courses: JourneyCourse[] = [{ id: 'course', title: 'Explorer', units: [{ id: 'unit', title: 'Hello', position: 1, lessons: [
      { id: 'done', title: 'First', objective: '', position: 1, state: 'completed' },
      { id: 'available', title: 'Second', objective: '', position: 2, state: 'available' },
      { id: 'locked', title: 'Third', objective: '', position: 3, state: 'locked' },
    ] }] }];
    expect(nextLesson(courses)?.lesson.id).toBe('available');
    expect(nextLesson([{ ...courses[0], units: [{ ...courses[0].units[0], lessons: courses[0].units[0].lessons.filter((lesson) => lesson.state !== 'available') }] }])).toBeNull();
  });
});
