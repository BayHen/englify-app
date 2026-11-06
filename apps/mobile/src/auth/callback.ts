export type AuthCallback =
  | { kind: 'code'; code: string; recovery: boolean }
  | { kind: 'error'; message: string }
  | { kind: 'none' };

export function parseAuthCallback(url: string): AuthCallback {
  const fragment = url.split('#', 2)[1] ?? '';
  const query = url.split('?', 2)[1]?.split('#', 1)[0] ?? '';
  const params = new URLSearchParams(query);
  new URLSearchParams(fragment).forEach((value, name) => params.set(name, value));
  const error = params.get('error_description') ?? params.get('error');
  if (error) return { kind: 'error', message: error };
  const code = params.get('code');
  if (!code) return { kind: 'none' };
  return {
    kind: 'code', code,
    recovery: params.get('type') === 'recovery' || url.includes('reset-password'),
  };
}
