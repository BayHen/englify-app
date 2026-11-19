// @ts-ignore Deno Edge Functions require explicit TypeScript extensions.
import { rewriteWriting, type RewriteMode } from '../_shared/writing-ai.ts';
// @ts-ignore Deno Edge Functions require explicit TypeScript extensions.
import { aiFailure, claim, finishUsage, parseRequest, preflight, reply, serviceRest } from '../_shared/writing-edge.ts';

declare const Deno: { serve(handler: (request: Request) => Promise<Response>): void };
const modes: RewriteMode[] = ['grammar','natural','vocabulary','formal','simple'];

Deno.serve(async (request) => {
  const early = preflight(request); if (early) return early;
  const parsed = await parseRequest(request, 'rewrite'); if (parsed.response) return parsed.response;
  const context = parsed.context!; const body = parsed.body!; const requestId = body.requestId as string;
  if (!modes.includes(body.mode as RewriteMode)
    || Object.keys(body).some((key) => !['submissionId','requestId','mode'].includes(key))) {
    return reply({ error: 'Invalid rewrite mode.', code: 'invalid_request' }, 422, context.origin);
  }
  let usageId: string | null = null;
  try {
    const reservation = await claim(context, 'rewrite', requestId); usageId = reservation.usageId;
    if (reservation.duplicate) {
      const existing = await serviceRest(context, `writing_ai_rewrites?select=*&user_id=eq.${context.userId}&request_id=eq.${requestId}`);
      const rows = existing.ok ? await existing.json() as unknown[] : [];
      if (rows[0]) return reply({ rewrite: rows[0], duplicate: true }, 200, context.origin);
      return reply({ error: 'This AI request is already processing or failed.', code: 'duplicate' }, 409, context.origin);
    }
    const generated = await rewriteWriting({ originalText: context.submission.body, mode: body.mode as RewriteMode,
      model: context.model, apiKey: context.apiKey, maxOutputTokens: context.maxOutputTokens, cefrLevel: context.exercise.cefr_level });
    const result = generated.result;
    const stored = await serviceRest(context, 'writing_ai_rewrites?select=*', { method: 'POST',
      headers: { Prefer: 'return=representation' }, body: JSON.stringify({ submission_id: context.submission.id,
        user_id: context.userId, request_id: requestId, mode: result.mode, original_text: result.original_text,
        improved_text: result.improved_text, key_changes: result.key_changes, explanations_vi: result.explanations_vi,
        vocabulary_suggestions: result.vocabulary_suggestions, model: context.model }) });
    if (!stored.ok) throw new Error('AI rewrite could not be stored.');
    const rows = await stored.json() as unknown[];
    if (!rows[0]) throw new Error('AI rewrite storage returned no row.');
    await finishUsage(context, usageId, 'completed', generated.usage);
    return reply({ rewrite: rows[0], duplicate: false }, 201, context.origin);
  } catch (cause) {
    if (usageId) await finishUsage(context, usageId, 'failed').catch(() => undefined);
    return aiFailure(cause, context.origin);
  }
});
