import { readStorage, writeStorage } from '@/features/dictionary/cache-storage';
import type { TranslateResult } from './api';

const keyFor = (userId: string) => `englify.saved-translations.v1:${userId}`;
export type SavedPhrase = TranslateResult & { saved_at: string };

export async function readSavedPhrases(userId: string): Promise<SavedPhrase[]> {
  try {
    const raw = await readStorage(keyFor(userId));
    if (!raw) return [];
    const parsed: unknown = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((item): item is SavedPhrase =>
      typeof item === 'object' && item !== null && typeof item.source_text === 'string' && typeof item.translated_text === 'string' && typeof item.saved_at === 'string') : [];
  } catch { return []; }
}

export async function savePhrase(userId: string, result: TranslateResult): Promise<SavedPhrase[]> {
  if (result.status !== 'translated' || !result.translated_text) throw new Error('Only available translations can be saved.');
  const previous = await readSavedPhrases(userId);
  const next = [{ ...result, saved_at: new Date().toISOString() }, ...previous.filter((item) =>
    !(item.source === result.source && item.target === result.target && item.source_text === result.source_text))].slice(0, 100);
  await writeStorage(keyFor(userId), JSON.stringify(next));
  return next;
}
