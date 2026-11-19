import { describe, expect, it, vi } from 'vitest';
// @ts-ignore Deno Edge shared modules use explicit TypeScript extensions.
import { analyzeWriting, rewriteWriting, validateCoachResult, validateRewriteResult } from '../../../../../supabase/functions/_shared/writing-ai.ts';

const original = 'She go to school every day. She likes her class.';
const coach = {
  overall_score: 78, grammar_score: 70, vocabulary_score: 82, sentence_structure_score: 76,
  coherence_score: 85, task_score: 80, assessment_vi: 'Bài viết rõ ý nhưng cần sửa chia động từ.',
  strengths: ['The main idea is clear.'], improvements: ['Review subject-verb agreement.'],
  errors: [{ type: 'grammar', original: 'She go to school', corrected: 'She goes to school',
    explanation_vi: 'Chủ ngữ She cần động từ thêm s ở hiện tại đơn.' }], next_steps: ['Practice third-person singular verbs.'],
};
const rewrite = (mode: 'grammar' | 'natural' | 'vocabulary' | 'formal' | 'simple') => ({ original_text: original,
  improved_text: 'She goes to school every day. She likes her class.', mode, key_changes: ['Corrected the verb form.'],
  explanations_vi: ['Đã sửa động từ theo chủ ngữ.'], vocabulary_suggestions: [] });
const gemini = (value: unknown) => new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify(value) }] } }],
  usageMetadata: { promptTokenCount: 30, candidatesTokenCount: 50 } }), { status: 200 });

describe('Writing AI validation', () => {
  it('accepts bounded coach feedback tied to the original text', () => {
    expect(validateCoachResult(coach, original).overall_score).toBe(78);
  });
  it('rejects invalid scores and invented corrections', () => {
    expect(() => validateCoachResult({ ...coach, grammar_score: 101 }, original)).toThrow(/schema/i);
    expect(() => validateCoachResult({ ...coach, errors: [{ ...coach.errors[0], original: 'They were late' }] }, original)).toThrow(/unrelated/i);
  });
  it.each(['grammar','natural','vocabulary','formal','simple'] as const)('validates %s rewrite without replacing the original', (mode) => {
    expect(validateRewriteResult(rewrite(mode), original, mode).original_text).toBe(original);
  });
  it('rejects a rewrite that changes its reported original', () => {
    expect(() => validateRewriteResult({ ...rewrite('natural'), original_text: 'Different facts.' }, original, 'natural')).toThrow(/schema/i);
  });
  it('parses structured Gemini coach output and reports usage', async () => {
    const fetcher = vi.fn().mockResolvedValue(gemini(coach));
    const value = await analyzeWriting({ prompt: 'Write about school.', originalText: original,
      model: 'gemini-2.5-flash-lite', apiKey: 'test-key', maxOutputTokens: 1000, fetcher });
    expect(value.result.grammar_score).toBe(70); expect(value.usage.outputTokens).toBe(50);
  });
  it('handles malformed output, provider quota and timeout safely', async () => {
    await expect(analyzeWriting({ prompt: 'Prompt', originalText: original, model: 'gemini-2.5-flash-lite', apiKey: 'test-key',
      maxOutputTokens: 1000, fetcher: vi.fn().mockResolvedValue(new Response('{"candidates":[]}', { status: 200 })) })).rejects.toMatchObject({ kind: 'invalid_response' });
    await expect(rewriteWriting({ originalText: original, mode: 'grammar', model: 'gemini-2.5-flash-lite', apiKey: 'test-key',
      maxOutputTokens: 1000, fetcher: vi.fn().mockResolvedValue(new Response('', { status: 429 })) })).rejects.toMatchObject({ kind: 'quota' });
  });
  it('classifies an aborted Gemini call as a timeout', async () => {
    vi.useFakeTimers();
    const fetcher = vi.fn((_url: string | URL | Request, init?: RequestInit) => new Promise<Response>((_resolve, reject) => {
      init?.signal?.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')));
    }));
    const pending = analyzeWriting({ prompt: 'Prompt', originalText: original, model: 'gemini-2.5-flash-lite',
      apiKey: 'test-key', maxOutputTokens: 1000, fetcher });
    const assertion = expect(pending).rejects.toMatchObject({ kind: 'timeout' });
    await vi.advanceTimersByTimeAsync(20_001);
    await assertion;
    vi.useRealTimers();
  });
});
