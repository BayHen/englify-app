import { beforeEach, describe, expect, it, vi } from 'vitest';

let handler: ((request: Request) => Promise<Response>) | null;
const env: Record<string, string> = {
  SUPABASE_URL: 'http://127.0.0.1:54321',
  SUPABASE_ANON_KEY: 'test-public-key',
  SUPABASE_SERVICE_ROLE_KEY: 'test-service-role-key',
  DICTIONARY_ALLOWED_ORIGINS: 'http://localhost:8081',
};
const databaseWord = {
  id: '11111111-1111-4111-8111-111111111111', term: 'license', definition: 'An official permit.',
  translation: 'giấy phép', ipa: '/license/', part_of_speech: 'noun', example: 'She has a license.',
  audio_url: 'https://audio.test/license.mp3', source_name: 'Englify editorial', license_id: 'project-owned',
  is_published: true, archived_at: null,
};
const dictionaryPayload = [{
  word: 'license', phonetic: '/license/', phonetics: [{ audio: '//audio.test/license.mp3' }],
  meanings: [
    { partOfSpeech: 'noun', definitions: [{ definition: 'An official permit.', example: 'She has a license.', synonyms: ['permit'] }] },
    { partOfSpeech: 'verb', definitions: [{ definition: 'To authorize.', antonyms: ['ban'] }] },
  ],
  license: { name: 'CC BY-SA 3.0', url: 'https://creativecommons.org/licenses/by-sa/3.0' },
  sourceUrls: ['https://en.wiktionary.org/wiki/license'],
}];

function request(body: unknown, authorization = 'Bearer user-jwt', origin?: string): Request {
  return new Request('http://localhost/functions/v1/dictionary-import', {
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
  await import('../../../../../supabase/functions/dictionary-import/index.ts');
});

describe('dictionary import Edge Function', () => {
  it('rejects missing auth, disallowed origins, and non-word input', async () => {
    expect((await invoke({ word: 'license' }, 'invalid')).status).toBe(401);
    expect((await invoke({ word: 'license' }, undefined, 'https://evil.test')).status).toBe(403);
    const fetcher = vi.fn().mockResolvedValue(new Response('{}', { status: 200 }));
    vi.stubGlobal('fetch', fetcher);
    expect((await invoke({ word: 'two words' })).status).toBe(422);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('returns an existing curated row without calling external providers or writing', async () => {
    const fetcher = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);
      if (url.includes('/auth/v1/user')) return new Response('{"id":"user-1"}', { status: 200 });
      if (url.includes('/rest/v1/dictionary_entries')) return new Response(JSON.stringify([databaseWord]), { status: 200 });
      throw new Error(`Unexpected request: ${url}`);
    });
    vi.stubGlobal('fetch', fetcher);
    const response = await invoke({ word: 'License' });
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ imported: false, word: { source_name: 'Englify editorial' } });
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it('imports verified provider data, translates it, and exposes multiple parsed senses', async () => {
    const inserted = { ...databaseWord, source_name: 'Free Dictionary API', license_id: 'CC BY-SA 3.0' };
    const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      if (url.includes('/auth/v1/user')) return new Response('{"id":"user-1"}', { status: 200 });
      if (url.includes('/rest/v1/dictionary_entries') && init?.method !== 'POST') return new Response('[]', { status: 200 });
      if (url.includes('api.dictionaryapi.dev')) return new Response(JSON.stringify(dictionaryPayload), { status: 200 });
      if (url.includes('/functions/v1/translate')) return new Response(JSON.stringify({ status: 'translated', translatedText: 'giấy phép' }), { status: 200 });
      if (url.includes('/rest/v1/dictionary_entries') && init?.method === 'POST') return new Response(JSON.stringify([inserted]), { status: 201 });
      throw new Error(`Unexpected request: ${url}`);
    });
    vi.stubGlobal('fetch', fetcher);
    const response = await invoke({ word: 'license' });
    expect(response.status).toBe(200);
    const payload = await response.json();
    expect(payload).toMatchObject({ imported: true, translationAvailable: true,
      word: { id: databaseWord.id, translation: 'giấy phép', source_name: 'Free Dictionary API' } });
    expect(payload.details.senses).toHaveLength(2);
    expect(payload.details.synonyms).toContain('permit');
    const insertCall = fetcher.mock.calls.find((call) => String(call[0]).includes('/rest/v1/dictionary_entries')
      && (call[1] as RequestInit | undefined)?.method === 'POST');
    expect(String((insertCall?.[1] as RequestInit | undefined)?.body)).toContain('To authorize.');
    expect(String((insertCall?.[1] as RequestInit | undefined)?.body)).toContain('"is_published":true');
  });

  it('does not invent unknown words and does not bypass translation quota', async () => {
    const notFound = vi.fn()
      .mockResolvedValueOnce(new Response('{}', { status: 200 }))
      .mockResolvedValueOnce(new Response('[]', { status: 200 }))
      .mockResolvedValueOnce(new Response('{}', { status: 404 }));
    vi.stubGlobal('fetch', notFound);
    expect((await invoke({ word: 'notarealwordxyz' })).status).toBe(404);

    const unavailable = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      if (url.includes('/auth/v1/user')) return new Response('{}', { status: 200 });
      if (url.includes('/rest/v1/dictionary_entries') && init?.method !== 'POST') return new Response('[]', { status: 200 });
      if (url.includes('api.dictionaryapi.dev')) return new Response(JSON.stringify(dictionaryPayload), { status: 200 });
      if (url.includes('/functions/v1/translate')) return new Response('{"error":"limited"}', { status: 429 });
      throw new Error(`Unexpected request: ${url}`);
    });
    vi.stubGlobal('fetch', unavailable);
    const response = await invoke({ word: 'license' });
    expect(response.status).toBe(429);
    expect(await response.json()).toMatchObject({ error: expect.stringContaining('limit reached') });
    expect(unavailable.mock.calls.some((call) => (call[1] as RequestInit | undefined)?.method === 'POST'
      && String(call[0]).includes('/rest/v1/dictionary_entries'))).toBe(false);
  });
});
