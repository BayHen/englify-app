// @ts-ignore Deno requires the explicit TypeScript extension; mobile tsc imports this file in tests.
import { translateWithMyMemory, utf8ByteLength } from '../translate/provider.ts';
import type { GeneratedLesson } from './real-english-generator.ts';

export type Enrichment = { ipa: string | null; partOfSpeech: string | null;
  myMemoryTranslation: string | null; warnings: string[] };
const word = /^[a-z][a-z-]{1,39}$/i;

export async function enrichLesson(lesson: GeneratedLesson, fetcher: typeof fetch = fetch,
  dictionaryEnabled = false): Promise<Enrichment> {
  const output: Enrichment = { ipa: null, partOfSpeech: null, myMemoryTranslation: null, warnings: [] };
  if (utf8ByteLength(lesson.expression) <= 500) {
    try {
      const result = await translateWithMyMemory(lesson.expression, 'en', 'vi', fetcher);
      output.myMemoryTranslation = result.translatedText;
      if (result.translatedText.trim().toLocaleLowerCase('vi') !== lesson.meaningVi.trim().toLocaleLowerCase('vi')) {
        output.warnings.push('Translation differs from MyMemory; admin must verify meaning.');
      }
    } catch { output.warnings.push('MyMemory unavailable; admin must verify translation.'); }
  } else output.warnings.push('Expression exceeds MyMemory request size; admin must verify translation.');
  if (!word.test(lesson.expression.trim())) {
    output.warnings.push('Dictionary lookup skipped for a multiword expression.');
    return output;
  }
  if (!dictionaryEnabled) {
    output.warnings.push('Dictionary enrichment disabled pending data-license review.');
    return output;
  }
  try {
    const url = new URL(`https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(lesson.expression.trim())}`);
    const response = await fetcher(url, { signal: AbortSignal.timeout(5000) });
    if (!response.ok) throw Error();
    const body: unknown = await response.json();
    if (!Array.isArray(body) || !body.length || !body[0] || typeof body[0] !== 'object') throw Error();
    const entry = body[0] as Record<string, unknown>;
    if (typeof entry.phonetic === 'string' && entry.phonetic.length <= 80) output.ipa = entry.phonetic;
    if (Array.isArray(entry.meanings)) {
      const first = entry.meanings[0];
      if (first && typeof first === 'object' && typeof first.partOfSpeech === 'string' && first.partOfSpeech.length <= 40) {
        output.partOfSpeech = first.partOfSpeech;
      }
    }
    if (!output.ipa) output.warnings.push('Dictionary response has no validated IPA.');
  } catch { output.warnings.push('Free Dictionary API unavailable or word not found.'); }
  return output;
}
