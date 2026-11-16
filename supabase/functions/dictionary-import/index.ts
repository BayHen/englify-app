declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (request: Request) => Promise<Response>): void;
};

type DictionarySense = { partOfSpeech: string; definition: string; example: string | null };
type DictionaryDetails = {
  word: string;
  ipa: string | null;
  audioUrl: string | null;
  senses: DictionarySense[];
  synonyms: string[];
  antonyms: string[];
  licenseName: string | null;
  licenseUrl: string | null;
  sourceUrl: string | null;
};
type DictionaryRow = {
  id: string; term: string; definition: string; translation: string | null; ipa: string | null;
  part_of_speech: string | null; example: string | null; audio_url: string | null;
  source_name: string; license_id: string; is_published?: boolean; archived_at?: string | null;
};
type RawDefinition = { definition?: unknown; example?: unknown; synonyms?: unknown; antonyms?: unknown };
type RawMeaning = { partOfSpeech?: unknown; definitions?: unknown; synonyms?: unknown; antonyms?: unknown };
type RawEntry = {
  word?: unknown; phonetic?: unknown; phonetics?: unknown; meanings?: unknown;
  license?: { name?: unknown; url?: unknown }; sourceUrls?: unknown;
};

const WORD_COLUMNS = 'id,term,definition,translation,ipa,part_of_speech,example,audio_url,source_name,license_id,is_published,archived_at';
const json = (value: unknown, status = 200, origin?: string) => new Response(JSON.stringify(value), {
  status,
  headers: {
    'Content-Type': 'application/json; charset=utf-8',
    'Vary': 'Origin',
    ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}),
  },
});

function publicKey(): string | null {
  const direct = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  if (direct) return direct;
  try {
    const keys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}') as Record<string, string>;
    return keys.default ?? Object.values(keys)[0] ?? null;
  } catch { return null; }
}

function normalizeWord(value: string): string {
  return value.trim().toLocaleLowerCase('en-US');
}

