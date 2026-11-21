import { describe, expect, it } from 'vitest';
import { accountDestination, authenticationRedirects } from './access';

describe('account route policy', () => {
  it('prompts guests for protected routes while keeping public tools open', () => {
    expect(authenticationRedirects('guest', false, false, false, null).privateRoute).toBe('/login-required');
    for (const route of ['/home', '/dictionary', '/translation', '/profile']) {
      expect(accountDestination(route)).toBeNull();
    }
  });

  it('accepts known protected deep links only', () => {
    expect(accountDestination('/lesson/abc-123')).toBe('/lesson/abc-123');
    expect(accountDestination('/explore')).toBe('/explore');
    for (const route of ['//external.test', '/lesson/../home', '/reset-password', '/not-a-route']) {
      expect(accountDestination(route)).toBeNull();
    }
  });

  it('sends an onboarded learner to the requested destination or Home', () => {
    expect(authenticationRedirects('authenticated', true, true, true, '/practice').publicAuth).toBe('/practice');
    expect(authenticationRedirects('authenticated', true, true, true, null).publicAuth).toBe('/home');
    expect(authenticationRedirects('authenticated', true, true, false, '/practice').publicAuth).toBe('/onboarding');
  });

  it('sends protected screens to Home on sign-out or profile recovery', () => {
    expect(authenticationRedirects('signingOut', false, false, false, null).privateRoute).toBe('/home');
    expect(authenticationRedirects('authenticated', true, false, false, null).privateRoute).toBe('/home');
  });
});
