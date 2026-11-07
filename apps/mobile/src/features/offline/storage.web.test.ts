import { describe, expect, it } from 'vitest';
import { cacheJourney, cacheLesson, cacheProfile, getCachedJourney, getCachedLesson, getCachedProfile, listEvents, queueEvent, updateEvent } from './storage.web';
import { retryDelay, type OutboxEvent } from './types';

describe('offline cache and outbox', () => {
  it('scopes downloaded content to the account', async () => {
    const lesson = { id: 'lesson-a', title: 'Start', objective: 'Practice', state: 'available' as const, items: [], questions: [] };
    await cacheLesson('offline-user-a', lesson.id, { lesson, contentVersion: 'a'.repeat(64), savedAt: '2026-01-01' });
    await cacheJourney('offline-user-a', { courses: [], savedAt: '2026-01-01' });
    await cacheProfile('offline-user-a', { id: 'offline-user-a', display_name: 'Learner', preferences: null });
    expect((await getCachedLesson('offline-user-a', lesson.id))?.lesson.title).toBe('Start');
    expect(await getCachedLesson('offline-user-b', lesson.id)).toBeNull();
    expect(await getCachedJourney('offline-user-b')).toBeNull();
    expect((await getCachedProfile('offline-user-a'))?.display_name).toBe('Learner');
    expect(await getCachedProfile('offline-user-b')).toBeNull();
  });
  it('keeps one event per request and retains successful history', async () => {
    const event: OutboxEvent = { id: 'offline-event-a', userId: 'offline-user-a', kind: 'lesson_submission', payload: { lessonId: 'lesson-a', contentVersion: 'a'.repeat(64), answers: { q: 'a' } }, status: 'pending', attempts: 0, nextRetryAt: 0, message: null, createdAt: '2026-01-01', result: null };
    await queueEvent(event); await queueEvent(event);
    expect((await listEvents(event.userId)).filter((item) => item.id === event.id)).toHaveLength(1);
    await updateEvent({ ...event, status: 'synced' });
    expect((await listEvents(event.userId)).find((item) => item.id === event.id)?.status).toBe('synced');
    expect(await listEvents('offline-user-b')).toEqual([]);
  });
  it('caps exponential retry delay', () => {
    expect(retryDelay(0)).toBe(2000);
    expect(retryDelay(2)).toBe(8000);
    expect(retryDelay(20)).toBe(256000);
  });
});
