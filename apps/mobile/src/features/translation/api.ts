import { ApiError } from '@/lib/api';
import { currentUserId } from '@/lib/supabase-query';
import { getSupabase } from '@/auth/supabase';

export type Language = 'en' | 'vi';
export type SourceLanguage = Language;
export type TranslateRequest = { source: SourceLanguage; target: Language; text: string };
export type TranslateResult = {
  status: 'translated' | 'unavailable'; source: Language; target: Language;
  source_text: string; translated_text: string | null;
  method: 'phrasebook' | 'libretranslate' | 'mymemory' | null;
  scope: 'exact_phrase' | 'full_text' | null; message: string;
};
type ProviderResponse = { status?: 'translated' | 'unavailable'; translatedText: string | null;
  sourceLanguage: Language; targetLanguage: Language; provider: string; message?: string };
const recent = new Map<string, { result: TranslateResult; expires: number }>();
const pendingTranslations = new Map<AbortController, string>();

export function clearAccountTranslations(userId: string) {
  const prefix = JSON.stringify(['mymemory-validated-v3', userId]).slice(0, -1) + ',';
  for (const key of recent.keys()) {
    if (key.startsWith(prefix)) recent.delete(key);
  }
  for (const [controller, owner] of pendingTranslations) {
    if (owner === userId) controller.abort();
  }
}
type HttpResponse = { status: number; clone: () => { json: () => Promise<unknown> } };
function isHttpResponse(value: unknown): value is HttpResponse {
  return typeof value === 'object' && value !== null && 'status' in value && typeof value.status === 'number'
    && 'clone' in value && typeof value.clone === 'function';
}
async function translationError(error: Error): Promise<ApiError> {
  const context = 'context' in error ? error.context : null;
  if (!isHttpResponse(context)) return new ApiError(0, 'Cannot reach Supabase. Check your connection and try again.');
  const detail = await context.clone().json().catch(() => null) as { error?: unknown; code?: unknown } | null;
  if (context.status === 404 || detail?.code === 'NOT_FOUND') {
    return new ApiError(404, 'Translation is not available yet: the Supabase translate function has not been deployed.');
  }
  if (context.status === 401) return new ApiError(401, 'Session expired. Sign in again.');
  if (context.status === 403) return new ApiError(403, 'Translation access denied.');
  if (context.status === 429) return new ApiError(429, 'Translation limit reached. Try again later.');
  return new ApiError(context.status,
    typeof detail?.error === 'string' && detail.error ? detail.error : 'Translation service error. Try again later.');
}
export function utf8ByteLength(text: string): number {
  let bytes = 0;
  for (const character of text) {
    const point = character.codePointAt(0)!;
    bytes += point <= 0x7f ? 1 : point <= 0x7ff ? 2 : point <= 0xffff ? 3 : 4;
  }
  return bytes;
}

export async function translateText(request: TranslateRequest, account?: string | null): Promise<TranslateResult> {
  const userId = account === undefined ? await currentUserId() : account;
  const text = request.text.trim();
  if (!text || utf8ByteLength(text) > 500 || !['en', 'vi'].includes(request.source)
      || !['en', 'vi'].includes(request.target) || request.source === request.target) {
    throw new ApiError(422, 'Enter a sentence of at most 500 UTF-8 bytes and choose English/Vietnamese languages.');
  }
  const cacheKey = JSON.stringify(['mymemory-validated-v3', userId, request.source, request.target, text]);
  const cached = recent.get(cacheKey);
  if (cached && cached.expires > Date.now()) return cached.result;
  const controller = new AbortController();
  if (userId) pendingTranslations.set(controller, userId);
  const timer = setTimeout(() => controller.abort(), 20000);
  let response: { data: ProviderResponse | null; error: Error | null };
  try {
    const body = { text, sourceLanguage: request.source, targetLanguage: request.target };
    if (userId) {
      response = await getSupabase().functions.invoke<ProviderResponse>('translate', { body, signal: controller.signal });
    } else {
      const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
      const key = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
      if (!url || !key) throw new ApiError(503, 'Translation service is not configured.');
      const remote = await fetch(`${url.replace(/\/$/, '')}/functions/v1/translate`, {
        method: 'POST', headers: { apikey: key, 'Content-Type': 'application/json' },
        body: JSON.stringify(body), signal: controller.signal,
      });
      if (!remote.ok) {
        if (remote.status === 401 || remote.status === 403 || remote.status >= 500 || remote.status === 404) {
          throw new ApiError(remote.status, 'Translation is temporarily unavailable.');
        }
        if (remote.status === 429) throw new ApiError(429, 'Too many requests. Please try again shortly.');
        throw await translationError(Object.assign(new Error('Guest translation failed'), { context: remote }));
      }
      response = { data: await remote.json() as ProviderResponse, error: null };
    }
  } catch (cause) {
    if (cause instanceof ApiError) throw cause;
    throw new ApiError(controller.signal.aborted ? 504 : 0,
      controller.signal.aborted ? 'Translation timed out.' : 'Unable to connect. Check your internet connection.');
  } finally {
    clearTimeout(timer);
    pendingTranslations.delete(controller);
  }
  if (controller.signal.aborted) throw new ApiError(504, 'Translation request ended.');
  const { data, error } = response;
  if (error) {
    if (controller.signal.aborted) throw new ApiError(504, 'Translation timed out.');
    throw await translationError(error);
  }
  if (!data || data.provider !== 'mymemory' || !['en', 'vi'].includes(data.sourceLanguage)
      || data.sourceLanguage !== request.source || data.targetLanguage !== request.target) {
    throw new ApiError(502, 'Translation provider returned invalid data.');
  }
  if (data.status === 'unavailable') {
    if (data.translatedText !== null) throw new ApiError(502, 'Translation provider returned invalid data.');
    const unavailable: TranslateResult = { status: 'unavailable', source: data.sourceLanguage, target: data.targetLanguage,
      source_text: text, translated_text: null, method: 'mymemory', scope: 'full_text',
      message: data.message?.trim() || 'No translation was found. Try a short phrase with more context.' };
    if (recent.size >= 100) recent.delete(recent.keys().next().value!);
    recent.set(cacheKey, { result: unavailable, expires: Date.now() + 10 * 60 * 1000 });
    return unavailable;
  }
  if (typeof data.translatedText !== 'string' || !data.translatedText.trim()) {
    throw new ApiError(502, 'Translation provider returned invalid data.');
  }
  if (data.translatedText.trim().toLocaleLowerCase() === text.toLocaleLowerCase()) {
    throw new ApiError(502, 'No distinct translation was found. Try a short phrase with more context.');
  }
  const result: TranslateResult = { status: 'translated', source: data.sourceLanguage, target: data.targetLanguage,
    source_text: text, translated_text: data.translatedText, method: 'mymemory', scope: 'full_text',
    message: 'Translation provided by MyMemory. Check important wording before use.' };
  if (recent.size >= 100) recent.delete(recent.keys().next().value!);
  recent.set(cacheKey, { result, expires: Date.now() + 60 * 60 * 1000 });
  return result;
}
