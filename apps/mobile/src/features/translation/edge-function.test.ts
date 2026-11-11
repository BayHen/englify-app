import { beforeEach, describe, expect, it, vi } from 'vitest';

let handler: ((request: Request) => Promise<Response>) | null;
const env: Record<string, string> = {
  SUPABASE_URL: 'http://127.0.0.1:54321', SUPABASE_ANON_KEY: 'test-public-key',
  TRANSLATE_ALLOWED_ORIGINS: 'http://localhost:8081',
};
function request(body: unknown, authorization = 'Bearer user-jwt', origin?: string): Request {
  return new Request('http://localhost/functions/v1/translate', {
    method: 'POST', headers: { Authorization: authorization, 'Content-Type': 'application/json',
      ...(origin ? { Origin: origin } : {}) }, body: JSON.stringify(body),
  });
}
async function invoke(body: unknown, authorization?: string, origin?: string) {
  if (!handler) throw new Error('Function handler was not registered');
  return handler(request(body, authorization, origin));
}
beforeEach(async () => {
  vi.resetModules();
  handler = null;
  vi.stubGlobal('Deno', { env: { get: (name: string) => env[name] }, serve: (fn: typeof handler) => { handler = fn; } });
  // @ts-ignore Deno Edge Functions use explicit TypeScript extensions.
  await import('../../../../../supabase/functions/translate/index.ts');
});
describe('translation Edge Function contract', () => {
  const input = { text: 'I am learning English.', sourceLanguage: 'en', targetLanguage: 'vi' };
  it('rejects missing auth and disallowed browser origins', async () => {
    expect((await invoke(input, 'invalid')).status).toBe(401);
    expect((await invoke(input, undefined, 'https://evil.test')).status).toBe(403);
  });
  it('rejects empty, oversized and invalid language requests before quota', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response('{}', { status: 200 }));
    vi.stubGlobal('fetch', fetcher);
    for (const body of [
      { ...input, text: '   ' }, { ...input, text: 'ế'.repeat(167) },
      { ...input, sourceLanguage: 'auto' }, { ...input, sourceLanguage: 'fr' },
      { ...input, targetLanguage: 'en' },
    ]) expect((await invoke(body)).status).toBe(422);
    expect(fetcher).toHaveBeenCalledTimes(5);
    expect(fetcher.mock.calls.every((call) => String(call[0]).includes('/auth/v1/user'))).toBe(true);
  });
  it('verifies auth, reserves quota, and returns actual upstream text', async () => {
    const fetcher = vi.fn()
      .mockResolvedValueOnce(new Response('{"id":"user-1"}', { status: 200 }))
      .mockResolvedValueOnce(new Response(null, { status: 204 }))
      .mockResolvedValueOnce(new Response('{"responseStatus":200,"responseData":{"translatedText":"Tôi đang học tiếng Anh."}}', { status: 200 }));
    vi.stubGlobal('fetch', fetcher);
    const response = await invoke(input);
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ translatedText: 'Tôi đang học tiếng Anh.', provider: 'mymemory' });
    expect(String(fetcher.mock.calls[1][0])).toContain('/rest/v1/rpc/englify_reserve_translation');
    expect(String(fetcher.mock.calls[2][0])).toContain('api.mymemory.translated.net/get');
  });
  it('does not call provider for expired sessions or exhausted quota', async () => {
    const expired = vi.fn().mockResolvedValue(new Response('{}', { status: 401 }));
    vi.stubGlobal('fetch', expired);
    expect((await invoke(input)).status).toBe(401);
    expect(expired).toHaveBeenCalledTimes(1);
    const limited = vi.fn().mockResolvedValueOnce(new Response('{}', { status: 200 }))
      .mockResolvedValueOnce(new Response('{"code":"P0001"}', { status: 400 }));
    vi.stubGlobal('fetch', limited);
    expect((await invoke(input)).status).toBe(429);
    expect(limited).toHaveBeenCalledTimes(2);
  });
  it('returns upstream quota and malformed response errors', async () => {
    for (const [payload, status] of [
      ['{"responseStatus":429,"quotaFinished":true}', 429],
      ['{"responseStatus":200,"responseData":{}}', 502],
    ] as const) {
      const fetcher = vi.fn().mockResolvedValueOnce(new Response('{}', { status: 200 }))
        .mockResolvedValueOnce(new Response(null, { status: 204 }))
        .mockResolvedValueOnce(new Response(payload, { status: 200 }));
      vi.stubGlobal('fetch', fetcher);
      expect((await invoke(input)).status).toBe(status);
    }
  });
  it('does not return source text as a successful translation', async () => {
    const fetcher = vi.fn()
      .mockResolvedValueOnce(new Response('{"id":"user-1"}', { status: 200 }))
      .mockResolvedValueOnce(new Response(null, { status: 204 }))
      .mockResolvedValueOnce(new Response('{"responseStatus":200,"responseData":{"translatedText":"License"}}', { status: 200 }));
    vi.stubGlobal('fetch', fetcher);
    const response = await invoke({ text: 'License', sourceLanguage: 'en', targetLanguage: 'vi' });
    expect(response.status).toBe(422);
    expect(await response.json()).toMatchObject({ error: expect.stringContaining('No distinct translation') });
  });
});
