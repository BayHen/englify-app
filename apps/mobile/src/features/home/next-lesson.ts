import type { JourneyCourse, JourneyLesson } from '@/features/learning/api';

export function nextLesson(courses: JourneyCourse[]): { course: JourneyCourse; lesson: JourneyLesson } | null {
  for (const course of courses) for (const unit of course.units) {
    const lesson = unit.lessons.find((item) => item.state === 'in_progress' || item.state === 'available');
    if (lesson) return { course, lesson };
  }
  return null;
}
