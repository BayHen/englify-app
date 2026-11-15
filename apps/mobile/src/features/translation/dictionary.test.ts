import { describe, expect, it, vi } from 'vitest';
import { englishLookupWord, lookupEnglishWord, parseDictionaryResponse } from './dictionary';

const example = [{
  word: 'license', phonetics: [{ text: '/ˈlaɪsəns/', audio: '//ssl.gstatic.com/dictionary/license.mp3' }],
  meanings: [
    { partOfSpeech: 'noun', definitions: [{ definition: 'An official permit.', example: 'She has a license.',
      synonyms: ['permit'], antonyms: ['ban'] }] },
    { partOfSpeech: 'verb', definitions: [{ definition: 'To authorize.', synonyms: ['permit'] }] },
  ],
  license: { name: 'CC BY-SA 3.0', url: 'https://creativecommons.org/licenses/by-sa/3.0' },
  sourceUrls: ['https://en.wiktionary.org/wiki/license'],
}];

describe('Free Dictionary API adapter', () => {
  it('only looks up a single English word', () => {
    expect(englishLookupWord('License.')).toBe('License');
    expect(englishLookupWord('hello world')).toBeNull();
    expect(englishLookupWord('giấy phép')).toBeNull();
  });
  it('parses IPA, secure audio, senses, examples, related words and attribution', () => {
    expect(parseDictionaryResponse(example)).toMatchObject({
      word: 'license', ipa: '/ˈlaɪsəns/',
      audioUrl: 'https://ssl.gstatic.com/dictionary/license.mp3',
      senses: [{ partOfSpeech: 'noun', definition: 'An official permit.', example: 'She has a license.' },
        { partOfSpeech: 'verb', definition: 'To authorize.', example: null }],
      synonyms: ['permit'], antonyms: ['ban'],
      licenseName: 'CC BY-SA 3.0', sourceUrl: 'https://en.wiktionary.org/wiki/license',
    });
  });
  it('omits missing fields and refuses insecure audio URLs', () => {
    expect(parseDictionaryResponse([{ word: 'sparse', phonetics: [{ audio: 'http://example.com/file.mp3' }],
      meanings: [{ definitions: [{ definition: 'Limited information.' }] }] }])).toMatchObject({
        ipa: null, audioUrl: null, senses: [{ definition: 'Limited information.', example: null }],
        synonyms: [], antonyms: [],
      });
    expect(parseDictionaryResponse({ error: 'bad payload' })).toBeNull();
  });
  it('uses actual encoded input, caches repeats, and treats 404 as missing details', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify(example), { status: 200 })) as unknown as typeof fetch;
    const first = await lookupEnglishWord('license', fetcher);
    const second = await lookupEnglishWord('license', fetcher);
    expect(first?.word).toBe('license');
    expect(second).toEqual(first);
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(String((fetcher as ReturnType<typeof vi.fn>).mock.calls[0][0]))
      .toBe('https://api.dictionaryapi.dev/api/v2/entries/en/license');
    const missing = vi.fn(async () => new Response('{}', { status: 404 })) as unknown as typeof fetch;
    expect(await lookupEnglishWord('nonexistentwordxyz', missing)).toBeNull();
  });
  it('does not turn network or malformed data into invented definitions', async () => {
    const offline = vi.fn(async () => { throw new TypeError('offline'); }) as unknown as typeof fetch;
    const malformed = vi.fn(async () => new Response('{"error":"bad"}', { status: 200 })) as unknown as typeof fetch;
    await expect(lookupEnglishWord('freshwordalpha', offline)).rejects.toThrow('Dictionary lookup is unavailable');
    await expect(lookupEnglishWord('freshwordbeta', malformed)).rejects.toThrow('Dictionary returned invalid data');
  });
});
