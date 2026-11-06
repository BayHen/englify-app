import { getSupabase } from './supabase';
import { supabaseConfigStatus } from './config';

export type Check = { label: string; status: 'passed' | 'failed' | 'not_tested'; detail: string };

export async function runAuthDiagnostic(): Promise<Check[]> {
  const checks: Check[] = [
    { label: 'Project URL and publishable key', status: supabaseConfigStatus === 'ready' ? 'passed' : 'failed', detail: supabaseConfigStatus },
  ];
  if (supabaseConfigStatus !== 'ready') return checks;

  const url = process.env.EXPO_PUBLIC_SUPABASE_URL!;
  const key = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY!;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 5000);
    let response: Response;
    try {
      response = await fetch(`${url}/auth/v1/health`, { headers: { apikey: key }, signal: controller.signal });
    } finally { clearTimeout(timer); }
    checks.push({ label: 'Auth service connectivity', status: response.ok ? 'passed' : 'failed', detail: response.ok ? 'Auth health endpoint responded' : `HTTP ${response.status}; verify project URL and key` });
    if (!response.ok) return checks;
  } catch {
    checks.push({ label: 'Auth service connectivity', status: 'failed', detail: 'Network error or 5-second timeout' });
    return checks;
  }

  const client = getSupabase();
  const { data: sessionData, error: sessionError } = await client.auth.getSession();
  if (sessionError) checks.push({ label: 'Session restoration', status: 'failed', detail: 'Stored session could not be read' });
  else if (!sessionData.session) checks.push({ label: 'Session restoration', status: 'not_tested', detail: 'Sign in with a developer account to verify restoration' });
  else {
    const { error } = await client.auth.getUser();
    checks.push({ label: 'Authenticated user lookup', status: error ? 'failed' : 'passed', detail: error ? 'Session rejected or network unavailable' : 'Current session verified by Auth server' });
  }

  if (!sessionData.session || sessionError) {
    checks.push({ label: 'profiles and user_preferences schema', status: 'not_tested', detail: 'Sign in with a developer account before querying private tables' });
    checks.push({ label: 'Cross-user RLS isolation', status: 'not_tested', detail: 'Requires two developer-managed test accounts and the SQL isolation test' });
    return checks;
  }
  for (const table of ['profiles', 'user_preferences'] as const) {
    const { error } = await client.from(table).select('id').limit(1);
    checks.push({
      label: `${table} schema`,
      status: error ? 'failed' : 'passed',
      detail: error ? (error.code === '42P01' || error.code === 'PGRST205' ? 'Table or API schema missing' : error.code === '42501' ? 'Authorization/RLS denied' : `Database request failed (${error.code || 'unknown'})`) : 'Table query completed; row access is not proven',
    });
  }
  checks.push({ label: 'Cross-user RLS isolation', status: 'not_tested', detail: 'Requires two developer-managed test accounts and the SQL isolation test' });
  return checks;
}
