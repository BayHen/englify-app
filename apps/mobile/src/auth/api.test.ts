import { afterEach, describe, expect, it, vi } from 'vitest';
import { privateRequest, type Profile } from './api';

const originalFetch = globalThis.fetch;
afterEach(() => { globalThis.fetch = originalFetch; });

describe('authenticated API requests', () => {
  it('sends the access token and parses a profile envelope', async () => {
    const profile: Profile = { id: 'user-id', display_name: 'Learner', preferences: null };
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ data: profile, error: null }) });
    globalThis.fetch = fetchMock;
    await expect(privateRequest<Profile>('/me', 'access-token')).resolves.toEqual(profile);
    const [url, options] = fetchMock.mock.calls[0];
    expect(url).toContain('/api/v1/me');
    expect(options.headers.Authorization).toBe('Bearer access-token');
  });
  it('preserves unauthorized status so the session can be cleared', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false, status: 401,
      json: async () => ({ data: null, error: { code: 'invalid_token', message: 'Expired' } }),
    });
    await expect(privateRequest('/me', 'expired')).rejects.toMatchObject({ status: 401, message: 'Expired' });
  });
  it('explains a failed connection without clearing the signed-in session', async () => {
    globalThis.fetch = vi.fn().mockRejectedValue(new TypeError('Failed to fetch'));
    await expect(privateRequest('/me', 'access-token')).rejects.toMatchObject({
      status: 0,
      message: 'Cannot reach the learning API. Check that FastAPI is running and the API URL is reachable.',
    });
  });
});
