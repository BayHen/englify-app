import { getSupabase } from '@/auth/supabase';
import { ApiError } from '@/lib/api';
import { currentUserId, dataOrThrow, errorOrThrow } from '@/lib/supabase-query';
import type { DictionaryWord, SavedWord } from './types';

const WORD_COLUMNS = 'id,term,definition,translation,ipa,part_of_speech,example,audio_url,source_name,license_id';

function publishedWords() {
  return getSupabase().from('dictionary_entries').select(WORD_COLUMNS)
    .eq('language', 'en').eq('is_published', true).is('archived_at', null);
}

function escapeLike(value: string): string {
  return value.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
}

export async function searchDictionary(query: string): Promise<DictionaryWord[]> {
  await currentUserId();
  const term = query.trim().toLocaleLowerCase();
  if (term.length > 80) throw new ApiError(422, 'Search term is too long.');
  if (!term) return dataOrThrow(await publishedWords().order('normalized_term').limit(50)) as DictionaryWord[];
  const pattern = escapeLike(term);
  // Separate filters avoid interpolating user text into a PostgREST `or` expression.
  const [byTerm, byTranslation] = await Promise.all([
    publishedWords().ilike('normalized_term', `${pattern}%`).order('normalized_term').limit(50),
    publishedWords().ilike('translation', `%${pattern}%`).order('normalized_term').limit(50),
  ]);
  const words = new Map<string, DictionaryWord>();
  for (const word of [...dataOrThrow(byTerm), ...dataOrThrow(byTranslation)] as DictionaryWord[]) words.set(word.id, word);
  return [...words.values()].sort((a, b) => a.term.localeCompare(b.term)).slice(0, 50);
}
export async function listSavedWords(): Promise<SavedWord[]> {
  const userId = await currentUserId();
  const saved = dataOrThrow(await getSupabase().from('saved_vocabulary')
    .select('id,entry_id,created_at,next_review_at').eq('user_id', userId)
    .order('created_at', { ascending: false }).limit(200));
  if (!saved.length) return [];
  const words = dataOrThrow(await publishedWords().in('id', saved.map((row) => row.entry_id)));
  const byId = new Map(words.map((word) => [word.id, word as DictionaryWord]));
  return saved.flatMap((row) => {
    const word = byId.get(row.entry_id);
    return word ? [{ id: row.id, word, created_at: row.created_at, next_review_at: row.next_review_at }] : [];
  });
}
export async function saveWord(id: string, _accessToken?: string): Promise<SavedWord> {
  const userId = await currentUserId();
  const word = dataOrThrow<DictionaryWord>(await publishedWords().eq('id', id).maybeSingle());
  const inserted = await getSupabase().from('saved_vocabulary')
    .upsert({ user_id: userId, entry_id: id, note: '' }, { onConflict: 'user_id,entry_id', ignoreDuplicates: true });
  errorOrThrow(inserted);
  const saved = dataOrThrow<{ id: string; created_at: string; next_review_at: string | null }>(await getSupabase().from('saved_vocabulary')
    .select('id,created_at,next_review_at').eq('user_id', userId).eq('entry_id', id).single());
  return { id: saved.id, word, created_at: saved.created_at, next_review_at: saved.next_review_at };
}
export async function removeSavedWord(id: string): Promise<void> {
  const userId = await currentUserId();
  errorOrThrow(await getSupabase().from('saved_vocabulary').delete().eq('user_id', userId).eq('entry_id', id));
}
