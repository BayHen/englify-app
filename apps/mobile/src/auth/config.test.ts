import { describe, expect, it } from 'vitest';
import { getSupabaseConfigStatus } from './config';

describe('Supabase public configuration', () => {
  const key = 'sb_publishable_example_key_123';
  it('requires a real Supabase project origin', () => {
    expect(getSupabaseConfigStatus(undefined, key)).toBe('missing_url');
    expect(getSupabaseConfigStatus('https://YOUR_PROJECT_REF.supabase.co', key)).toBe('missing_url');
    expect(getSupabaseConfigStatus('https://sample.on.expo.app', key)).toBe('invalid_url');
    expect(getSupabaseConfigStatus('http://project.supabase.co', key)).toBe('invalid_url');
    expect(getSupabaseConfigStatus('https://project.supabase.co/other', key)).toBe('invalid_url');
  });
  it('rejects missing or secret key types', () => {
    expect(getSupabaseConfigStatus('https://project.supabase.co', undefined)).toBe('missing_key');
    expect(getSupabaseConfigStatus('https://project.supabase.co', 'YOUR_PUBLISHABLE_KEY')).toBe('missing_key');
    expect(getSupabaseConfigStatus('https://project.supabase.co', 'sb_secret_never_mobile')).toBe('invalid_key');
  });
  it('accepts the public key format', () => {
    expect(getSupabaseConfigStatus('https://project.supabase.co', key)).toBe('ready');
  });
});
