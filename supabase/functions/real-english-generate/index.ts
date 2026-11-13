// Manual/admin generation endpoint. No Cron is registered until provider and RLS gates pass.
import { searchTatoeba, TatoebaError } from '../_shared/tatoeba.ts';
import { checkGeminiModel, generateLesson, GenerationError, isNearDuplicate } from '../_shared/real-english-generator.ts';
import { enrichLesson } from '../_shared/real-english-enrichment.ts';

declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (request: Request) => Promise<Response>): void;
};

const json = (data: unknown, status: number, origin?: string) => new Response(JSON.stringify(data), {
  status, headers: { 'Content-Type': 'application/json; charset=utf-8', 'Vary': 'Origin',
    ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}) },
});
const validUuid = (value: unknown): value is string => typeof value === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
const positiveLimit = (value: string | undefined) => value && /^\d+$/.test(value) ? Number(value) : 0;
function publicKey(): string | null {
  const direct = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  if (direct) return direct;
  try {
    const keys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}') as Record<string, string>;
    return keys.default ?? Object.values(keys)[0] ?? null;
  } catch { return null; }
}
function sameSecret(left: string, right: string): boolean {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  let difference = a.length ^ b.length;
  for (let index = 0; index < Math.max(a.length, b.length); index++) difference |= (a[index] ?? 0) ^ (b[index] ?? 0);
  return difference === 0;
}
function isGatewayVerifiedAnonJwt(bearer: string): boolean {
  // Supabase's verify_jwt=true gateway validates signature; this check limits Cron to the anon role.
  const token = bearer.startsWith('Bearer ') ? bearer.slice(7) : '';
  const parts = token.split('.');
  if (parts.length !== 3) return false;
  try {
    const encoded = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const claims = JSON.parse(atob(encoded.padEnd(Math.ceil(encoded.length / 4) * 4, '='))) as Record<string, unknown>;
    return claims.role === 'anon' && typeof claims.exp === 'number' && claims.exp > Date.now() / 1000;
  } catch { return false; }
}

async function rest(url: string, key: string, path: string, options: RequestInit = {}): Promise<Response> {
  return fetch(`${url}/rest/v1/${path}`, { ...options, signal: AbortSignal.timeout(8000), headers: {
    apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json',
    ...(options.headers ?? {}),
  } });
}

