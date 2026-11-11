import { beforeEach, describe, expect, it, vi } from 'vitest';
import { downloadLesson, getAttempts, getJourney, startLesson, submitLesson, syncLesson } from './api';

const state = vi.hoisted(() => ({ client: null as unknown }));
vi.mock('@/auth/supabase', () => ({ getSupabase: () => state.client }));
const session = { user: { id: 'learner-1' }, access_token: 'current-token' };
const auth = { getSession: async () => ({ data: { session }, error: null }) };
beforeEach(() => { state.client = null; });

describe('Supabase Journey client', () => {
  it('reads the journey and starts lessons using server-owned RPCs', async () => {
    const rpc = vi.fn().mockResolvedValueOnce({ data: [{ id: 'course-1' }], error: null, status: 200 })
      .mockResolvedValueOnce({ data: { id: 'lesson-1', state: 'in_progress' }, error: null, status: 200 });
    state.client = { auth, rpc };
    await expect(getJourney()).resolves.toEqual([{ id: 'course-1' }]);
    await expect(startLesson('lesson-1')).resolves.toMatchObject({ state: 'in_progress' });
    expect(rpc.mock.calls).toEqual([
      ['englify_journey'], ['englify_start_lesson', { p_lesson_id: 'lesson-1' }],
    ]);
  });
  it('downloads an answer-free package and sends idempotent quiz IDs', async () => {
    const rpc = vi.fn().mockResolvedValueOnce({ data: { id: 'lesson-1', questions: [] }, error: null, status: 200 })
      .mockResolvedValueOnce({ data: 'content-version', error: null, status: 200 })
      .mockResolvedValueOnce({ data: { attempt_id: 'attempt-1', earned_xp: 20 }, error: null, status: 200 })
      .mockResolvedValueOnce({ data: { attempt_id: 'attempt-1', earned_xp: 20 }, error: null, status: 200 });
    state.client = { auth, rpc };
    await expect(downloadLesson('lesson-1')).resolves.toEqual({ lesson: { id: 'lesson-1', questions: [] }, content_version: 'content-version' });
    await expect(submitLesson('lesson-1', 'request-1', { 'question-1': 'option-1' })).resolves.toMatchObject({ earned_xp: 20 });
    await expect(syncLesson('lesson-1', 'request-1', 'content-version', { 'question-1': 'option-1' }, 'current-token'))
      .resolves.toMatchObject({ attempt_id: 'attempt-1' });
    expect(rpc).toHaveBeenNthCalledWith(3, 'englify_submit_lesson', {
      p_lesson_id: 'lesson-1', p_request_id: 'request-1', p_answers: { 'question-1': 'option-1' }, p_content_version: null,
    });
    expect(rpc).toHaveBeenNthCalledWith(4, 'englify_submit_lesson', {
      p_lesson_id: 'lesson-1', p_request_id: 'request-1', p_answers: { 'question-1': 'option-1' }, p_content_version: 'content-version',
    });
  });
  it('rejects a changed session before syncing an offline event', async () => {
    const rpc = vi.fn();
    state.client = { auth, rpc };
    await expect(syncLesson('lesson-1', 'request-1', 'version', {}, 'old-token')).rejects.toMatchObject({ status: 401 });
    expect(rpc).not.toHaveBeenCalled();
  });
  it('maps own attempt history and refuses expired sessions', async () => {
    const builder = { select: vi.fn(), eq: vi.fn(), order: vi.fn(), limit: vi.fn(),
      then: (resolve: (result: unknown) => unknown) => Promise.resolve({ data: [{ id: 'attempt-1', result_state: 'completed', reward_payload: [] }], error: null, status: 200 }).then(resolve) };
    for (const key of ['select', 'eq', 'order', 'limit'] as const) builder[key].mockReturnValue(builder);
    state.client = { auth, from: vi.fn().mockReturnValue(builder) };
    await expect(getAttempts('lesson-1')).resolves.toMatchObject([{ attempt_id: 'attempt-1', state: 'completed', rewards: [] }]);
    expect(builder.eq).toHaveBeenCalledWith('lesson_id', 'lesson-1');
    state.client = { auth: { getSession: async () => ({ data: { session: null }, error: null }) }, rpc: vi.fn() };
    await expect(getJourney()).rejects.toMatchObject({ status: 401 });
  });
});
