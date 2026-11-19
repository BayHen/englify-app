// @ts-ignore Deno Edge Functions require explicit TypeScript extensions.
import { analyzeWriting } from '../_shared/writing-ai.ts';
// @ts-ignore Deno Edge Functions require explicit TypeScript extensions.
import { aiFailure, claim, finishUsage, parseRequest, preflight, reply, serviceRest } from '../_shared/writing-edge.ts';

declare const Deno: { serve(handler: (request: Request) => Promise<Response>): void };

Deno.serve(async (request) => {
  const early = preflight(request); if (early) return early;
  const parsed = await parseRequest(request, 'coach'); if (parsed.response) return parsed.response;
  const context = parsed.context!; const body = parsed.body!; const requestId = body.requestId as string;
  if (Object.keys(body).some((key) => !['submissionId','requestId'].includes(key))) {
    return reply({ error: 'Invalid writing request.', code: 'invalid_request' }, 422, context.origin);
  }
  let usageId: string | null = null;
  try {
    const reservation = await claim(context, 'coach', requestId); usageId = reservation.usageId;
    if (reservation.duplicate) {
      const existing = await serviceRest(context, `writing_ai_feedback?select=*&user_id=eq.${context.userId}&request_id=eq.${requestId}`);
      const rows = existing.ok ? await existing.json() as unknown[] : [];
      if (rows[0]) return reply({ feedback: rows[0], duplicate: true }, 200, context.origin);
      return reply({ error: 'This AI request is already processing or failed.', code: 'duplicate' }, 409, context.origin);
    }
    const generated = await analyzeWriting({ prompt: context.submission.prompt, originalText: context.submission.body,
      model: context.model, apiKey: context.apiKey, maxOutputTokens: context.maxOutputTokens,
      cefrLevel: context.exercise.cefr_level, exerciseKind: context.exercise.kind, instructions: context.exercise.instructions,
      topic: context.exercise.writing_topics?.title ?? null });
    const result = generated.result;
    const stored = await serviceRest(context, 'writing_ai_feedback?select=*', { method: 'POST',
      headers: { Prefer: 'return=representation' }, body: JSON.stringify({ submission_id: context.submission.id,
        user_id: context.userId, request_id: requestId, overall_score: result.overall_score,
        grammar_score: result.grammar_score, vocabulary_score: result.vocabulary_score,
        sentence_structure_score: result.sentence_structure_score, coherence_score: result.coherence_score,
        task_score: result.task_score, assessment_vi: result.assessment_vi, strengths: result.strengths,
        improvements: result.improvements, errors: result.errors, next_steps: result.next_steps, model: context.model }) });
    if (!stored.ok) throw new Error('AI feedback could not be stored.');
    const rows = await stored.json() as unknown[];
    if (!rows[0]) throw new Error('AI feedback storage returned no row.');
    await finishUsage(context, usageId, 'completed', generated.usage);
    return reply({ feedback: rows[0], duplicate: false }, 201, context.origin);
  } catch (cause) {
    if (usageId) await finishUsage(context, usageId, 'failed').catch(() => undefined);
    return aiFailure(cause, context.origin);
  }
});
