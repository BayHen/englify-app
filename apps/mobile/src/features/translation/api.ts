import { privateRequest } from '@/auth/api';
import { getSupabase } from '@/auth/supabase';

export type Language = 'en' | 'vi';
export type TranslateRequest = { source: Language; target: Language; text: string };
export type TranslateResult = {
  status: 'translated' | 'unavailable'; source: Language; target: Language;
  source_text: string; translated_text: string | null;
  method: 'phrasebook' | 'libretranslate' | null;
  scope: 'exact_phrase' | 'full_text' | null; message: string;
};
export type Phrase = { en: string; vi: string };

async function token(): Promise<string> {
  const { data, error } = await getSupabase().auth.getSession();
  if (error || !data.session) throw new Error('Session expired. Please sign in again.');
  return data.session.access_token;
}

export async function translateText(request: TranslateRequest): Promise<TranslateResult> {
  return privateRequest<TranslateResult>('/translate', await token(), 'POST', request);
}
export async function getPhrases(): Promise<Phrase[]> {
  return privateRequest<Phrase[]>('/translation/phrases', await token());
}
