import { beforeEach, describe, expect, it, vi } from 'vitest';
import { readSavedPhrases, savePhrase } from './saved';
import type { TranslateResult } from './api';
import type { DictionaryDetails } from './dictionary';

const storage = vi.hoisted(() => new Map<string, string>());
vi.mock('@/features/dictionary/cache-storage', () => ({
  readStorage: async (key: string) => storage.get(key) ?? null,
  writeStorage: async (key: string, value: string) => { storage.set(key, value); },
}));
beforeEach(() => storage.clear());

const result: TranslateResult = {
  status: 'translated', source: 'en', target: 'vi', source_text: 'License',
  translated_text: 'Giấy phép.', method: 'mymemory', scope: 'full_text', message: '',
};

describe('saved translation compatibility', () => {
  it('reads old entries and adds optional dictionary fields without deleting history', async () => {
    const key = 'englify.saved-translations.v1:user-1';
    storage.set(key, JSON.stringify([{ ...result, source_text: 'Old sentence', saved_at: '2025-01-01T00:00:00Z' }]));
    const dictionary: DictionaryDetails = {
      word: 'license', ipa: '/ˈlaɪsəns/', audioUrl: 'https://example.com/license.mp3',
      senses: [{ partOfSpeech: 'noun', definition: 'A permit.', example: null }],
      synonyms: [], antonyms: [], licenseName: null, licenseUrl: null, sourceUrl: null,
    };
    const saved = await savePhrase('user-1', result, dictionary);
    expect(saved).toHaveLength(2);
    expect(saved[0]).toMatchObject({ ipa: '/ˈlaɪsəns/', part_of_speech: 'noun',
      audio_url: 'https://example.com/license.mp3' });
    expect(saved[1]).toMatchObject({ source_text: 'Old sentence' });
    expect(await readSavedPhrases('user-1')).toEqual(saved);
  });
  it('keeps data separate by user and rejects unavailable translations', async () => {
    await savePhrase('user-1', result);
    expect(await readSavedPhrases('user-2')).toEqual([]);
    await expect(savePhrase('user-1', { ...result, translated_text: null })).rejects.toThrow();
  });
});
