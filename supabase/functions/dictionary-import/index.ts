// Persist only words independently verified against Free Dictionary API.
// The service-role key stays inside the Edge Function, never on the device.
declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (request: Request) => Promise<Response>): void;
};

const reply = (value: unknown, status = 200, origin?: string) => new Response(JSON.stringify(value), {
  status, headers: { 'Content-Type': 'application/json', 'Vary': 'Origin',
    ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}) },
});

function publicKey(): string | undefined {
  const direct = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  if (direct) return direct;
  try {
    const keys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}') as Record<string, string>;
    return keys.default ?? Object.values(keys)[0];
  } catch { return undefined; }
}

Deno.serve(async (request) => {
  const origin = request.headers.get('Origin') ?? undefined;
  const allowed = (Deno.env.get('EDGE_ALLOWED_ORIGINS') ?? '').split(',').map((item) => item.trim()).filter(Boolean);
  if (origin && !allowed.includes(origin)) return reply({ error: 'Origin not allowed.' }, 403);
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: {
    'Vary': 'Origin', ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}),
    'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  } });
  if (request.method !== 'POST') return reply({ error: 'Method not allowed.' }, 405, origin);
  const url = Deno.env.get('SUPABASE_URL');
  const key = publicKey();
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const bearer = request.headers.get('Authorization') ?? '';
  if (!url || !key || !serviceKey) return reply({ error: 'Dictionary import not configured.' }, 503, origin);
  if (!/^Bearer [A-Za-z0-9._-]+$/.test(bearer)) return reply({ error: 'Sign in required.' }, 401, origin);
  try {
    const auth = await fetch(`${url}/auth/v1/user`, {
      headers: { apikey: key, Authorization: bearer }, signal: AbortSignal.timeout(5000),
    });
    if (!auth.ok) return reply({ error: 'Session expired.' }, 401, origin);
  } catch { return reply({ error: 'Authentication unavailable.' }, 503, origin); }

  let word: string;
  try {
    const raw = await request.text();
    if (raw.length > 300) return reply({ error: 'Invalid word.' }, 422, origin);
    const parsed = JSON.parse(raw) as { word?: unknown };
    word = typeof parsed?.word === 'string' ? parsed.word.trim().toLowerCase() : '';
  } catch { return reply({ error: 'Invalid JSON.' }, 400, origin); }
  if (!/^[a-z]+(?:['’-][a-z]+)*$/.test(word) || word.length > 80) {
    return reply({ error: 'Enter one English word.' }, 422, origin);
  }
  const headers = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` };
  const path = `${url}/rest/v1/dictionary_entries`;
  try {
    const query = `?language=eq.en&normalized_term=eq.${encodeURIComponent(word)}&select=id,is_published&limit=1`;
    const existing = await fetch(path + query, { headers, signal: AbortSignal.timeout(7000) });
    if (!existing.ok) return reply({ error: 'Dictionary storage unavailable.' }, 503, origin);
    const rows = await existing.json() as { id: string; is_published: boolean }[];
    if (rows.length) return rows[0].is_published ? reply({ id: rows[0].id }, 200, origin)
      : reply({ error: 'Word is awaiting editorial approval.' }, 409, origin);

    const provider = await fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`, {
      signal: AbortSignal.timeout(7000),
    });
    if (provider.status === 404) return reply({ error: 'Word was not found.' }, 404, origin);
    if (!provider.ok) return reply({ error: 'Dictionary provider unavailable.' }, 502, origin);
    const content = await provider.json() as { word?: string; phonetic?: string;
      meanings?: { partOfSpeech?: string; definitions?: { definition?: string; example?: string }[] }[];
      license?: { name?: string }; phonetics?: { audio?: string }[] }[];
    const first = Array.isArray(content) ? content.find((entry) => entry?.meanings?.length) : undefined;
    const sense = first?.meanings?.flatMap((meaning) => (meaning.definitions ?? []).map((definition) => ({
      ...definition, partOfSpeech: meaning.partOfSpeech,
    }))).find((definition) => typeof definition.definition === 'string' && !!definition.definition.trim());
    if (!first || !sense?.definition || typeof first.word !== 'string' || first.word.toLowerCase() !== word) {
      return reply({ error: 'Invalid dictionary provider response.' }, 502, origin);
    }
    const audio = first.phonetics?.map((entry) => entry.audio).find((value) =>
      typeof value === 'string' && value.startsWith('https://')) ?? null;
    const record = {
      language: 'en', term: first.word.slice(0, 80), normalized_term: word,
      definition: sense.definition.slice(0, 2000), translation: null,
      part_of_speech: sense.partOfSpeech?.slice(0, 60) ?? null,
      example: sense.example?.slice(0, 1000) ?? null, ipa: first.phonetic?.slice(0, 120) ?? null,
      audio_url: audio, source_name: 'Free Dictionary API',
      license_id: first.license?.name?.slice(0, 120) ?? 'See provider license', is_published: true,
    };
    const inserted = await fetch(path + '?on_conflict=language,normalized_term', {
      method: 'POST', headers: { ...headers, 'Content-Type': 'application/json', Prefer: 'resolution=ignore-duplicates,return=representation' },
      body: JSON.stringify(record), signal: AbortSignal.timeout(7000),
    });
    if (!inserted.ok) return reply({ error: 'Could not store dictionary word.' }, 503, origin);
    const created = await inserted.json() as { id: string }[];
    if (created.length) return reply({ id: created[0].id }, 200, origin);
    const concurrent = await fetch(path + query, { headers, signal: AbortSignal.timeout(7000) });
    const latest = concurrent.ok ? await concurrent.json() as { id: string; is_published: boolean }[] : [];
    if (latest[0]?.is_published) return reply({ id: latest[0].id }, 200, origin);
    return reply({ error: 'Word could not be saved.' }, 409, origin);
  } catch { return reply({ error: 'Dictionary request failed. Try again later.' }, 503, origin); }
});
