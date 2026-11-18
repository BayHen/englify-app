// @ts-ignore Deno Edge Functions require explicit TypeScript extensions.
import { WritingAiError } from './writing-ai.ts';

declare const Deno: { env: { get(name: string): string | undefined } };

export type WritingSubmission = { id: string; user_id: string; exercise_id: string | null; prompt: string; body: string };
export type WritingExerciseContext = { kind: string; cefr_level: string; instructions: string | null; topic_id: string | null; writing_topics?: { title?: string } | null };
export type WritingEdgeContext = { origin?: string; bearer: string; base: string; publicKey: string; serviceKey: string;
  userId: string; submission: WritingSubmission; exercise: WritingExerciseContext; model: string; apiKey: string; maxOutputTokens: number; dailyLimit: number };

export const validUuid = (value: unknown): value is string => typeof value === 'string'
  && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);

export function reply(body: unknown, status = 200, origin?: string) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json; charset=utf-8', Vary: 'Origin',
    ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}) } });
}

export function preflight(request: Request): Response | null {
  const origin = request.headers.get('Origin') ?? undefined;
  const allowed = (Deno.env.get('EDGE_ALLOWED_ORIGINS') ?? '').split(',').map((item) => item.trim()).filter(Boolean);
  if (origin && !allowed.includes(origin)) return reply({ error: 'Origin not allowed.', code: 'origin_denied' }, 403);
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: {
    Vary: 'Origin', ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}),
    'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  } });
  if (request.method !== 'POST') return reply({ error: 'Method not allowed.', code: 'method_not_allowed' }, 405, origin);
  return null;
}

function publicKey(): string | null {
  const direct = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  if (direct) return direct;
  try {
    const keys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}') as Record<string, string>;
    return keys.default ?? Object.values(keys)[0] ?? null;
  } catch { return null; }
}

export async function parseRequest(request: Request, kind: 'coach' | 'rewrite'): Promise<{ context?: WritingEdgeContext;
  body?: Record<string, unknown>; response?: Response }> {
  const origin = request.headers.get('Origin') ?? undefined;
  const bearer = request.headers.get('Authorization') ?? '';
  if (!/^Bearer [A-Za-z0-9._-]+$/.test(bearer)) return { response: reply({ error: 'Authentication required.', code: 'unauthorized' }, 401, origin) };
  const base = Deno.env.get('SUPABASE_URL');
  const projectPublicKey = publicKey();
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const model = Deno.env.get('GEMINI_MODEL') ?? '';
  const apiKey = Deno.env.get('GEMINI_API_KEY') ?? '';
  const enabled = Deno.env.get('WRITING_AI_ENABLED') === 'true' && Deno.env.get('AI_FREE_TIER_CONFIRMED') === 'true'
    && Deno.env.get('AI_MONTHLY_MAX_ESTIMATED_COST_USD') === '0';
  const maxOutputTokens = Number(Deno.env.get('WRITING_AI_MAX_OUTPUT_TOKENS') ?? '2048');
  const dailyLimit = Number(Deno.env.get(kind === 'coach' ? 'WRITING_AI_COACH_DAILY_LIMIT' : 'WRITING_AI_REWRITE_DAILY_LIMIT') ?? '5');
  if (!base || !projectPublicKey || !serviceKey || !enabled || !apiKey
    || !['gemini-2.5-flash-lite','gemini-3.5-flash-lite'].includes(model)
    || !Number.isInteger(maxOutputTokens) || maxOutputTokens < 256 || maxOutputTokens > 4096
    || !Number.isInteger(dailyLimit) || dailyLimit < 1 || dailyLimit > 5) {
    return { response: reply({ error: 'Writing AI is not safely configured.', code: 'configuration' }, 503, origin) };
  }
  let body: Record<string, unknown>;
  try {
    const raw = await request.text();
    if (raw.length > 1200) return { response: reply({ error: 'Request too large.', code: 'invalid_request' }, 413, origin) };
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error();
    body = parsed as Record<string, unknown>;
  } catch { return { response: reply({ error: 'Invalid JSON request.', code: 'invalid_request' }, 400, origin) }; }
  if (!validUuid(body.submissionId) || !validUuid(body.requestId)) {
    return { response: reply({ error: 'Invalid writing request.', code: 'invalid_request' }, 422, origin) };
  }
  const userHeaders = { apikey: projectPublicKey, Authorization: bearer };
  try {
    const auth = await fetch(`${base}/auth/v1/user`, { headers: userHeaders, signal: AbortSignal.timeout(5000) });
    if (!auth.ok) return { response: reply({ error: 'Session expired. Sign in again.', code: 'unauthorized' }, 401, origin) };
    const user = await auth.json() as { id?: unknown };
    if (typeof user.id !== 'string') return { response: reply({ error: 'Invalid session.', code: 'unauthorized' }, 401, origin) };
    const lookup = new URL(`${base}/rest/v1/writing_submissions`);
    lookup.searchParams.set('select', 'id,user_id,exercise_id,prompt,body');
    lookup.searchParams.set('id', `eq.${body.submissionId}`);
    lookup.searchParams.set('user_id', `eq.${user.id}`);
    const rows = await fetch(lookup, { headers: userHeaders, signal: AbortSignal.timeout(5000) });
    if (!rows.ok) return { response: reply({ error: 'Writing history is unavailable.', code: 'database' }, 503, origin) };
    const submissions = await rows.json() as WritingSubmission[];
    const submission = submissions[0];
    if (!submission || submission.user_id !== user.id) return { response: reply({ error: 'Writing submission not found.', code: 'not_found' }, 404, origin) };
    if (!submission.exercise_id || submission.body.trim().length < 20 || submission.body.length > 5000) {
      return { response: reply({ error: 'AI writing tools require an eligible response of 20-5000 characters.', code: 'ineligible' }, 422, origin) };
    }
    const exerciseLookup = new URL(`${base}/rest/v1/writing_exercises`);
    exerciseLookup.searchParams.set('select', 'kind,cefr_level,instructions,topic_id,writing_topics(title)'); exerciseLookup.searchParams.set('id', `eq.${submission.exercise_id}`);
    exerciseLookup.searchParams.set('is_published', 'eq.true');
    const exerciseRows = await fetch(exerciseLookup, { headers: userHeaders, signal: AbortSignal.timeout(5000) });
    const exercises = exerciseRows.ok ? await exerciseRows.json() as WritingExerciseContext[] : [];
    const exercise = exercises[0];
    if (!exercise || !['paragraph','email','opinion','essay'].includes(exercise.kind)) {
      return { response: reply({ error: 'AI feedback is available for open writing exercises.', code: 'ineligible' }, 422, origin) };
    }
    return { body, context: { origin, bearer, base, publicKey: projectPublicKey, serviceKey, userId: user.id,
      submission, exercise, model, apiKey, maxOutputTokens, dailyLimit } };
  } catch { return { response: reply({ error: 'Authentication service unavailable.', code: 'network' }, 503, origin) }; }
}

