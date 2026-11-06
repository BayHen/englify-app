import { describe, expect, it, vi } from 'vitest';
import type { DictionaryWord, SavedWord } from './types';
import { cacheSavedWords, cacheWords, getCachedSavedWords, getRecentSearches, rememberSearch, searchCachedWords } from './cache';

const mockStore = vi.hoisted(() => new Map<string, string>());
vi.mock('./cache-storage', () => ({
  readStorage: async (key: string) => mockStore.get(key) ?? null,
  writeStorage: async (key: string, value: string) => { mockStore.set(key, value); },
}));

const word = {
  id: 'cache-test-word', term: 'curious', translation: 'tò mò', definition: 'Eager to learn.',
  ipa: '/ˈkjʊriəs/', part_of_speech: 'adjective', example: 'A curious learner.',
  audio_url: null, source_name: 'Englify Quest editorial', license_id: 'project-owned',
} satisfies DictionaryWord;

describe('dictionary offline cache', () => {
  it('keeps a searched word available without a network request', async () => {
    await cacheWords([word]);
    expect((await searchCachedWords('CUR')).map((item) => item.id)).toContain(word.id);
  });
  it('keeps saved decks and recent terms scoped by user', async () => {
    const saved: SavedWord = { id: 'saved-test', word, created_at: '2026-01-01T00:00:00Z', next_review_at: null };
    await cacheSavedWords('cache-user-a', [saved]);
    await rememberSearch('cache-user-a', 'curious');
    await rememberSearch('cache-user-a', 'CURIOUS');
    expect(await getCachedSavedWords('cache-user-a')).toEqual([saved]);
    expect(await getCachedSavedWords('cache-user-b')).toEqual([]);
    expect(await getRecentSearches('cache-user-a')).toEqual(['CURIOUS']);
    expect(await getRecentSearches('cache-user-b')).toEqual([]);
  });
});
