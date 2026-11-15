import { beforeEach, describe, expect, it, vi } from 'vitest';

let handler: ((request: Request) => Promise<Response>) | null;
const env: Record<string, string> = {
  SUPABASE_URL: 'http://127.0.0.1:54321', SUPABASE_ANON_KEY: 'public-test-key',
  SUPABASE_SERVICE_ROLE_KEY: 'private-test-key', EDGE_ALLOWED_ORIGINS: 'http://localhost:8081',
  LANGUAGETOOL_URL: 'http://127.0.0.1:8010',
};
const submit = (submissionId = '44444444-4444-4444-8444-444444444401', origin?: string) => {
  if (!handler) throw new Error('Edge handler missing');
  return handler(new Request('http://localhost/functions/v1/writing-grammar', {
    method: 'POST', headers: { Authorization: 'Bearer test-user-jwt', ...(origin ? { Origin: origin } : {}) },
    body: JSON.stringify({ submissionId }),
  }));
};

beforeEach(async () => {
  vi.resetModules();
  handler = null;
  env.LANGUAGETOOL_URL = 'http://127.0.0.1:8010';
  vi.stubGlobal('Deno', { env: { get: (name: string) => env[name] }, serve: (fn: typeof handler) => { handler = fn; } });
  // @ts-ignore Deno Edge Functions use explicit TypeScript extensions.
  await import('../../../../../supabase/functions/writing-grammar/index.ts');
});

describe('optional grammar Edge Function', () => {
  it('blocks disallowed origins and malformed IDs before database access', async () => {
    const fetcher = vi.fn(); vi.stubGlobal('fetch', fetcher);
    expect((await submit(undefined, 'https://untrusted.example')).status).toBe(403);
    expect((await submit('bad-id')).status).toBe(422);
    expect(fetcher).not.toHaveBeenCalled();
  });
  it('checks Auth and ownership before calling LanguageTool', async () => {
    const fetcher = vi.fn().mockResolvedValueOnce(new Response('{"id":"user-1"}', { status: 200 }))
      .mockResolvedValueOnce(new Response('[]', { status: 200 }));
    vi.stubGlobal('fetch', fetcher);
    expect((await submit()).status).toBe(404);
    expect(fetcher).toHaveBeenCalledTimes(2);
  });
  it('returns available only after trusted feedback is stored', async () => {
    const fetcher = vi.fn().mockResolvedValueOnce(new Response('{"id":"user-1"}', { status: 200 }))
      .mockResolvedValueOnce(new Response('[{"id":"submission-1","user_id":"user-1","body":"I write English."}]', { status: 200 }))
      .mockResolvedValueOnce(new Response('{"matches":[]}', { status: 200 }))
      .mockResolvedValueOnce(new Response('true', { status: 200 }));
    vi.stubGlobal('fetch', fetcher);
    const response = await submit();
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ status: 'available' });
    expect(String(fetcher.mock.calls[2][0])).toContain('/v2/check');
    expect(String(fetcher.mock.calls[3][0])).toContain('/rpc/englify_attach_grammar_feedback');
    const options = fetcher.mock.calls[3][1] as RequestInit;
    expect((options.headers as Record<string, string>).Authorization).toBe('Bearer private-test-key');
  });
  it('keeps rule feedback when provider is not configured', async () => {
    delete env.LANGUAGETOOL_URL;
    const fetcher = vi.fn().mockResolvedValueOnce(new Response('{"id":"user-1"}', { status: 200 }))
      .mockResolvedValueOnce(new Response('[{"id":"submission-1","user_id":"user-1","body":"Hello"}]', { status: 200 }));
    vi.stubGlobal('fetch', fetcher);
    expect(await (await submit()).json()).toEqual({ status: 'unavailable' });
    expect(fetcher).toHaveBeenCalledTimes(2);
  });
});
