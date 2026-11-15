export type TranslationLanguage = 'en' | 'vi';
export type ProviderTranslation = { translatedText: string };

export class ProviderError extends Error {
  constructor(public readonly kind: 'timeout' | 'rate_limited' | 'upstream' | 'invalid_input' | 'no_translation', message: string) {
    super(message);
  }
}

export function utf8ByteLength(text: string): number {
  return new TextEncoder().encode(text).length;
}

function comparable(text: string): string {
  return text.trim().replace(/^[\s\p{P}]+|[\s\p{P}]+$/gu, '').toLocaleLowerCase();
}

function lookupText(text: string): string {
  if (text.trim().split(/\s+/u).length > 3) return text;
  const normalized = text[0].toUpperCase() + text.slice(1);
  return utf8ByteLength(normalized) <= 500 ? normalized : text;
}

export async function translateWithMyMemory(
  text: string, source: TranslationLanguage, target: TranslationLanguage,
  fetcher: typeof fetch = fetch,
): Promise<ProviderTranslation> {
  if (!text.trim() || utf8ByteLength(text) > 500 || source === target) {
    throw new ProviderError('invalid_input', 'Enter a sentence of at most 500 UTF-8 bytes and choose two languages.');
  }
  const url = new URL('https://api.mymemory.translated.net/get');
  url.searchParams.set('q', lookupText(text));
  url.searchParams.set('langpair', `${source}|${target}`);
  let response: Response;
  try {
    response = await fetcher(url, { method: 'GET', signal: AbortSignal.timeout(8000) });
  } catch (cause) {
    throw new ProviderError(cause instanceof Error && ['TimeoutError', 'AbortError'].includes(cause.name) ? 'timeout' : 'upstream',
      'Translation service could not be reached.');
  }
  if (response.status === 429 || response.status === 403) throw new ProviderError('rate_limited', 'MyMemory daily limit reached.');
  if (!response.ok) throw new ProviderError('upstream', 'MyMemory returned an error.');
  let body: unknown;
  try { body = await response.json(); }
  catch { throw new ProviderError('upstream', 'MyMemory returned invalid data.'); }
  if (!body || typeof body !== 'object') throw new ProviderError('upstream', 'MyMemory returned invalid data.');
  const result = body as { responseStatus?: unknown; responseData?: { translatedText?: unknown };
    quotaFinished?: unknown; matches?: { segment?: unknown; translation?: unknown; match?: unknown }[] };
  if (result.quotaFinished === true || Number(result.responseStatus) === 429 || Number(result.responseStatus) === 403) {
    throw new ProviderError('rate_limited', 'MyMemory daily limit reached.');
  }
  if (Number(result.responseStatus) !== 200 || typeof result.responseData?.translatedText !== 'string'
      || !result.responseData.translatedText.trim()) {
    throw new ProviderError('upstream', 'MyMemory returned no valid translation.');
  }
  const primary = result.responseData.translatedText.trim();
  if (comparable(primary) !== comparable(text)) return { translatedText: primary };
  const alternative = Array.isArray(result.matches) ? result.matches.find((entry) =>
    typeof entry.segment === 'string' && comparable(entry.segment) === comparable(text)
    && typeof entry.translation === 'string' && comparable(entry.translation) !== comparable(text)
    && Number(entry.match) >= 0.98) : undefined;
  if (alternative && typeof alternative.translation === 'string') {
    return { translatedText: alternative.translation.trim() };
  }
  throw new ProviderError('no_translation', 'MyMemory did not provide a distinct translation.');
}
