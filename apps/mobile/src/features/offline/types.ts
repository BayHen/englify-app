import type { Answer, JourneyCourse, LessonDetail, QuizResult } from '@/features/learning/api';

export type CachedLesson = { lesson: LessonDetail; contentVersion: string; savedAt: string };
export type OutboxEvent = {
  id: string; userId: string; kind: 'lesson_submission' | 'save_word';
  payload: { lessonId: string; contentVersion: string; answers: Record<string, Answer> } | { wordId: string };
  status: 'pending' | 'conflict' | 'rejected' | 'synced'; attempts: number;
  nextRetryAt: number; message: string | null; createdAt: string; result: QuizResult | null;
};
export type CachedJourney = { courses: JourneyCourse[]; savedAt: string };

export function retryDelay(attempts: number): number {
  return Math.min(300_000, 2_000 * 2 ** Math.min(attempts, 7));
}
