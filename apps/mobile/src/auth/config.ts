export type SupabaseConfigStatus = 'ready' | 'missing_url' | 'invalid_url' | 'missing_key' | 'invalid_key';

export function getSupabaseConfigStatus(url?: string, key?: string): SupabaseConfigStatus {
  if (!url || url.includes('YOUR_PROJECT_REF')) return 'missing_url';
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== 'https:' || !/^[a-z0-9-]+\.supabase\.co$/.test(parsed.hostname)
      || parsed.pathname !== '/' || parsed.search || parsed.hash || parsed.username || parsed.password) {
      return 'invalid_url';
    }
  } catch { return 'invalid_url'; }
  if (!key || key === 'YOUR_PUBLISHABLE_KEY') return 'missing_key';
  if (!/^sb_publishable_[A-Za-z0-9_-]+$/.test(key)) return 'invalid_key';
  return 'ready';
}

export const supabaseConfigStatus = getSupabaseConfigStatus(
  process.env.EXPO_PUBLIC_SUPABASE_URL,
  process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
);
