import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { OutboxEvent } from './types';
import { syncOutbox } from './sync';

const state = vi.hoisted(() => ({ events: [] as OutboxEvent[] }));
vi.mock('./storage', () => ({
  listEvents: async (userId: string) => state.events.filter((event) => event.userId === userId),
  updateEvent: async (value: OutboxEvent) => { state.events = state.events.map((item) => item.id === value.id ? value : item); },
}));
const submit = vi.hoisted(() => vi.fn());
const authState = vi.hoisted(() => ({ userId: 'user-a' }));
vi.mock('@/features/learning/api', () => ({ syncLesson: submit }));
vi.mock('@/features/dictionary/api', () => ({ saveWord: vi.fn() }));
vi.mock('@/auth/supabase', () => ({ getSupabase: () => ({ auth: { getSession: async () => ({ data: { session: { user: { id: authState.userId }, access_token: `token-${authState.userId}` } }, error: null }) } }) }));

function event(id: string): OutboxEvent {
  return { id, userId: 'user-a', kind: 'lesson_submission', payload: { lessonId: id, contentVersion: 'a'.repeat(64), answers: {} }, status: 'pending', attempts: 0, nextRetryAt: 0, message: null, createdAt: id, result: null };
}

describe('offline synchronization', () => {
  beforeEach(() => { state.events = []; submit.mockReset(); authState.userId = 'user-a'; });
  it('keeps a failed event and does not send later locked lessons out of order', async () => {
    state.events = [event('a'), event('b')];
    submit.mockRejectedValueOnce(new Error('network unavailable'));
    const result = await syncOutbox('user-a');
    expect(result.pending).toBe(2);
    expect(state.events[0].attempts).toBe(1);
    expect(state.events[0].nextRetryAt).toBeGreaterThan(Date.now());
    expect(submit).toHaveBeenCalledTimes(1);
  });
  it('retains synced event and never sends it again', async () => {
    state.events = [event('a')];
    submit.mockResolvedValue({ attempt_id: 'attempt-a', rewards: [] });
    expect((await syncOutbox('user-a')).synced).toBe(1);
    expect(state.events[0].status).toBe('synced');
    await syncOutbox('user-a');
    expect(submit).toHaveBeenCalledTimes(1);
  });
  it('does not submit another account’s queued answers after account switching', async () => {
    state.events = [event('a')];
    authState.userId = 'user-b';
    expect((await syncOutbox('user-a')).pending).toBe(1);
    expect(submit).not.toHaveBeenCalled();
  });
  it('sends each event with the token from the session whose user ID was checked', async () => {
    state.events = [event('a'), event('b')];
    submit.mockImplementationOnce(async () => {
      authState.userId = 'user-b';
      return { attempt_id: 'attempt-a', rewards: [] };
    });
    const result = await syncOutbox('user-a');
    expect(result.synced).toBe(1);
    expect(result.pending).toBe(1);
    expect(submit).toHaveBeenCalledTimes(1);
    expect(submit.mock.calls[0][4]).toBe('token-user-a');
  });
});