function exactEnglishWord(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const word = normalizeWord(value);
  return word.length <= 80 && /^[a-z]+(?:['-][a-z]+)*$/iu.test(word) ? word : null;
}

function httpsUrl(value: unknown): string | null {
  if (typeof value !== 'string' || !value || value.length > 1000) return null;
  try {
    const url = new URL(value.startsWith('//') ? `https:${value}` : value);
    if (url.protocol !== 'https:' || url.username || url.password || !url.hostname.includes('.')) return null;
    return url.toString();
  } catch { return null; }
}

function words(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string' && !!item.trim())
    .map((item) => item.trim()) : [];
}

export function parseDictionaryResponse(value: unknown): DictionaryDetails | null {
  if (!Array.isArray(value)) return null;
  const entry = value.find((item): item is RawEntry =>
    !!item && typeof item === 'object' && typeof item.word === 'string' && Array.isArray(item.meanings));
  if (!entry) return null;
  const phonetics = Array.isArray(entry.phonetics) ? entry.phonetics.filter((item): item is { text?: unknown; audio?: unknown } =>
    !!item && typeof item === 'object') : [];
  const meanings = (entry.meanings as unknown[]).filter((item): item is RawMeaning =>
    !!item && typeof item === 'object' && Array.isArray((item as RawMeaning).definitions));
  const senses: DictionarySense[] = [];
  const synonyms: string[] = [];
  const antonyms: string[] = [];
  for (const meaning of meanings) {
    const partOfSpeech = typeof meaning.partOfSpeech === 'string' ? meaning.partOfSpeech.trim() : '';
    synonyms.push(...words(meaning.synonyms));
    antonyms.push(...words(meaning.antonyms));
    for (const definition of meaning.definitions as RawDefinition[]) {
      if (!definition || typeof definition !== 'object') continue;
      synonyms.push(...words(definition.synonyms));
      antonyms.push(...words(definition.antonyms));
      if (typeof definition.definition === 'string' && definition.definition.trim()) {
        senses.push({
          partOfSpeech,
          definition: definition.definition.trim(),
          example: typeof definition.example === 'string' && definition.example.trim() ? definition.example.trim() : null,
        });
      }
    }
  }
  if (!senses.length) return null;
  const selected = senses.slice(0, 3);
  if (!selected.some((sense) => sense.example)) {
    const withExample = senses.find((sense) => !!sense.example);
    if (withExample && !selected.includes(withExample)) selected[Math.min(2, selected.length)] = withExample;
  }
  const unique = (list: string[]) => [...new Set(list)].slice(0, 8);
  return {
    word: (entry.word as string).trim(),
    ipa: typeof entry.phonetic === 'string' && entry.phonetic.trim() ? entry.phonetic.trim()
      : phonetics.map((item) => item.text).find((item): item is string => typeof item === 'string' && !!item.trim()) ?? null,
    audioUrl: phonetics.map((item) => httpsUrl(item.audio)).find((item): item is string => !!item) ?? null,
    senses: selected,
    synonyms: unique(synonyms),
    antonyms: unique(antonyms),
    licenseName: typeof entry.license?.name === 'string' && entry.license.name.trim() ? entry.license.name.trim() : null,
    licenseUrl: httpsUrl(entry.license?.url),
    sourceUrl: Array.isArray(entry.sourceUrls) ? entry.sourceUrls.map(httpsUrl).find(Boolean) ?? null : null,
  };
}

function restHeaders(key: string): Record<string, string> {
  return { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
}

function entryUrl(supabaseUrl: string, normalized: string): URL {
  const url = new URL(`${supabaseUrl}/rest/v1/dictionary_entries`);
  url.searchParams.set('select', WORD_COLUMNS);
  url.searchParams.set('language', 'eq.en');
  url.searchParams.set('normalized_term', `eq.${normalized}`);
  url.searchParams.set('limit', '1');
  return url;
}

async function findExisting(supabaseUrl: string, serviceKey: string, normalized: string): Promise<DictionaryRow | null> {
  const response = await fetch(entryUrl(supabaseUrl, normalized), {
    headers: restHeaders(serviceKey), signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) throw new Error('database_read');
  const rows = await response.json().catch(() => null) as unknown;
  return Array.isArray(rows) && rows[0] && typeof rows[0] === 'object' ? rows[0] as DictionaryRow : null;
}

async function translateWord(supabaseUrl: string, publicApiKey: string, authorization: string, word: string): Promise<string | null> {
  const response = await fetch(`${supabaseUrl}/functions/v1/translate`, {
    method: 'POST',
    headers: { apikey: publicApiKey, Authorization: authorization, 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: word, sourceLanguage: 'en', targetLanguage: 'vi' }),
    signal: AbortSignal.timeout(9000),
  });
  if (response.status === 401 || response.status === 403) throw new Error('session_expired');
  if (response.status === 429) throw new Error('translation_rate_limited');
  if (!response.ok) return null;
  const payload = await response.json().catch(() => null) as { status?: unknown; translatedText?: unknown } | null;
  return payload?.status === 'translated' && typeof payload.translatedText === 'string' && payload.translatedText.trim()
    ? payload.translatedText.trim() : null;
}

Deno.serve(async (request) => {
  const origin = request.headers.get('Origin') ?? undefined;
  const allowed = (Deno.env.get('DICTIONARY_ALLOWED_ORIGINS') ?? Deno.env.get('TRANSLATE_ALLOWED_ORIGINS') ?? '')
    .split(',').map((entry) => entry.trim()).filter(Boolean);
  if (origin && !allowed.includes(origin)) return json({ error: 'Origin not allowed.' }, 403);
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: {
    'Vary': 'Origin', ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}),
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  } });
  if (request.method !== 'POST') return json({ error: 'Method not allowed.' }, 405, origin);

  const authorization = request.headers.get('Authorization') ?? '';
  if (!/^Bearer [A-Za-z0-9._-]+$/.test(authorization)) return json({ error: 'Authentication required.' }, 401, origin);
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const publicApiKey = publicKey();
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !publicApiKey || !serviceKey) return json({ error: 'Dictionary service is not configured.' }, 503, origin);

  let verified: Response;
  try {
    verified = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: { apikey: publicApiKey, Authorization: authorization }, signal: AbortSignal.timeout(5000),
    });
  } catch { return json({ error: 'Authentication service unavailable.' }, 503, origin); }
  if (!verified.ok) return json({ error: 'Session expired. Sign in again.' }, 401, origin);

  const lengthHeader = Number(request.headers.get('Content-Length'));
  if (Number.isFinite(lengthHeader) && lengthHeader > 1000) return json({ error: 'Input is too long.' }, 413, origin);
  let payload: unknown;
  try {
    const raw = await request.text();
    if (raw.length > 1000) return json({ error: 'Input is too long.' }, 413, origin);
    payload = JSON.parse(raw);
  } catch { return json({ error: 'Invalid JSON request.' }, 400, origin); }
  const input = payload as Record<string, unknown> | null;
  const word = exactEnglishWord(input?.word);
  if (!word || Object.keys(input ?? {}).some((field) => field !== 'word')) {
    return json({ error: 'Enter one English word of at most 80 characters.' }, 422, origin);
  }

  let existing: DictionaryRow | null;
  try { existing = await findExisting(supabaseUrl, serviceKey, word); }
  catch { return json({ error: 'Dictionary database is unavailable.' }, 503, origin); }
  if (existing) {
    if (!existing.is_published || existing.archived_at) {
      return json({ error: 'This dictionary entry is not available.' }, 409, origin);
    }
    const { is_published: _published, archived_at: _archived, ...safeWord } = existing;
    return json({ word: safeWord, imported: false, translationAvailable: !!safeWord.translation }, 200, origin);
  }

  let dictionaryResponse: Response;
  try {
    dictionaryResponse = await fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`, {
      headers: { Accept: 'application/json' }, signal: AbortSignal.timeout(7000),
    });
  } catch (cause) {
    return json({ error: cause instanceof DOMException && cause.name === 'TimeoutError'
      ? 'Dictionary provider timed out.' : 'Dictionary provider unavailable.' },
    cause instanceof DOMException && cause.name === 'TimeoutError' ? 504 : 502, origin);
  }
  if (dictionaryResponse.status === 404) return json({ error: 'Word not found.' }, 404, origin);
  if (dictionaryResponse.status === 429) return json({ error: 'Dictionary provider limit reached.' }, 429, origin);
  if (!dictionaryResponse.ok) return json({ error: 'Dictionary provider unavailable.' }, 502, origin);
  const details = parseDictionaryResponse(await dictionaryResponse.json().catch(() => null));
  if (!details || normalizeWord(details.word) !== word) return json({ error: 'Dictionary provider returned invalid data.' }, 502, origin);

  let translation: string | null = null;
  try { translation = await translateWord(supabaseUrl, publicApiKey, authorization, details.word); }
  catch (cause) {
    if (cause instanceof Error && cause.message === 'session_expired') return json({ error: 'Session expired. Sign in again.' }, 401, origin);
    if (cause instanceof Error && cause.message === 'translation_rate_limited') {
      return json({ error: 'Dictionary import limit reached. Try again later.' }, 429, origin);
    }
  }

  const first = details.senses[0];
  const example = details.senses.find((sense) => !!sense.example)?.example ?? null;
  const row = {
    language: 'en', term: details.word, normalized_term: word,
    definition: details.senses.map((sense) => sense.partOfSpeech
      ? `${sense.partOfSpeech}: ${sense.definition}` : sense.definition).join('\n'),
    translation, ipa: details.ipa,
    part_of_speech: first.partOfSpeech || null, example, audio_url: details.audioUrl,
    source_name: 'Free Dictionary API', license_id: details.licenseName ?? 'CC BY-SA 3.0',
    is_published: true,
  };
  const insertUrl = new URL(`${supabaseUrl}/rest/v1/dictionary_entries`);
  insertUrl.searchParams.set('on_conflict', 'language,normalized_term');
  let inserted: Response;
  try {
    inserted = await fetch(insertUrl, {
      method: 'POST', headers: { ...restHeaders(serviceKey), Prefer: 'resolution=ignore-duplicates,return=representation' },
      body: JSON.stringify(row), signal: AbortSignal.timeout(5000),
    });
  } catch { return json({ error: 'Dictionary database is unavailable.' }, 503, origin); }
  if (!inserted.ok) return json({ error: 'Dictionary entry could not be saved.' }, 503, origin);
  const insertedRows = await inserted.json().catch(() => []) as DictionaryRow[];
  let saved: DictionaryRow | null = insertedRows[0] ?? null;
  if (!saved) {
    try { saved = await findExisting(supabaseUrl, serviceKey, word); }
    catch { return json({ error: 'Dictionary entry could not be verified.' }, 503, origin); }
  }
  if (!saved || !saved.is_published || saved.archived_at) return json({ error: 'Dictionary entry could not be verified.' }, 503, origin);
  const { is_published: _published, archived_at: _archived, ...safeWord } = saved;
  return json({
    word: safeWord, details, imported: true, translationAvailable: !!translation,
    ...(translation ? {} : { warning: 'Vietnamese translation is temporarily unavailable.' }),
  }, 200, origin);
});
