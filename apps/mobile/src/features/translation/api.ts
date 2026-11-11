import { currentUserId } from '@/lib/supabase-query';
import { ApiError } from '@/lib/api';
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
type ProviderResponse = { translatedText: string; sourceLanguage: Language; targetLanguage: Language; provider: string };
const recent = new Map<string, { result: TranslateResult; expires: number }>();
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

export async function translateText(request: TranslateRequest): Promise<TranslateResult> {
  const userId = await currentUserId();
  const text = request.text.trim();
  if (!text || utf8ByteLength(text) > 500 || !['en', 'vi'].includes(request.source)
      || !['en', 'vi'].includes(request.target) || request.source === request.target) {
    throw new ApiError(422, 'Enter a sentence of at most 500 UTF-8 bytes and choose English/Vietnamese languages.');
  }
  const cacheKey = JSON.stringify(['mymemory-validated-v2', userId, request.source, request.target, text]);
  const cached = recent.get(cacheKey);
  if (cached && cached.expires > Date.now()) return cached.result;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 20000);
  let response: { data: ProviderResponse | null; error: Error | null };
  try {
    response = await getSupabase().functions.invoke<ProviderResponse>('translate', {
      body: { text, sourceLanguage: request.source, targetLanguage: request.target }, signal: controller.signal,
    });
  } catch {
    throw new ApiError(controller.signal.aborted ? 504 : 0,
      controller.signal.aborted ? 'Translation timed out.' : 'Cannot reach the translation service.');
  } finally { clearTimeout(timer); }
  const { data, error } = response;
  if (error) {
    if (controller.signal.aborted) throw new ApiError(504, 'Translation timed out.');
    throw await translationError(error);
  }
  if (!data || data.provider !== 'mymemory' || typeof data.translatedText !== 'string'
      || !data.translatedText.trim() || !['en', 'vi'].includes(data.sourceLanguage) || data.targetLanguage !== request.target) {
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
