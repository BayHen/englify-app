import { readStorage, writeStorage } from './cache-storage';
import type { DictionaryWord } from './types';

import { curatedWords } from './curated-words';

const parts: Record<string, string> = { n: 'noun', v: 'verb', adj: 'adjective', adv: 'adverb' };

export function parseDailyCandidates(value: unknown): DictionaryWord[] {
  if (!Array.isArray(value)) return [];
  const entries: DictionaryWord[] = [];
  for (const item of value) {
    if (!item || typeof item.word !== 'string' || !/^[a-z]{3,20}$/.test(item.word)
      || item.defHeadword || !Array.isArray(item.defs)) continue;
    const sense = item.defs.find((definition: unknown) => typeof definition === 'string'
      && /^(n|v|adj|adv)\t\S/.test(definition));
    if (typeof sense !== 'string') continue;
    const [tag, ...content] = sense.split('\t');
    entries.push({ id: `daily-online:${item.word}`, term: item.word, definition: content.join(' ').trim(),
      part_of_speech: parts[tag], ipa: null, translation: null, example: null,
      audio_url: null, source_name: 'Datamuse (WordNet/Wiktionary)', license_id: '' });
  }
  return entries;
}

async function fetchDailyCandidates() {
  const prefixes = ['ac', 'br', 'ch', 'co', 'de', 'ex', 'fl', 'gr', 'in', 'li', 'mo', 'pa', 're', 'sh', 'st', 'tr'];
  const prefix = prefixes[Math.floor(Math.random() * prefixes.length)];
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 2500);
  try {
    const result = await fetch(`https://api.datamuse.com/words?sp=${prefix}*&md=d&max=35`, { signal: controller.signal });
    return result.ok ? parseDailyCandidates(await result.json()) : [];
  } catch { return []; }
  finally { clearTimeout(timer); }
}

export function localVocabularyDate(now = new Date()) {
  return [now.getFullYear(), String(now.getMonth() + 1).padStart(2, '0'), String(now.getDate()).padStart(2, '0')].join('-');
}

let selection: { date: string; words: Promise<DictionaryWord[]> } | undefined;
export function loadDailyVocabulary(now = new Date()) {
  const date = localVocabularyDate(now);
  if (selection?.date === date) return selection.words;
  const words = (async () => {
    const key = `daily-vocabulary:${date}`;
    const valid = new Map(curatedWords.filter((word) => word.definition && word.translation).map((word) => [word.term, word]));
    async function read(dayKey: string): Promise<DictionaryWord[]> {
      try {
        const raw: unknown = JSON.parse(await readStorage(dayKey) ?? 'null');
        const entries = new Map<string, DictionaryWord>();
        for (const item of Array.isArray(raw) ? raw : []) {
          const term = typeof item === 'string' ? item : item?.term;
          const entry = valid.get(term) ?? (item?.id === `daily-online:${term}` && typeof term === 'string'
            && /^[a-z]{3,20}$/.test(term) && typeof item.definition === 'string' && item.definition.trim() ? item as DictionaryWord : null);
          if (entry) entries.set(entry.term, entry);
        }
        return [...entries.values()];
      } catch { return []; }
    }
    const stored = await read(key);
    if (stored.length === 5) return stored;
    const yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
    const recent = (await read(`daily-vocabulary:${localVocabularyDate(yesterday)}`)).map((word) => word.term);
    const online = [...new Map((await fetchDailyCandidates())
      .filter((word) => !valid.has(word.term) && !recent.includes(word.term))
      .map((word) => [word.term, word])).values()];
    const chosen = Array.from({ length: Math.min(3, online.length) }, () => online.splice(Math.floor(Math.random() * online.length), 1)[0]);
    const pool = [...valid.values()].filter((word) => !recent.includes(word.term));
    if (pool.length < 5 - chosen.length) pool.push(...[...valid.values()].filter((word) => recent.includes(word.term)));
    while (chosen.length < 5 && pool.length) chosen.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]);
    await writeStorage(key, JSON.stringify(chosen)).catch(() => undefined);
    return chosen;
  })();
  selection = { date, words };
  return words;
}
