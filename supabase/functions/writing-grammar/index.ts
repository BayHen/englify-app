// Optional self-hosted LanguageTool enrichment. Rule feedback is already durable in PostgreSQL.
declare const Deno: { env: { get(name: string): string | undefined }; serve(handler: (request: Request) => Promise<Response>): void };

const reply = (body: unknown, status = 200, origin?: string) => new Response(JSON.stringify(body), {
  status, headers: { 'Content-Type': 'application/json; charset=utf-8', Vary: 'Origin',
    ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}) },
});
const validOrigin = (origin?: string) => !origin || (Deno.env.get('EDGE_ALLOWED_ORIGINS') ?? '').split(',')
  .map((value) => value.trim()).includes(origin);

Deno.serve(async (request) => {
  const origin = request.headers.get('Origin') ?? undefined;
  if (!validOrigin(origin)) return reply({ error: 'Origin not allowed.' }, 403);
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: {
    Vary: 'Origin', ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}),
    'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  } });
  if (request.method !== 'POST') return reply({ error: 'Method not allowed.' }, 405, origin);
  const bearer = request.headers.get('Authorization') ?? '';
  if (!/^Bearer [A-Za-z0-9._-]+$/.test(bearer)) return reply({ error: 'Authentication required.' }, 401, origin);
  const base = Deno.env.get('SUPABASE_URL');
  const publicKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!base || !publicKey) return reply({ error: 'Learning service is not configured.' }, 503, origin);
  let input: { submissionId?: unknown };
  try {
    const raw = await request.text();
    if (raw.length > 1000) return reply({ error: 'Request is too large.' }, 413, origin);
    input = JSON.parse(raw) as { submissionId?: unknown };
  } catch { return reply({ error: 'Invalid request.' }, 400, origin); }
  if (typeof input?.submissionId !== 'string' || !/^[0-9a-f-]{36}$/i.test(input.submissionId)) {
    return reply({ error: 'Invalid submission ID.' }, 422, origin);
  }
  const userHeaders = { apikey: publicKey, Authorization: bearer };
  try {
    const verified = await fetch(`${base}/auth/v1/user`, { headers: userHeaders, signal: AbortSignal.timeout(5000) });
    if (!verified.ok) return reply({ error: 'Session expired. Sign in again.' }, 401, origin);
    const user = await verified.json() as { id?: string };
    if (!user.id) return reply({ error: 'Invalid session.' }, 401, origin);
    const lookup = new URL(`${base}/rest/v1/writing_submissions`);
    lookup.searchParams.set('select', 'id,body,user_id');
    lookup.searchParams.set('id', `eq.${input.submissionId}`);
    lookup.searchParams.set('user_id', `eq.${user.id}`);
    const rows = await fetch(lookup, { headers: userHeaders, signal: AbortSignal.timeout(5000) });
    if (!rows.ok) return reply({ error: 'Writing history is unavailable.' }, 503, origin);
    const submissions = await rows.json() as { id: string; body: string; user_id: string }[];
    const submission = submissions[0];
    if (!submission || submission.user_id !== user.id) return reply({ error: 'Submission not found.' }, 404, origin);
    const toolUrl = Deno.env.get('LANGUAGETOOL_URL');
    if (!toolUrl || !serviceKey) return reply({ status: 'unavailable' }, 200, origin);
    let provider: URL;
    try {
      provider = new URL(toolUrl);
      if (!['http:', 'https:'].includes(provider.protocol) || provider.username || provider.password) throw new Error('bad URL');
    } catch { return reply({ status: 'unavailable' }, 200, origin); }
    const grammar = await fetch(`${provider.origin}/v2/check`, {
      method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ language: 'en-US', text: submission.body }), signal: AbortSignal.timeout(4000),
    });
    if (!grammar.ok) return reply({ status: 'unavailable' }, 200, origin);
    const payload = await grammar.json() as { matches?: unknown };
    if (!Array.isArray(payload.matches)) return reply({ status: 'unavailable' }, 200, origin);
    const matches = payload.matches.slice(0, 20).map((raw) => {
      const item = raw as { message?: unknown; offset?: unknown; length?: unknown; replacements?: { value?: unknown }[] };
      return { message: String(item.message ?? '').slice(0, 300), offset: Number(item.offset),
        length: Number(item.length), replacements: (Array.isArray(item.replacements) ? item.replacements : [])
          .slice(0, 3).map((value) => String(value.value ?? '').slice(0, 100)) };
    });
    if (matches.some((match) => !Number.isInteger(match.offset) || match.offset < 0 || !Number.isInteger(match.length)
      || match.length < 0 || match.offset + match.length > submission.body.length)) {
      return reply({ status: 'unavailable' }, 200, origin);
    }
    const saved = await fetch(`${base}/rest/v1/rpc/englify_attach_grammar_feedback`, {
      method: 'POST', headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`,
        'Content-Type': 'application/json' },
      body: JSON.stringify({ p_submission_id: submission.id, p_matches: matches }), signal: AbortSignal.timeout(5000),
    });
    if (!saved.ok || (await saved.json()) !== true) return reply({ status: 'unavailable' }, 200, origin);
    return reply({ status: 'available' }, 200, origin);
  } catch { return reply({ status: 'unavailable' }, 200, origin); }
});
