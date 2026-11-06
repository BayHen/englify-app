import { describe, expect, it } from 'vitest';
import { parseAuthCallback } from './callback';

describe('Supabase email link callback', () => {
  it('extracts one-time confirmation codes and recovery intent', () => {
    expect(parseAuthCallback('englifyquest://auth-callback?code=signup-code')).toEqual({
      kind: 'code', code: 'signup-code', recovery: false,
    });
    expect(parseAuthCallback('englifyquest://reset-password?code=reset-code')).toEqual({
      kind: 'code', code: 'reset-code', recovery: true,
    });
    expect(parseAuthCallback('englifyquest://auth-callback?type=recovery#code=reset-code')).toEqual({
      kind: 'code', code: 'reset-code', recovery: true,
    });
  });
  it('never accepts injected session tokens', () => {
    expect(parseAuthCallback('englifyquest://auth-callback#access_token=access&refresh_token=refresh')).toEqual({ kind: 'none' });
  });
  it('surfaces expired-link errors', () => {
    expect(parseAuthCallback('englifyquest://auth-callback#error=access_denied&error_description=Expired+link')).toEqual({
      kind: 'error', message: 'Expired link',
    });
  });
});
