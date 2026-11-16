import assert from 'node:assert/strict';
import test from 'node:test';
import { supabaseAdminRequest } from './supabase-admin.ts';

const requestId = '11111111-1111-4111-8111-111111111111';

function clientFor(result) {
  const calls = [];
  const client = {
    auth: { getSession: async () => ({ data: { session: { user: { id: 'admin-1' } } }, error: null }) },
    rpc: async (name, values) => {
      calls.push([name, values]);
      if (name === 'englify_is_admin') return { data: true, error: null };
      return { data: result, error: null };
    },
    from: () => { throw new Error('multi-table writes must use an RPC'); },
  };
  return { client, calls };
}

test('quiz question writes use the atomic RPC and request id', async () => {
  const previous = process.env.NEXT_PUBLIC_ADMIN_ATOMIC_CRUD_ENABLED;
  process.env.NEXT_PUBLIC_ADMIN_ATOMIC_CRUD_ENABLED = 'true';
  try {
    const result = { id: '22222222-2222-4222-8222-222222222222', prompt: 'Question', answer: ['answer'] };
    const { client, calls } = clientFor(result);
    const actual = await supabaseAdminRequest(client, '/catalog/quiz-questions', {
      method: 'POST',
      body: JSON.stringify({
        request_id: requestId,
        data: { lesson_id: '33333333-3333-4333-8333-333333333333', position: 1, kind: 'fill_blank', prompt: 'Question', payload: {}, answer: ['answer'] },
      }),
    });
    assert.deepEqual(actual, result);
    assert.equal(calls[1][0], 'englify_admin_upsert_quiz_question');
    assert.equal(calls[1][1].p_request_id, requestId);
    assert.deepEqual(calls[1][1].p_data.answer, ['answer']);
  } finally {
    if (previous === undefined) delete process.env.NEXT_PUBLIC_ADMIN_ATOMIC_CRUD_ENABLED;
    else process.env.NEXT_PUBLIC_ADMIN_ATOMIC_CRUD_ENABLED = previous;
  }
});

test('badge writes reject a missing idempotency key before mutation', async () => {
  const previous = process.env.NEXT_PUBLIC_ADMIN_ATOMIC_CRUD_ENABLED;
  process.env.NEXT_PUBLIC_ADMIN_ATOMIC_CRUD_ENABLED = 'true';
  try {
    const { client, calls } = clientFor({});
    await assert.rejects(
      () => supabaseAdminRequest(client, '/catalog/badges', {
        method: 'POST',
        body: JSON.stringify({ data: { code: 'first', title: 'First', metric: 'total_xp', target: 10 } }),
      }),
      /valid mutation request ID/,
    );
    assert.deepEqual(calls.map(([name]) => name), ['englify_is_admin']);
  } finally {
    if (previous === undefined) delete process.env.NEXT_PUBLIC_ADMIN_ATOMIC_CRUD_ENABLED;
    else process.env.NEXT_PUBLIC_ADMIN_ATOMIC_CRUD_ENABLED = previous;
  }
});
