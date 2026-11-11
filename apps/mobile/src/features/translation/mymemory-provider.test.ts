import { describe, expect, it, vi } from 'vitest';
import { ProviderError, translateWithMyMemory, utf8ByteLength } from '../../../../../supabase/functions/translate/provider';

const valid = (translatedText: string) => new Response(JSON.stringify({
  responseStatus: 200, responseData: { translatedText },
}), { status: 200 });

describe('MyMemory adapter', () => {
  it('sends real English input to the fixed HTTPS endpoint', async () => {
    const fetcher = vi.fn(async () => valid('Tôi học tiếng Anh mỗi ngày.')) as unknown as typeof fetch;
    const result = await translateWithMyMemory('I learn English every day.', 'en', 'vi', fetcher);
    expect(result.translatedText).toBe('Tôi học tiếng Anh mỗi ngày.');
    const [url, init] = (fetcher as ReturnType<typeof vi.fn>).mock.calls[0];
    expect(new URL(url).origin).toBe('https://api.mymemory.translated.net');
    expect(new URL(url).searchParams.get('q')).toBe('I learn English every day.');
    expect(new URL(url).searchParams.get('langpair')).toBe('en|vi');
    expect(init.method).toBe('GET');
  });
  it('supports Vietnamese Unicode in reverse direction', async () => {
    const fetcher = vi.fn(async () => valid('Hello, how are you?')) as unknown as typeof fetch;
    await translateWithMyMemory('Xin chào, bạn khỏe không?', 'vi', 'en', fetcher);
    expect(new URL((fetcher as ReturnType<typeof vi.fn>).mock.calls[0][0]).searchParams.get('q'))
      .toBe('Xin chào, bạn khỏe không?');
  });
  it('uses a distinct matching MyMemory alternative when the primary repeats the source', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ responseStatus: 200,
      responseData: { translatedText: 'License' }, matches: [
        { segment: 'License', translation: 'License', match: 1 },
        { segment: 'License.', translation: 'Giấy phép.', match: 0.99 },
      ],
    }), { status: 200 })) as unknown as typeof fetch;
    await expect(translateWithMyMemory('License', 'en', 'vi', fetcher))
      .resolves.toEqual({ translatedText: 'Giấy phép.' });
  });
  it('capitalizes short lookup text to avoid poor case-sensitive matches', async () => {
    const fetcher = vi.fn(async () => valid('License')) as unknown as typeof fetch;
    await expect(translateWithMyMemory('giấy phép', 'vi', 'en', fetcher))
      .resolves.toEqual({ translatedText: 'License' });
    expect(new URL((fetcher as ReturnType<typeof vi.fn>).mock.calls[0][0]).searchParams.get('q'))
      .toBe('Giấy phép');
  });
  it('rejects an unchanged response without a usable alternative', async () => {
    const fetcher = vi.fn(async () => valid('License')) as unknown as typeof fetch;
    await expect(translateWithMyMemory('License', 'en', 'vi', fetcher))
      .rejects.toMatchObject({ kind: 'no_translation' });
  });
  it('rejects empty input and oversized UTF-8 without calling upstream', async () => {
    const fetcher = vi.fn() as unknown as typeof fetch;
    expect(utf8ByteLength('ế')).toBe(3);
    await expect(translateWithMyMemory(' ', 'en', 'vi', fetcher)).rejects.toMatchObject({ kind: 'invalid_input' });
    await expect(translateWithMyMemory('ế'.repeat(167), 'vi', 'en', fetcher)).rejects.toMatchObject({ kind: 'invalid_input' });
    expect(fetcher).not.toHaveBeenCalled();
  });
  it('handles HTTP and payload rate limits', async () => {
    for (const response of [new Response('{}', { status: 429 }),
      new Response('{"responseStatus":429,"quotaFinished":true}', { status: 200 })]) {
      const fetcher = vi.fn(async () => response) as unknown as typeof fetch;
      await expect(translateWithMyMemory('Hi', 'en', 'vi', fetcher)).rejects.toMatchObject({ kind: 'rate_limited' });
    }
  });
  it('handles timeout, network failure and invalid API data', async () => {
    const timeout = vi.fn(async () => { throw new DOMException('timed out', 'TimeoutError'); }) as unknown as typeof fetch;
    const offline = vi.fn(async () => { throw new TypeError('network'); }) as unknown as typeof fetch;
    await expect(translateWithMyMemory('Hi', 'en', 'vi', timeout)).rejects.toMatchObject({ kind: 'timeout' });
    await expect(translateWithMyMemory('Hi', 'en', 'vi', offline)).rejects.toMatchObject({ kind: 'upstream' });
    for (const response of [new Response('bad'), new Response('{"responseStatus":200,"responseData":{"translatedText":""}}')]) {
      const fetcher = vi.fn(async () => response) as unknown as typeof fetch;
      await expect(translateWithMyMemory('Hi', 'en', 'vi', fetcher)).rejects.toBeInstanceOf(ProviderError);
    }
  });
});
