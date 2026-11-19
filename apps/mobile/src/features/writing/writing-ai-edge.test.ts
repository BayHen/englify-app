import { beforeEach, describe, expect, it, vi } from 'vitest';

let coach: ((request: Request) => Promise<Response>) | null;
let rewrite: ((request: Request) => Promise<Response>) | null;
const env: Record<string, string> = {
  SUPABASE_URL: 'http://127.0.0.1:54321', SUPABASE_ANON_KEY: 'public-test-key', SUPABASE_SERVICE_ROLE_KEY: 'service-test-key',
  GEMINI_API_KEY: 'gemini-test-key', GEMINI_MODEL: 'gemini-2.5-flash-lite', WRITING_AI_ENABLED: 'true',
  AI_FREE_TIER_CONFIRMED: 'true', AI_MONTHLY_MAX_ESTIMATED_COST_USD: '0', WRITING_AI_MAX_OUTPUT_TOKENS: '1000',
  WRITING_AI_COACH_DAILY_LIMIT: '5', WRITING_AI_REWRITE_DAILY_LIMIT: '5', EDGE_ALLOWED_ORIGINS: 'http://localhost:8081',
};
const submissionId = '33333333-3333-4333-8333-333333333333';
const requestId = '77777777-7777-4777-8777-777777777777';
const request = (path: string, body: unknown, authorized = true) => new Request(`http://localhost/functions/v1/${path}`, {
  method: 'POST', headers: authorized ? { Authorization: 'Bearer test-user-jwt' } : {}, body: JSON.stringify(body),
});

beforeEach(async () => {
  vi.resetModules(); coach = null; rewrite = null;
  vi.stubGlobal('Deno', { env: { get: (name: string) => env[name] }, serve: (fn: (request: Request) => Promise<Response>) => {
    if (!coach) coach = fn; else rewrite = fn;
  } });
  // @ts-ignore Deno Edge Functions use explicit TypeScript extensions.
  await import('../../../../../supabase/functions/writing-ai-coach/index.ts');
  // @ts-ignore Deno Edge Functions use explicit TypeScript extensions.
  await import('../../../../../supabase/functions/writing-ai-rewrite/index.ts');
});

describe('Writing AI Edge authorization and limits', () => {
  it('rejects unauthenticated coach and rewrite requests before network access', async () => {
    const fetcher = vi.fn(); vi.stubGlobal('fetch', fetcher);
    expect((await coach!(request('writing-ai-coach', { submissionId, requestId }, false))).status).toBe(401);
    expect((await rewrite!(request('writing-ai-rewrite', { submissionId, requestId, mode: 'natural' }, false))).status).toBe(401);
    expect(fetcher).not.toHaveBeenCalled();
  });
  it('rejects an invalid rewrite mode after verifying ownership', async () => {
    const fetcher = vi.fn().mockResolvedValueOnce(new Response('{"id":"user-1"}', { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify([{ id: submissionId, user_id: 'user-1', exercise_id: '44444444-4444-4444-8444-444444444404', prompt: 'Write.', body: 'This paragraph has enough words to qualify for a safe AI rewrite request.' }]), { status: 200 }))
      .mockResolvedValueOnce(new Response('[{"kind":"paragraph"}]', { status: 200 }));
    vi.stubGlobal('fetch', fetcher);
    const response = await rewrite!(request('writing-ai-rewrite', { submissionId, requestId, mode: 'invent-facts' }));
    expect(response.status).toBe(422); expect(await response.json()).toMatchObject({ code: 'invalid_request' });
    expect(fetcher).toHaveBeenCalledTimes(3);
  });
  it('returns a clear quota response when the transactional claim is refused', async () => {
    const fetcher = vi.fn().mockResolvedValueOnce(new Response('{"id":"user-1"}', { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify([{ id: submissionId, user_id: 'user-1', exercise_id: '44444444-4444-4444-8444-444444444404', prompt: 'Write.', body: 'This paragraph has enough words to qualify for safe AI writing feedback.' }]), { status: 200 }))
      .mockResolvedValueOnce(new Response('[{"kind":"paragraph"}]', { status: 200 }))
      .mockResolvedValueOnce(new Response('{"message":"Daily limit"}', { status: 429 }));
    vi.stubGlobal('fetch', fetcher);
    const response = await coach!(request('writing-ai-coach', { submissionId, requestId }));
    expect(response.status).toBe(429); expect(await response.json()).toMatchObject({ code: 'quota' });
  });
});
