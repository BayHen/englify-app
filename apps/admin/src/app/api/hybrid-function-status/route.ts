import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  const bearer = request.headers.get('authorization');
  if (!url || !/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(url) || !key || !bearer?.startsWith('Bearer ')) {
    return NextResponse.json({ status: 'unverified', reason: 'Configuration or session unavailable.' });
  }
  try {
    // A GET never generates content. The deployed function answers 405 after JWT verification.
    const response = await fetch(`${url}/functions/v1/real-english-generate`, {
      method: 'GET', cache: 'no-store', signal: AbortSignal.timeout(6000),
      headers: { apikey: key, Authorization: bearer },
    });
    return NextResponse.json({ status: response.status === 405 ? 'deployed' : response.status === 404 ? 'missing' : 'unverified',
      httpStatus: response.status });
  } catch {
    return NextResponse.json({ status: 'unverified', reason: 'Gateway unreachable or timed out.' });
  }
}
