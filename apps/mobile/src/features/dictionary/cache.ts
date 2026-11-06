import { readStorage, writeStorage } from './cache-storage';
import { filterCachedWords, type DictionaryWord, type SavedWord } from './types';

const CACHE_VERSION = 1;
const wordsKey = `dictionary:v${CACHE_VERSION}:words`;
const savedKey = (userId: string) => `dictionary:v${CACHE_VERSION}:saved:${userId}`;
const recentKey = (userId: string) => `dictionary:v${CACHE_VERSION}:recent:${userId}`;

async function readArray<T>(key: string): Promise<T[]> {
  const value = await readStorage(key);
  if (!value) return [];
  try { const parsed: unknown = JSON.parse(value); return Array.isArray(parsed) ? parsed as T[] : []; }
  catch { return []; }
}

export async function cacheWords(words: DictionaryWord[]): Promise<void> {
  const current = await readArray<DictionaryWord>(wordsKey);
  const merged = new Map(current.map((word) => [word.id, word]));
  words.forEach((word) => merged.set(word.id, word));
  await writeStorage(wordsKey, JSON.stringify(Array.from(merged.values()).slice(-500)));
}
export async function searchCachedWords(query: string): Promise<DictionaryWord[]> {
  return filterCachedWords(await readArray<DictionaryWord>(wordsKey), query);
}
export async function cacheSavedWords(userId: string, words: SavedWord[]): Promise<void> {
  await writeStorage(savedKey(userId), JSON.stringify(words.slice(0, 200)));
  await cacheWords(words.map((saved) => saved.word));
}
export async function getCachedSavedWords(userId: string): Promise<SavedWord[]> {
  return readArray<SavedWord>(savedKey(userId));
}
export async function rememberSearch(userId: string, term: string): Promise<void> {
  const value = term.trim();
  if (!value) return;
  const current = await readArray<string>(recentKey(userId));
  await writeStorage(recentKey(userId), JSON.stringify([value, ...current.filter((item) => item.toLocaleLowerCase() !== value.toLocaleLowerCase())].slice(0, 12)));
}
export async function getRecentSearches(userId: string): Promise<string[]> {
  return readArray<string>(recentKey(userId));
}
