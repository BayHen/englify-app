import { describe, expect, it, vi } from 'vitest';
import { enrichLesson } from '../../../../../supabase/functions/_shared/real-english-enrichment';
import type { GeneratedLesson } from '../../../../../supabase/functions/_shared/real-english-generator';

const lesson: GeneratedLesson = {
  title: 'Welcome', description: 'A short exchange.', contentType: 'dialogue', difficulty: 'A1',
  expression: 'Love', meaningVi: 'Tình yêu', usageContext: 'Everyday English.', formality: 'neutral',
  explanation: 'A common noun.', learningTip: 'Practice the word.', dialogue: [
    { speaker: 'A', englishText: 'I love this.', vietnameseTranslation: 'Tôi thích điều này.' },
    { speaker: 'B', englishText: 'Me too.', vietnameseTranslation: 'Tôi cũng vậy.' },
  ],
};

describe('Real English enrichment', () => {
  it('keeps real provider candidates separate from the AI meaning', async () => {
    const fetcher = vi.fn(async (url: URL | RequestInfo) => String(url).includes('mymemory')
      ? new Response(JSON.stringify({ responseStatus: 200, responseData: { translatedText: 'Tình yêu' } }), { status: 200 })
      : new Response(JSON.stringify([{ phonetic: '/lʌv/', meanings: [{ partOfSpeech: 'noun' }] }]), { status: 200 })) as typeof fetch;
    const output = await enrichLesson(lesson, fetcher, true);
    expect(output).toMatchObject({ ipa: '/lʌv/', partOfSpeech: 'noun', myMemoryTranslation: 'Tình yêu', warnings: [] });
    expect(fetcher).toHaveBeenCalledTimes(2);
  });
  it('preserves a usable draft and warnings when providers fail', async () => {
    const fetcher = vi.fn(async () => { throw Error('offline'); }) as typeof fetch;
    const output = await enrichLesson(lesson, fetcher, true);
    expect(output.ipa).toBeNull();
    expect(output.myMemoryTranslation).toBeNull();
    expect(output.warnings).toHaveLength(2);
  });
  it('does not pretend a multiword phrase has dictionary IPA', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ responseStatus: 200,
      responseData: { translatedText: 'Không sao đâu' } }), { status: 200 })) as typeof fetch;
    const output = await enrichLesson({ ...lesson, expression: 'No biggie' }, fetcher);
    expect(output.ipa).toBeNull();
    expect(output.warnings).toContain('Dictionary lookup skipped for a multiword expression.');
    expect(fetcher).toHaveBeenCalledTimes(1);
  });
  it('keeps dictionary enrichment off until data licensing is reviewed', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ responseStatus: 200,
      responseData: { translatedText: 'Tình yêu' } }), { status: 200 })) as unknown as typeof fetch;
    const output = await enrichLesson(lesson, fetcher);
    expect(output.ipa).toBeNull();
    expect(output.warnings).toContain('Dictionary enrichment disabled pending data-license review.');
    expect(fetcher).toHaveBeenCalledTimes(1);
  });
});
