/** Tatoeba v1 sentence search. No sentence is publishable without both licenses. */
export type ReferencePair = {
  englishId: number;
  vietnameseId: number;
  englishText: string;
  vietnameseText: string;
  englishContributor: string | null;
  vietnameseContributor: string | null;
  englishLicense: string | null;
  vietnameseLicense: string | null;
  sourceUrl: string;
  translationUrl: string;
  validationStatus: 'eligible' | 'blocked_license';
  validationReason: string | null;
};

export type ReferencePage = { pairs: ReferencePair[]; next: string | null; hasNext: boolean };
export class TatoebaError extends Error {
  constructor(public readonly kind: 'network' | 'timeout' | 'rate_limited' | 'invalid_response' | 'upstream', message: string) {
    super(message);
  }
}

type Sentence = { id?: unknown; text?: unknown; lang?: unknown; owner?: unknown;
  license?: unknown; is_unapproved?: unknown; is_direct?: unknown; translations?: unknown };
const allowedLicense = new Set(['CC0 1.0', 'CC BY 2.0 FR']);
const cache = new Map<string, { value: ReferencePage; expires: number }>();
const isObject = (value: unknown): value is Record<string, unknown> => !!value && typeof value === 'object' && !Array.isArray(value);
const validId = (value: unknown): value is number => Number.isSafeInteger(value) && Number(value) > 0;
const textValue = (value: unknown): string | null => typeof value === 'string' && value.trim() ? value.trim() : null;
const sourceUrl = (id: number) => `https://api.tatoeba.org/v1/sentences/${id}`;

export function buildTatoebaUrl(keyword: string, limit = 20, after?: string): string {
  if (!keyword.trim() || keyword.length > 80 || !Number.isInteger(limit) || limit < 1 || limit > 50) {
    throw new TatoebaError('invalid_response', 'Invalid Tatoeba search parameters.');
  }
  const url = new URL('https://api.tatoeba.org/v1/sentences');
  url.searchParams.set('lang', 'eng');
  url.searchParams.set('q', keyword.trim());
  url.searchParams.set('trans:lang', 'vie');
  url.searchParams.set('trans:is_direct', 'yes');
  url.searchParams.set('showtrans', 'matching');
  url.searchParams.set('sort', 'relevance');
  url.searchParams.set('limit', String(limit));
  if (after) {
    if (!/^[\w,.-]{1,120}$/.test(after)) throw new TatoebaError('invalid_response', 'Invalid Tatoeba cursor.');
    url.searchParams.set('after', after);
  }
  return url.toString();
}

function pairOf(english: Sentence, vietnamese: Sentence): ReferencePair | null {
  if (!validId(english.id) || !validId(vietnamese.id) || english.lang !== 'eng'
    || vietnamese.lang !== 'vie' || vietnamese.is_direct !== true) return null;
  const englishText = textValue(english.text);
  const vietnameseText = textValue(vietnamese.text);
  if (!englishText || !vietnameseText || englishText.length > 500 || vietnameseText.length > 500) return null;
  const englishContributor = textValue(english.owner);
  const vietnameseContributor = textValue(vietnamese.owner);
  const englishLicense = textValue(english.license);
  const vietnameseLicense = textValue(vietnamese.license);
  const licensed = allowedLicense.has(englishLicense ?? '') && allowedLicense.has(vietnameseLicense ?? '')
    && (englishLicense === 'CC0 1.0' || !!englishContributor)
    && (vietnameseLicense === 'CC0 1.0' || !!vietnameseContributor)
    && english.is_unapproved === false && vietnamese.is_unapproved === false;
  return { englishId: english.id, vietnameseId: vietnamese.id, englishText, vietnameseText,
    englishContributor, vietnameseContributor, englishLicense, vietnameseLicense,
    sourceUrl: sourceUrl(english.id), translationUrl: sourceUrl(vietnamese.id),
    validationStatus: licensed ? 'eligible' : 'blocked_license',
    validationReason: licensed ? null : 'License, contributor, or approval metadata is missing or incompatible.' };
}

export function parseTatoebaPage(value: unknown): ReferencePage {
  if (!isObject(value) || !Array.isArray(value.data) || !isObject(value.paging)
    || typeof value.paging.has_next !== 'boolean') {
    throw new TatoebaError('invalid_response', 'Tatoeba response does not match API v1.');
  }
  const pairs = new Map<string, ReferencePair>();
  for (const item of value.data) {
    if (!isObject(item) || !Array.isArray(item.translations)) {
      throw new TatoebaError('invalid_response', 'Tatoeba sentence metadata is malformed.');
    }
    for (const translation of item.translations) {
      if (!isObject(translation)) continue;
      const pair = pairOf(item, translation);
      if (pair) pairs.set(`${pair.englishId}:${pair.vietnameseId}`, pair);
    }
  }
  const next = value.paging.next;
  let nextUrl: string | null = null;
  if (value.paging.has_next) {
    if (typeof next !== 'string') throw new TatoebaError('invalid_response', 'Tatoeba pagination is invalid.');
    try {
      const parsed = new URL(next);
      if (parsed.origin !== 'https://api.tatoeba.org' || parsed.pathname !== '/v1/sentences') throw new Error();
      nextUrl = parsed.toString();
    } catch { throw new TatoebaError('invalid_response', 'Tatoeba pagination URL is unsafe.'); }
  }
  return { pairs: [...pairs.values()], next: nextUrl, hasNext: value.paging.has_next };
}

export async function searchTatoeba(keyword: string, options: {
  limit?: number; after?: string; fetcher?: typeof fetch;
} = {}): Promise<ReferencePage> {
  const url = buildTatoebaUrl(keyword, options.limit, options.after);
  const cached = cache.get(url);
  if (cached && cached.expires > Date.now()) return cached.value;
  const fetcher = options.fetcher ?? fetch;
  for (let attempt = 0; attempt < 2; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 30000);
    try {
      const response = await fetcher(url, { signal: controller.signal, headers: { Accept: 'application/json' } });
      if (response.status === 429) throw new TatoebaError('rate_limited', 'Tatoeba rate limit reached.');
      if (!response.ok) {
        if (response.status >= 500 && attempt === 0) continue;
        throw new TatoebaError('upstream', 'Tatoeba request failed.');
      }
      let body: unknown;
      try { body = await response.json(); }
      catch { throw new TatoebaError('invalid_response', 'Tatoeba returned invalid JSON.'); }
      const page = parseTatoebaPage(body);
      if (cache.size >= 100) cache.delete(cache.keys().next().value!);
      cache.set(url, { value: page, expires: Date.now() + 10 * 60 * 1000 });
      return page;
    } catch (cause) {
      if (cause instanceof TatoebaError) throw cause;
      if (controller.signal.aborted) throw new TatoebaError('timeout', 'Tatoeba request timed out.');
      if (attempt === 1) throw new TatoebaError('network', 'Tatoeba is unreachable.');
    } finally { clearTimeout(timer); }
  }
  throw new TatoebaError('network', 'Tatoeba is unreachable.');
}
