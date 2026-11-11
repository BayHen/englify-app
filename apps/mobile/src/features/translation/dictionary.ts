export type DictionarySense = { partOfSpeech: string; definition: string; example: string | null };
export type DictionaryDetails = {
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

type RawDefinition = { definition?: unknown; example?: unknown; synonyms?: unknown; antonyms?: unknown };
type RawMeaning = { partOfSpeech?: unknown; definitions?: unknown; synonyms?: unknown; antonyms?: unknown };
type RawEntry = {
  word?: unknown; phonetic?: unknown; phonetics?: unknown; meanings?: unknown;
  license?: { name?: unknown; url?: unknown }; sourceUrls?: unknown;
};
const cache = new Map<string, { value: DictionaryDetails | null; expires: number }>();

export function englishLookupWord(text: string): string | null {
  const word = text.trim().replace(/[.!?;,]+$/u, '');
  return /^[a-z]+(?:['’-][a-z]+)*$/iu.test(word) && word.length <= 80 ? word : null;
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
        senses.push({ partOfSpeech, definition: definition.definition.trim(),
          example: typeof definition.example === 'string' && definition.example.trim() ? definition.example.trim() : null });
      }
    }
  }
  const unique = (list: string[]) => [...new Set(list)].slice(0, 8);
  const selectedSenses = senses.slice(0, 3);
  if (!selectedSenses.some((sense) => sense.example)) {
    const withExample = senses.find((sense) => !!sense.example);
    if (withExample && !selectedSenses.includes(withExample)) {
      if (selectedSenses.length === 3) selectedSenses[2] = withExample;
      else selectedSenses.push(withExample);
    }
  }
  const source = Array.isArray(entry.sourceUrls) ? entry.sourceUrls.map(httpsUrl).find(Boolean) ?? null : null;
  return {
    word: entry.word as string,
    ipa: typeof entry.phonetic === 'string' && entry.phonetic.trim() ? entry.phonetic.trim()
      : phonetics.map((item) => item.text).find((item): item is string => typeof item === 'string' && !!item.trim()) ?? null,
    audioUrl: phonetics.map((item) => httpsUrl(item.audio)).find((item): item is string => !!item) ?? null,
    senses: selectedSenses, synonyms: unique(synonyms), antonyms: unique(antonyms),
    licenseName: typeof entry.license?.name === 'string' ? entry.license.name : null,
    licenseUrl: httpsUrl(entry.license?.url),
    sourceUrl: source,
  };
}

export async function lookupEnglishWord(word: string, fetcher: typeof fetch = fetch): Promise<DictionaryDetails | null> {
  const normalized = englishLookupWord(word);
  if (!normalized) return null;
  const key = normalized.toLocaleLowerCase();
  const cached = cache.get(key);
  if (cached && cached.expires > Date.now()) return cached.value;
  const url = `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(normalized)}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 7000);
  let response: Response;
  try { response = await fetcher(url, { method: 'GET', signal: controller.signal }); }
  catch { throw new Error(controller.signal.aborted ? 'Dictionary lookup timed out. Translation is still available.'
    : 'Dictionary lookup is unavailable. Translation is still available.'); }
  finally { clearTimeout(timer); }
  if (response.status === 404) {
    cache.set(key, { value: null, expires: Date.now() + 10 * 60 * 1000 });
    return null;
  }
  if (!response.ok) throw new Error('Dictionary lookup is unavailable. Translation is still available.');
  let body: unknown;
  try { body = await response.json(); }
  catch { throw new Error('Dictionary returned invalid data. Translation is still available.'); }
  const details = parseDictionaryResponse(body);
  if (!details) throw new Error('Dictionary returned invalid data. Translation is still available.');
  if (cache.size >= 100) cache.delete(cache.keys().next().value!);
  cache.set(key, { value: details, expires: Date.now() + 24 * 60 * 60 * 1000 });
  return details;
}
