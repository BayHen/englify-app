import { beforeEach, describe, expect, it, vi } from 'vitest';
import { getContextQuiz, searchExpressions, submitContextQuiz } from './api';

const state = vi.hoisted(() => ({ client: null as unknown }));
vi.mock('@/auth/supabase', () => ({ getSupabase: () => state.client }));

function query(data: unknown) {
  const builder = {
    select: vi.fn(), eq: vi.fn(), is: vi.fn(), order: vi.fn(), limit: vi.fn(),
    ilike: vi.fn(), in: vi.fn(), then: (resolve: (result: unknown) => unknown) =>
      Promise.resolve({ data, error: null, status: 200 }).then(resolve),
  };
  for (const name of ['select', 'eq', 'is', 'order', 'limit', 'ilike', 'in'] as const) builder[name].mockReturnValue(builder);
  return builder;
}

beforeEach(() => { state.client = null; });

describe('Real English Supabase repository', () => {
  it('reads only published expressions and joins own saved IDs', async () => {
    const saved = query([{ expression_id: 'expression-1' }]);
    const catalog = query([{ id: 'expression-1', expression: 'Hang on' }]);
    const from = vi.fn().mockReturnValueOnce(saved).mockReturnValueOnce(catalog);
    state.client = {
      auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) },
      from,
    };
    await expect(searchExpressions()).resolves.toMatchObject([{ id: 'expression-1', saved: true }]);
    expect(catalog.eq).toHaveBeenCalledWith('is_published', true);
    expect(catalog.is).toHaveBeenCalledWith('archived_at', null);
    expect(saved.eq).toHaveBeenCalledWith('user_id', 'user-1');
  });

  it('requests only answer-free quiz data and submits a stable request ID to the server', async () => {
    const rpc = vi.fn().mockResolvedValueOnce({ data: { id: 'quiz-1', options: [] }, error: null, status: 200 })
      .mockResolvedValueOnce({ data: { attempt_id: 'attempt-1', is_correct: true }, error: null, status: 200 });
    state.client = {
      auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) }, rpc,
    };
    await expect(getContextQuiz('expression-1')).resolves.toMatchObject({ id: 'quiz-1' });
    await expect(submitContextQuiz('expression-1', 'request-1', 'option-a')).resolves.toMatchObject({ attempt_id: 'attempt-1' });
    expect(rpc).toHaveBeenNthCalledWith(1, 'englify_context_quiz', { p_expression_id: 'expression-1' });
    expect(rpc).toHaveBeenNthCalledWith(2, 'englify_submit_context_quiz', {
      p_expression_id: 'expression-1', p_request_id: 'request-1', p_selected_option: 'option-a',
    });
  });
});