export async function serviceRest(context: WritingEdgeContext, path: string, options: RequestInit = {}) {
  return fetch(`${context.base}/rest/v1/${path}`, { ...options, signal: AbortSignal.timeout(8000), headers: {
    apikey: context.serviceKey, Authorization: `Bearer ${context.serviceKey}`, 'Content-Type': 'application/json',
    ...(options.headers ?? {}),
  } });
}

export async function claim(context: WritingEdgeContext, kind: 'coach' | 'rewrite', requestId: string) {
  const response = await serviceRest(context, 'rpc/englify_claim_writing_ai_request', { method: 'POST', body: JSON.stringify({
    p_user_id: context.userId, p_request_kind: kind, p_request_id: requestId, p_daily_limit: context.dailyLimit,
  }) });
  if (response.status === 429 || response.status === 400) throw new WritingAiError('quota', 'Daily AI writing limit reached.');
  if (!response.ok) throw new WritingAiError('provider', 'AI usage reservation failed.');
  const value = await response.json() as { usage_id?: unknown; duplicate?: unknown; status?: unknown };
  if (!validUuid(value.usage_id)) throw new WritingAiError('provider', 'AI usage reservation is invalid.');
  return { usageId: value.usage_id, duplicate: value.duplicate === true, status: String(value.status ?? '') };
}

export async function finishUsage(context: WritingEdgeContext, usageId: string, status: 'completed' | 'failed', usage?: { inputTokens: number; outputTokens: number }) {
  await serviceRest(context, `writing_ai_usage?id=eq.${usageId}`, { method: 'PATCH', body: JSON.stringify({ status,
    input_tokens: usage?.inputTokens ?? 0, output_tokens: usage?.outputTokens ?? 0, completed_at: new Date().toISOString() }) });
}

export function aiFailure(cause: unknown, origin?: string) {
  const error = cause instanceof WritingAiError ? cause : new WritingAiError('provider', 'Writing AI failed.');
  const status = error.kind === 'quota' ? 429 : error.kind === 'invalid_response' ? 422
    : error.kind === 'configuration' ? 503 : error.kind === 'timeout' || error.kind === 'network' ? 504 : 502;
  const publicMessage = error.kind === 'quota' ? 'Daily AI writing limit reached.'
    : error.kind === 'invalid_response' ? 'AI returned feedback that could not be validated.'
      : error.kind === 'timeout' ? 'AI writing request timed out.'
        : error.kind === 'network' ? 'AI writing service is unreachable.' : 'AI writing service is unavailable.';
  return reply({ error: publicMessage, code: error.kind }, status, origin);
}
