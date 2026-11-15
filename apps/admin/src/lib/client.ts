import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { supabaseAdminRequest } from './supabase-admin';

let client: SupabaseClient | null = null;

export function getSupabase(): SupabaseClient {
  if (client) return client;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  const hosted = !!url && /^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(url);
  const local = process.env.NODE_ENV !== 'production' && !!url && /^http:\/\/(127\.0\.0\.1|localhost):54321$/.test(url);
  if (!url || !(hosted && key?.startsWith('sb_publishable_') || local && !!key && (key.startsWith('sb_publishable_') || key.startsWith('eyJ')))) {
    throw new Error('Configure the public Supabase URL and publishable key in apps/admin/.env.local.');
  }
  client = createClient(url, key, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: false } });
  return client;
}

export async function adminRequest<T>(path: string, init: RequestInit = {}): Promise<T> {
  if (process.env.NEXT_PUBLIC_SUPABASE_ADMIN_ENABLED === 'true') {
    return supabaseAdminRequest<T>(getSupabase(), path, init);
  }
  const { data, error } = await getSupabase().auth.getSession();
  if (error || !data.session) throw new Error('Your session expired. Sign in again.');
  const base = process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, '') ?? 'http://127.0.0.1:8000/api/v1';
  const response = await fetch(`${base}/admin${path}`, {
    ...init,
    cache: 'no-store',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${data.session.access_token}`, ...init.headers },
  });
  const body = await response.json().catch(() => null);
  if (!response.ok) throw new Error(body?.error?.message ?? `Admin API error (${response.status})`);
  return body.data as T;
}
