import { describe, expect, it } from 'vitest';
import { ApiError } from '@/lib/api';
import { preferenceErrorKey } from './errors';

describe('localized preference errors', () => {
  it.each([
    [0, 'preferences.error.network'], [401, 'preferences.error.auth'], [403, 'preferences.error.auth'],
    [409, 'preferences.error.conflict'], [422, 'preferences.error.invalid'], [429, 'preferences.error.rateLimit'],
  ] as const)('maps status %s to %s', (status, key) => {
    expect(preferenceErrorKey(new ApiError(status, 'technical detail'), 'preferences.error.save')).toBe(key);
  });

  it('keeps a safe fallback for unexpected failures', () => {
    expect(preferenceErrorKey(new Error('unexpected'), 'preferences.error.save')).toBe('preferences.error.save');
  });
});
