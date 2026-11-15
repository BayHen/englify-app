import { beforeEach, describe, expect, it, vi } from 'vitest';
import { getExercises, getWritingHistory, submitWriting } from './api';

const state = vi.hoisted(() => ({ client: null as unknown }));
vi.mock('@/auth/supabase', () => ({ getSupabase: () => state.client }));
const auth = { getSession: async () => ({ data: { session: { user: { id: 'learner-1' }, access_token: 'token' } }, error: null }) };
beforeEach(() => { state.client = null; });

describe('writing Supabase client', () => {
  it('loads published exercises directly from Supabase', async () => {
    const exercises = [{ id: 'exercise-1', kind: 'sentence', prompt: 'Write a greeting.', hint: 'Be friendly.', tokens: [] }];
    const orderById = vi.fn().mockResolvedValue({ data: exercises, error: null, status: 200 });
    const orderByKind = vi.fn().mockReturnValue({ order: orderById });
    const eq = vi.fn().mockReturnValue({ order: orderByKind });
    const select = vi.fn().mockReturnValue({ eq });
    const from = vi.fn().mockReturnValue({ select });
    state.client = { auth, from };

    await expect(getExercises()).resolves.toEqual(exercises);
    expect(from).toHaveBeenCalledWith('writing_exercises');
    expect(eq).toHaveBeenCalledWith('is_published', true);
    expect(orderByKind).toHaveBeenCalledWith('kind');
    expect(orderById).toHaveBeenCalledWith('id');
  });

  it('keeps rule feedback when optional grammar Edge service is unavailable', async () => {
    const saved = { id: 'submission-1', body: 'Hello.', feedback: { rule_result: 'matched', grammar_status: 'unavailable' } };
    const rpc = vi.fn().mockResolvedValue({ data: saved, error: null, status: 200 });
    const invoke = vi.fn().mockRejectedValue(new Error('Edge unavailable'));
    state.client = { auth, rpc, functions: { invoke } };
    await expect(submitWriting('request-1', 'exercise-1', 'Hello.', true)).resolves.toBe(saved);
    expect(rpc).toHaveBeenCalledWith('englify_submit_writing', {
      p_request_id: 'request-1', p_exercise_id: 'exercise-1', p_body: 'Hello.', p_grammar_check: true,
    });
    expect(invoke).toHaveBeenCalledWith('writing-grammar', { body: { submissionId: 'submission-1' } });
  });
  it('reloads persisted provider feedback only after Edge confirms it', async () => {
    const saved = { id: 'submission-1', feedback: { grammar_status: 'unavailable' } };
    const enriched = { id: 'submission-1', feedback: { grammar_status: 'available', grammar_matches: [] } };
    const rpc = vi.fn().mockResolvedValueOnce({ data: saved, error: null, status: 200 })
      .mockResolvedValueOnce({ data: enriched, error: null, status: 200 });
    state.client = { auth, rpc, functions: { invoke: vi.fn().mockResolvedValue({ data: { status: 'available' }, error: null }) } };
    await expect(submitWriting('request-1', 'exercise-1', 'Hello.', true)).resolves.toBe(enriched);
    expect(rpc).toHaveBeenNthCalledWith(2, 'englify_writing_submission', { p_submission_id: 'submission-1' });
  });
  it('loads durable history through the ownership-checked RPC', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: [{ id: 'submission-1' }], error: null, status: 200 });
    state.client = { auth, rpc };
    await expect(getWritingHistory()).resolves.toEqual([{ id: 'submission-1' }]);
    expect(rpc).toHaveBeenCalledWith('englify_writing_history', { p_limit: 30 });
  });
});
