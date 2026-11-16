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

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;

function exactEnglishWord(value: string): string | null {
  return /^[a-z]+(?:['’\-][a-z]+)*$/iu.test(value) ? value.replaceAll('’', "'") : null;
}

function isDictionaryWord(value: unknown): value is DictionaryWord {
  if (!value || typeof value !== 'object') return false;
  const word = value as Record<string, unknown>;
  return UUID_PATTERN.test(String(word.id ?? ''))
    && typeof word.term === 'string' && !!word.term.trim()
    && typeof word.definition === 'string' && !!word.definition.trim()
    && (word.translation === null || typeof word.translation === 'string')
    && (word.ipa === null || typeof word.ipa === 'string')
    && (word.part_of_speech === null || typeof word.part_of_speech === 'string')
    && (word.example === null || typeof word.example === 'string')
    && (word.audio_url === null || typeof word.audio_url === 'string')
    && typeof word.source_name === 'string'
    && typeof word.license_id === 'string';
}

async function importExactWord(word: string): Promise<DictionaryWord | null> {
  const result = await getSupabase().functions.invoke('dictionary-import', { body: { word } });
  if (result.error) {
    const context = (result.error as { context?: { status?: number } }).context;
    const status = context?.status ?? 0;
    if (status === 404) return null;
    throw new ApiError(status, status === 429
      ? 'Dictionary provider limit reached. Try again later.'
      : status === 401 ? 'Session expired. Please sign in again.'
        : status === 504 ? 'Dictionary lookup timed out. Try again.'
          : 'Dictionary lookup is unavailable. Try again later.');
  }
  const payload = result.data as { word?: unknown } | null;
  if (!isDictionaryWord(payload?.word)) throw new ApiError(502, 'Dictionary returned invalid data.');
  return payload.word;
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
  const exact = exactEnglishWord(term);
  const hasExact = exact !== null && [...words.values()].some((word) => word.term.toLocaleLowerCase() === exact);
  if (exact && !hasExact) {
    const imported = await importExactWord(exact);
    if (imported) words.set(imported.id, imported);
  }
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
