import { privateRequest } from '@/auth/api';
import { getSupabase } from '@/auth/supabase';
import type { DictionaryWord, SavedWord } from './types';

async function token(): Promise<string> {
  const { data, error } = await getSupabase().auth.getSession();
  if (error || !data.session) throw new Error('Session expired. Please sign in again.');
  return data.session.access_token;
}

export async function searchDictionary(query: string): Promise<DictionaryWord[]> {
  const params = new URLSearchParams({ q: query.trim(), limit: '50' });
  return privateRequest<DictionaryWord[]>(`/dictionary?${params}`, await token());
}
export async function listSavedWords(): Promise<SavedWord[]> {
  return privateRequest<SavedWord[]>('/me/vocabulary', await token());
}
export async function saveWord(id: string): Promise<SavedWord> {
  return privateRequest<SavedWord>(`/me/vocabulary/${encodeURIComponent(id)}`, await token(), 'POST');
}
export async function removeSavedWord(id: string): Promise<void> {
  await privateRequest<{ removed: boolean }>(`/me/vocabulary/${encodeURIComponent(id)}`, await token(), 'DELETE');
}
