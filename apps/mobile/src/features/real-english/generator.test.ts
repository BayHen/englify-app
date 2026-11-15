import { describe, expect, it, vi } from 'vitest';
import { generateLesson, isNearDuplicate, validateGeneratedLesson } from '../../../../../supabase/functions/_shared/real-english-generator';
import type { ReferencePair } from '../../../../../supabase/functions/_shared/tatoeba';

const reference: ReferencePair = {
  englishId: 101, vietnameseId: 202, englishText: 'We need coffee.', vietnameseText: 'Chúng ta cần cà phê.',
  englishContributor: 'author_en', vietnameseContributor: 'author_vi', englishLicense: 'CC BY 2.0 FR',
  vietnameseLicense: 'CC BY 2.0 FR', sourceUrl: 'https://api.tatoeba.org/v1/sentences/101',
  translationUrl: 'https://api.tatoeba.org/v1/sentences/202', validationStatus: 'eligible', validationReason: null,
};
const lesson = {
  title: 'Coffee with a friend', description: 'Practice a casual request.', contentType: 'dialogue', difficulty: 'A2',
  expression: 'Fancy a coffee?', meaningVi: 'Bạn muốn uống cà phê không?', usageContext: 'A casual invitation.',
  formality: 'informal', explanation: 'A friendly way to invite someone.', learningTip: 'Use it with friends.',
  dialogue: [
    { speaker: 'A', englishText: 'Fancy a coffee?', vietnameseTranslation: 'Bạn muốn uống cà phê không?' },
    { speaker: 'B', englishText: 'Sure, thanks!', vietnameseTranslation: 'Được, cảm ơn!' },
  ],
};
const input = { topic: 'coffee', difficulty: 'A2' as const, reference,
  model: 'gemini-2.5-flash-lite', apiKey: 'test-only-key', maxOutputTokens: 1000 };

describe('Real English structured generation', () => {
  it('detects normalized near-duplicate expressions without an AI call', () => {
    expect(isNearDuplicate('Coffee, please!', 'coffee please')).toBe(true);
    expect(isNearDuplicate('Coffee with a friend', 'Travel by train')).toBe(false);
  });
  it('accepts only bounded complete lesson content', () => {
    expect(validateGeneratedLesson(lesson, 'A2').title).toBe(lesson.title);
    expect(() => validateGeneratedLesson({ ...lesson, dialogue: [] }, 'A2')).toThrow('schema');
    expect(() => validateGeneratedLesson({ ...lesson, difficulty: 'B2' }, 'A2')).toThrow('schema');
    expect(() => validateGeneratedLesson({ ...lesson, madeUpField: true }, 'A2')).toThrow('schema');
  });
  it('sends an eligible reference as data and validates JSON response', async () => {
    const fetchSpy = vi.fn(async (_url: string, _init?: RequestInit) => new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify(lesson) }] } }],
      usageMetadata: { promptTokenCount: 40, candidatesTokenCount: 90 } }), { status: 200 }));
    const result = await generateLesson({ ...input, fetcher: fetchSpy as typeof fetch });
    expect(result.lesson.expression).toBe('Fancy a coffee?');
    expect(result.usage.outputTokens).toBe(90);
    const request = JSON.parse(String(fetchSpy.mock.calls[0][1]?.body));
    expect(request.contents[0].parts[0].text).toContain(reference.englishText);
    expect(request.generationConfig.responseMimeType).toBe('application/json');
  });
  it('does not call Gemini with an unverified model or unlicensed source', async () => {
    const fetcher = vi.fn() as unknown as typeof fetch;
    await expect(generateLesson({ ...input, model: 'gemini-pro-paid', fetcher })).rejects.toMatchObject({ kind: 'configuration' });
    await expect(generateLesson({ ...input, reference: { ...reference, validationStatus: 'blocked_license' }, fetcher }))
      .rejects.toMatchObject({ kind: 'configuration' });
    expect(fetcher).not.toHaveBeenCalled();
  });
  it('reports quota and malformed output without creating a lesson', async () => {
    const limited = vi.fn(async () => new Response('{}', { status: 429 })) as unknown as typeof fetch;
    await expect(generateLesson({ ...input, fetcher: limited })).rejects.toMatchObject({ kind: 'quota' });
    const malformed = vi.fn(async () => new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: '{}' }] } }] }),
      { status: 200 })) as unknown as typeof fetch;
    await expect(generateLesson({ ...input, fetcher: malformed })).rejects.toMatchObject({ kind: 'invalid_response' });
  });
});
