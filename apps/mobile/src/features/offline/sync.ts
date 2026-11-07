import { ApiError } from '@/lib/api';
import { getSupabase } from '@/auth/supabase';
import { saveWord } from '@/features/dictionary/api';
import { syncLesson } from '@/features/learning/api';
import { listEvents, updateEvent } from './storage';
import { retryDelay, type OutboxEvent } from './types';

let active = false;
export async function syncOutbox(userId: string): Promise<{ synced: number; pending: number; conflicts: number }> {
  if (active) return { synced: 0, pending: (await listEvents(userId)).filter((event) => event.status === 'pending').length, conflicts: 0 };
  active = true;
  let synced = 0;
  try {
    for (const event of await listEvents(userId)) {
      if (event.status !== 'pending' || event.nextRetryAt > Date.now()) continue;
      // A previous account's queue must never be submitted with a new account's JWT.
      const { data, error } = await getSupabase().auth.getSession();
      if (error || !data.session || data.session.user.id !== userId || event.userId !== userId) break;
      try {
        let result = null;
        if (event.kind === 'lesson_submission') {
          const payload = event.payload as { lessonId: string; contentVersion: string; answers: Record<string, string | Record<string, string>> };
          result = await syncLesson(payload.lessonId, event.id, payload.contentVersion, payload.answers);
        } else {
          await saveWord((event.payload as { wordId: string }).wordId);
        }
        await updateEvent({ ...event, status: 'synced', result, message: null }); synced += 1;
      } catch (cause) {
        const status = cause instanceof ApiError ? cause.status : 0;
        const message = cause instanceof Error ? cause.message : 'Synchronization failed';
        if (status === 401 || status === 0 || status >= 500) {
          await updateEvent({ ...event, attempts: event.attempts + 1, nextRetryAt: Date.now() + retryDelay(event.attempts), message });
          break; // Keep chronological lesson unlock order.
        }
        const state: OutboxEvent['status'] = status === 409 ? 'conflict' : 'rejected';
        await updateEvent({ ...event, status: state, message });
        if (event.kind === 'lesson_submission') break;
      }
    }
  } finally { active = false; }
  const all = await listEvents(userId);
  return { synced, pending: all.filter((event) => event.status === 'pending').length, conflicts: all.filter((event) => event.status === 'conflict' || event.status === 'rejected').length };
}
export async function retryPendingNow(userId: string) {
  for (const event of await listEvents(userId)) if (event.status === 'pending') await updateEvent({ ...event, nextRetryAt: 0 });
  return syncOutbox(userId);
}