Deno.serve(async (request) => {
  const origin = request.headers.get('Origin') ?? undefined;
  const allowed = (Deno.env.get('EDGE_ALLOWED_ORIGINS') ?? '').split(',').map((item) => item.trim()).filter(Boolean);
  if (origin && !allowed.includes(origin)) return json({ error: 'Origin not allowed.' }, 403);
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: {
    'Vary': 'Origin', ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}),
    'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  } });
  if (request.method !== 'POST') return json({ error: 'Method not allowed.' }, 405, origin);
  const bearer = request.headers.get('Authorization') ?? '';
  if (!/^Bearer [A-Za-z0-9._-]+$/.test(bearer)) return json({ error: 'Authentication required.' }, 401, origin);
  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const projectPublicKey = publicKey();
  if (!url || !serviceKey || !projectPublicKey) return json({ error: 'Service configuration incomplete.' }, 503, origin);
  const cronSecret = Deno.env.get('REAL_ENGLISH_CRON_SECRET');
  const scheduledCaller = !!cronSecret
    && sameSecret(request.headers.get('x-englify-cron-secret') ?? '', cronSecret)
    && isGatewayVerifiedAnonJwt(bearer);
  if (!scheduledCaller) {
    // Verify the end-user JWT using Auth and ask the database-owned membership RPC.
    try {
      const auth = await fetch(`${url}/auth/v1/user`, { headers: { apikey: projectPublicKey, Authorization: bearer },
        signal: AbortSignal.timeout(5000) });
      if (!auth.ok) return json({ error: 'Session expired.' }, 401, origin);
      const admin = await rest(url, projectPublicKey, 'rpc/englify_is_admin', { method: 'POST',
        headers: { Authorization: bearer }, body: '{}' });
      if (!admin.ok || await admin.json() !== true) return json({ error: 'Administrator access required.' }, 403, origin);
    } catch { return json({ error: 'Authentication service unavailable.' }, 503, origin); }
  }

  if (Deno.env.get('AI_GENERATION_ENABLED') !== 'true'
    || Deno.env.get('AI_FREE_TIER_CONFIRMED') !== 'true'
    || Deno.env.get('AI_MONTHLY_MAX_ESTIMATED_COST_USD') !== '0'
    || !['gemini-2.5-flash-lite', 'gemini-3.5-flash-lite'].includes(Deno.env.get('GEMINI_MODEL') ?? '')
    || !Deno.env.get('GEMINI_API_KEY')) {
    return json({ error: 'AI generation is disabled or Free tier has not been verified.' }, 503, origin);
  }
  let body: Record<string, unknown>;
  try {
    const raw = await request.text();
    if (raw.length > 2000) return json({ error: 'Request too large.' }, 413, origin);
    body = JSON.parse(raw);
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw Error();
  } catch { return json({ error: 'Invalid JSON request.' }, 400, origin); }
  if (body.action === 'check_model' && Object.keys(body).length === 1) {
    const configured = Deno.env.get('GEMINI_MODEL')!;
    const candidates = [...new Set([configured, 'gemini-3.5-flash-lite'])];
    const models = await Promise.all(candidates.map(async (model) => {
      try { await checkGeminiModel(model, Deno.env.get('GEMINI_API_KEY')!); return { model, available: true }; }
      catch (cause) { return { model, available: false, reason: cause instanceof Error ? cause.message : 'Model check failed.' }; }
    }));
    return json({ configured, models }, 200, origin);
  }
  const { topicId, keyword, difficulty, slot } = body;
  if (!validUuid(topicId) || typeof keyword !== 'string' || !keyword.trim() || keyword.length > 80
    || !['A1','A2','B1','B2','C1','C2'].includes(String(difficulty))
    || !Number.isInteger(slot) || Number(slot) < 0 || Number(slot) > 19
    || Object.keys(body).some((key) => !['topicId','keyword','difficulty','slot'].includes(key))) {
    return json({ error: 'Invalid generation request.' }, 422, origin);
  }
  const parts = new Intl.DateTimeFormat('en-US', { timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit', day: '2-digit' })
    .formatToParts(new Date());
  const part = (type: string) => parts.find((item) => item.type === type)?.value ?? '';
  const day = `${part('year')}-${part('month')}-${part('day')}`;
  const idempotencyKey = `real-english:${day}:${topicId}:${slot}`;
  let jobId: string | null = null;
  try {
    const [settingsResponse, topicResponse, batchResponse] = await Promise.all([
      rest(url, serviceKey, 'real_english_generation_settings?select=*&id=eq.true'),
      rest(url, serviceKey, `real_english_topics?select=id,slug,is_active,difficulty&id=eq.${topicId}`),
      rest(url, serviceKey, `real_english_generation_batches?select=success_count&generation_date=eq.${day}`),
    ]);
    if (!settingsResponse.ok || !topicResponse.ok || !batchResponse.ok) throw Error('Database unavailable.');
    const [settingsRows, topicRows, batchRows] = await Promise.all([settingsResponse.json(), topicResponse.json(), batchResponse.json()]);
    const settings = settingsRows?.[0];
    const topic = topicRows?.[0];
    if (!settings || !settings.ai_generation_enabled || !settings.source_import_enabled || !topic?.is_active
      || topic.difficulty !== difficulty || !settings.enabled_topics.includes(topic.slug)
      || !settings.enabled_difficulty_levels.includes(difficulty)
      || Number(slot) >= settings.maximum_daily_requests) {
      return json({ error: 'Topic or generation is disabled.' }, 409, origin);
    }
    if (Number(batchRows?.[0]?.success_count ?? 0) >= settings.daily_generation_target) {
      return json({ error: 'Daily reviewable lesson target reached.' }, 409, origin);
    }
    const envRequests = positiveLimit(Deno.env.get('AI_DAILY_MAX_REQUESTS'));
    const envTokens = positiveLimit(Deno.env.get('AI_DAILY_MAX_OUTPUT_TOKENS'));
    if (!envRequests || !envTokens || settings.maximum_daily_requests > envRequests
      || settings.maximum_output_tokens * settings.maximum_daily_requests > envTokens) {
      return json({ error: 'Generation quota configuration is unsafe.' }, 503, origin);
    }
    const preflight = await rest(url, serviceKey,
      `real_english_generation_preflights?select=attempt_count,next_retry_at&idempotency_key=eq.${encodeURIComponent(idempotencyKey)}`);
    if (!preflight.ok) throw Error('Source retry log unavailable.');
    const previous = (await preflight.json())?.[0];
    if (previous?.attempt_count >= 3) return json({ error: 'Source retry limit reached for this topic today.' }, 429, origin);
    if (previous?.next_retry_at && new Date(previous.next_retry_at).getTime() > Date.now()) {
      return json({ error: 'Source retry is cooling down. Try another topic.' }, 429, origin);
    }
    // Source availability is checked before claiming the one daily Gemini attempt.
    const page = await searchTatoeba(keyword);
    const reference = page.pairs.find((pair) => pair.validationStatus === 'eligible');
    if (!reference) throw new GenerationError('invalid_response', 'No licensed direct translation was found.');
    // Read-only model lookup precedes the quota claim. A missing model must not consume the daily generation slot.
    await checkGeminiModel(Deno.env.get('GEMINI_MODEL')!, Deno.env.get('GEMINI_API_KEY')!);
    const claim = await rest(url, serviceKey, 'rpc/englify_claim_real_english_job', { method: 'POST',
      body: JSON.stringify({ p_key: idempotencyKey, p_scheduled_for: new Date().toISOString() }) });
    if (!claim.ok) return json({ error: claim.status === 400 ? 'Daily generation limit reached.' : 'Generation job unavailable.' },
      claim.status === 400 ? 429 : 503, origin);
    jobId = await claim.json();
    if (!validUuid(jobId)) return json({ error: 'This generation slot has already run.' }, 409, origin);
    const generated = await generateLesson({ topic: topic.slug, difficulty: difficulty as 'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2',
      reference, model: Deno.env.get('GEMINI_MODEL')!, apiKey: Deno.env.get('GEMINI_API_KEY')!,
      maxOutputTokens: settings.maximum_output_tokens });
    const existing = await rest(url, serviceKey, 'real_english_phrases?select=english_text&order=created_at.desc&limit=500');
    if (!existing.ok) throw new GenerationError('provider', 'Duplicate check unavailable.');
    const existingPhrases = await existing.json() as { english_text?: unknown }[];
    if (!Array.isArray(existingPhrases) || existingPhrases.some((phrase) => typeof phrase.english_text !== 'string')) {
      throw new GenerationError('invalid_response', 'Duplicate check returned invalid data.');
    }
    if (existingPhrases.some((phrase) => isNearDuplicate(generated.lesson.expression, phrase.english_text as string))) {
      throw new GenerationError('invalid_response', 'A similar lesson expression already exists.');
    }
    const enrichment = await enrichLesson(generated.lesson, fetch,
      Deno.env.get('DICTIONARY_ENRICHMENT_ENABLED') === 'true');
    const store = await rest(url, serviceKey, 'rpc/englify_store_real_english_draft', { method: 'POST',
      body: JSON.stringify({ p_job_id: jobId, p_topic_id: topicId,
        p_content: { ...generated.lesson, enrichment }, p_source: reference }) });
    if (!store.ok) throw new GenerationError('invalid_response', 'Draft failed database quality or duplicate checks.');
    const lessonId = await store.json();
    await rest(url, serviceKey, `real_english_generation_jobs?id=eq.${jobId}`, { method: 'PATCH',
      body: JSON.stringify({ usage_metadata: generated.usage }) }).catch(() => undefined);
    return json({ jobId, lessonId, status: 'pending_review' }, 201, origin);
  } catch (cause) {
    const kind = cause instanceof GenerationError ? cause.kind : cause instanceof TatoebaError ? `source_${cause.kind}` : 'provider';
    if (!jobId) await rest(url, serviceKey, 'rpc/englify_record_real_english_preflight_failure', {
      method: 'POST', body: JSON.stringify({ p_key: idempotencyKey, p_topic_id: topicId, p_slot: slot,
        p_code: kind, p_message: cause instanceof Error ? cause.message.slice(0,180) : 'Source preflight failed.' }),
    }).catch(() => undefined);
    if (jobId) await rest(url, serviceKey, `real_english_generation_jobs?id=eq.${jobId}`, { method: 'PATCH',
      body: JSON.stringify({ status: kind === 'quota' ? 'quota_blocked' : 'failed', completed_at: new Date().toISOString(),
        lease_expires_at: null, error_code: kind, error_message: cause instanceof Error ? cause.message.slice(0, 180) : 'Generation failed.' }),
    }).catch(() => undefined);
    return json({ error: kind === 'quota' ? 'Free tier quota reached.' : kind === 'invalid_response'
      ? 'No validated lesson could be created.' : kind === 'source_rate_limited'
        ? 'Tatoeba rate limit reached; another topic can continue.' : jobId ? 'Generation provider unavailable.'
          : 'Licensed source sentences are unavailable. Try again later.', code: kind },
    kind === 'quota' || kind === 'source_rate_limited' ? 429 : kind === 'invalid_response' ? 422 : 502, origin);
  }
});
