import { NextRequest, NextResponse } from 'next/server';

export const maxDuration = 90;

export async function POST(request: NextRequest) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  const bearer = request.headers.get('authorization');
  if (!url || !/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(url) || !key) {
    return NextResponse.json({ error: 'Supabase is not configured.' }, { status: 503 });
  }
  if (!bearer || !/^Bearer [A-Za-z0-9._-]+$/.test(bearer)) {
    return NextResponse.json({ error: 'Sign in again.' }, { status: 401 });
  }
  try {
    const raw = await request.text();
    if (raw.length > 2000) return NextResponse.json({ error: 'Request too large.' }, { status: 413 });
    const upstream = await fetch(`${url}/functions/v1/real-english-generate`, {
      method: 'POST', cache: 'no-store', signal: AbortSignal.timeout(75000),
      headers: { apikey: key, Authorization: bearer, 'Content-Type': 'application/json' },
      body: raw,
    });
    const result: unknown = await upstream.json().catch(() => ({ error: 'Invalid generation response.' }));
    return NextResponse.json(result, { status: upstream.status });
  } catch {
    return NextResponse.json({ error: 'Generation service is unavailable or timed out.' }, { status: 503 });
  }
}
