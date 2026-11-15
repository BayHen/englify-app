import { beforeEach, describe, expect, it, vi } from 'vitest';
import { translateText } from './api';

const state = vi.hoisted(() => ({ client: null as unknown }));
vi.mock('@/auth/supabase', () => ({ getSupabase: () => state.client }));
const session = { data: { session: { user: { id: 'user-1' } } }, error: null };
function withInvoke(invoke: ReturnType<typeof vi.fn>) {
  state.client = { auth: { getSession: async () => session }, functions: { invoke } };
}
beforeEach(() => { state.client = null; });

describe('translation mobile integration', () => {
  it('sends arbitrary text to the Supabase function and uses only its response', async () => {
    const invoke = vi.fn().mockResolvedValue({ data: {
      translatedText: 'Một bản dịch trả về từ API', sourceLanguage: 'en', targetLanguage: 'vi',
      provider: 'mymemory',
    }, error: null });
    withInvoke(invoke);
    const result = await translateText({ source: 'en', target: 'vi', text: 'An unseen sentence.' });
    expect(result.translated_text).toBe('Một bản dịch trả về từ API');
    expect(result.scope).toBe('full_text');
    expect(invoke).toHaveBeenCalledWith('translate', { body: {
      text: 'An unseen sentence.', sourceLanguage: 'en', targetLanguage: 'vi',
    }, signal: expect.any(AbortSignal) });
    await translateText({ source: 'en', target: 'vi', text: 'An unseen sentence.' });
    expect(invoke).toHaveBeenCalledTimes(1);
  });
  it('supports Vietnamese-to-English from the verified provider response', async () => {
    const invoke = vi.fn().mockResolvedValue({ data: {
      translatedText: 'Hello', sourceLanguage: 'vi', targetLanguage: 'en', provider: 'mymemory',
    }, error: null });
    withInvoke(invoke);
    await expect(translateText({ source: 'vi', target: 'en', text: 'Xin chào' })).resolves.toMatchObject({ source: 'vi', target: 'en' });
  });
  it('does not disguise expired sessions as translations', async () => {
    const invoke = vi.fn().mockResolvedValue({ data: null, error: { context: new Response('{"error":"Session expired"}', { status: 401 }) } });
    withInvoke(invoke);
    await expect(translateText({ source: 'en', target: 'vi', text: 'Hello.' })).rejects.toMatchObject({ status: 401 });
  });
  it('surfaces provider rate limits and network failure without cached translations', async () => {
    const invoke = vi.fn().mockResolvedValueOnce({ data: null, error: {
      context: new Response('{"error":"Translation provider daily limit reached."}', { status: 429 }),
    } }).mockRejectedValueOnce(new TypeError('offline'));
    withInvoke(invoke);
    await expect(translateText({ source: 'en', target: 'vi', text: 'A unique sentence for quota.' }))
      .rejects.toMatchObject({ status: 429 });
    await expect(translateText({ source: 'en', target: 'vi', text: 'A unique sentence for offline.' }))
      .rejects.toMatchObject({ status: 0 });
  });
  it('identifies a missing deployed Edge Function from the gateway response', async () => {
    const invoke = vi.fn().mockResolvedValue({ data: null, error: {
      context: new Response('{"code":"NOT_FOUND","message":"Function not found"}', { status: 404 }),
    } });
    withInvoke(invoke);
    await expect(translateText({ source: 'en', target: 'vi', text: 'A missing function example.' }))
      .rejects.toMatchObject({ status: 404,
        message: 'Translation is not available yet: the Supabase translate function has not been deployed.' });
  });
  it('does not present unchanged upstream text as a translated result', async () => {
    const invoke = vi.fn().mockResolvedValue({ data: {
      translatedText: 'License', sourceLanguage: 'en', targetLanguage: 'vi', provider: 'mymemory',
    }, error: null });
    withInvoke(invoke);
    await expect(translateText({ source: 'en', target: 'vi', text: 'License' }))
      .rejects.toMatchObject({ status: 502 });
  });
  it('reports missing provider configuration for both known and new text', async () => {
    const invoke = vi.fn().mockResolvedValue({ data: null, error: { context: new Response('{"error":"Unavailable"}', { status: 503 }) } });
    withInvoke(invoke);
    await expect(translateText({ source: 'en', target: 'vi', text: 'Hello.' })).rejects.toMatchObject({ status: 503 });
    await expect(translateText({ source: 'en', target: 'vi', text: 'A new sentence.' })).rejects.toMatchObject({ status: 503 });
  });
  it('rejects blank, long, and same-language requests before invoking provider', async () => {
    const invoke = vi.fn(); withInvoke(invoke);
    for (const value of [
      { source: 'en' as const, target: 'vi' as const, text: '   ' },
      { source: 'en' as const, target: 'vi' as const, text: 'x'.repeat(2001) },
      { source: 'vi' as const, target: 'en' as const, text: 'ế'.repeat(167) },
      { source: 'vi' as const, target: 'vi' as const, text: 'Xin chào' },
    ]) await expect(translateText(value)).rejects.toMatchObject({ status: 422 });
    expect(invoke).not.toHaveBeenCalled();
  });
});
