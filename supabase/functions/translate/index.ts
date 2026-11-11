// @ts-ignore Deno requires the explicit TypeScript extension; mobile tsc only imports this file in tests.
import { ProviderError, translateWithMyMemory, utf8ByteLength, type TranslationLanguage } from './provider.ts';

declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (request: Request) => Promise<Response>): void;
};

const allowedLanguage = (value: unknown): value is TranslationLanguage => value === 'en' || value === 'vi';
const json = (value: unknown, status = 200, origin?: string) => new Response(JSON.stringify(value), {
  status, headers: { 'Content-Type': 'application/json; charset=utf-8', 'Vary': 'Origin',
    ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}) },
});
function publicKey(): string | null {
  const direct = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  if (direct) return direct;
  try {
    const keys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}') as Record<string, string>;
    return keys.default ?? Object.values(keys)[0] ?? null;
  } catch { return null; }
}

Deno.serve(async (request) => {
  const origin = request.headers.get('Origin') ?? undefined;
  const allowed = (Deno.env.get('TRANSLATE_ALLOWED_ORIGINS') ?? '').split(',').map((entry) => entry.trim()).filter(Boolean);
  if (origin && !allowed.includes(origin)) return json({ error: 'Origin not allowed.' }, 403);
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: {
    'Vary': 'Origin', ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}),
    'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  } });
  if (request.method !== 'POST') return json({ error: 'Method not allowed.' }, 405, origin);
  const authorization = request.headers.get('Authorization') ?? '';
  if (!/^Bearer [A-Za-z0-9._-]+$/.test(authorization)) return json({ error: 'Authentication required.' }, 401, origin);
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const key = publicKey();
  if (!supabaseUrl || !key) return json({ error: 'Translation service is not configured.' }, 503, origin);
  const authHeaders = { apikey: key, Authorization: authorization };
  let verified: Response;
  try {
    verified = await fetch(`${supabaseUrl}/auth/v1/user`, { headers: authHeaders, signal: AbortSignal.timeout(5000) });
  } catch { return json({ error: 'Authentication service unavailable.' }, 503, origin); }
  if (!verified.ok) return json({ error: 'Session expired. Sign in again.' }, 401, origin);
  const lengthHeader = Number(request.headers.get('Content-Length'));
  if (Number.isFinite(lengthHeader) && lengthHeader > 10000) return json({ error: 'Input is too long.' }, 413, origin);
  let payload: unknown;
  try {
    const raw = await request.text();
    if (raw.length > 10000) return json({ error: 'Input is too long.' }, 413, origin);
    payload = JSON.parse(raw);
  } catch { return json({ error: 'Invalid JSON request.' }, 400, origin); }
  const input = payload as Record<string, unknown> | null;
  const text = typeof input?.text === 'string' ? input.text.trim() : '';
  const source = input?.sourceLanguage;
  const target = input?.targetLanguage;
  const characterCount = Array.from(text).length;
  if (!text || utf8ByteLength(text) > 500 || !allowedLanguage(source) || !allowedLanguage(target)
      || source === target || Object.keys(input ?? {}).some((field) => !['text', 'sourceLanguage', 'targetLanguage'].includes(field))) {
    return json({ error: 'Enter a sentence of at most 500 UTF-8 bytes and choose English/Vietnamese languages.' }, 422, origin);
  }
  // This SECURITY DEFINER RPC reserves a per-user and global quota atomically, without storing text.
  let reservation: Response;
  try {
    reservation = await fetch(`${supabaseUrl}/rest/v1/rpc/englify_reserve_translation`, {
      method: 'POST', headers: { ...authHeaders, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_characters: characterCount }), signal: AbortSignal.timeout(5000),
    });
  } catch { return json({ error: 'Translation quota service unavailable.' }, 503, origin); }
  if (!reservation.ok) {
    if (reservation.status === 401 || reservation.status === 403) return json({ error: 'Session expired. Sign in again.' }, 401, origin);
    const detail = await reservation.json().catch(() => ({})) as { code?: string };
    return json({ error: detail.code === 'P0001' ? 'Translation limit reached. Try again later.' : 'Translation quota unavailable.' },
      detail.code === 'P0001' ? 429 : 503, origin);
  }
  try {
    const translated = await translateWithMyMemory(text, source, target);
    return json({ translatedText: translated.translatedText,
      sourceLanguage: source, targetLanguage: target, provider: 'mymemory' }, 200, origin);
  } catch (cause) {
    const kind = cause instanceof ProviderError ? cause.kind : 'upstream';
    return json({ error: kind === 'timeout' ? 'Translation timed out.' : kind === 'rate_limited'
      ? 'Translation provider daily limit reached. Try again later.' : kind === 'no_translation'
      ? 'No distinct translation was found. Try a short phrase with more context.' : 'Translation provider unavailable.' },
    kind === 'timeout' ? 504 : kind === 'rate_limited' ? 429
      : kind === 'invalid_input' || kind === 'no_translation' ? 422 : 502, origin);
  }
});
