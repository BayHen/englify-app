import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiError, apiUrl, getJson, isHealthResponse } from './api';

afterEach(() => vi.unstubAllGlobals());

describe('typed API client', () => {
  it('normalizes the configured base and path', () => {
    expect(apiUrl('/health', 'http://localhost:8000/api/v1/')).toBe('http://localhost:8000/api/v1/health');
  });

  it('accepts a valid response and rejects invalid data', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ data: { status: 'ok' }, error: null }) }));
    await expect(getJson('/health', isHealthResponse)).resolves.toEqual({ data: { status: 'ok' }, error: null });
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ status: 'wrong' }) }));
    await expect(getJson('/health', isHealthResponse)).rejects.toBeInstanceOf(ApiError);
  });

  it('preserves HTTP error status', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 403 }));
    await expect(getJson('/health', isHealthResponse)).rejects.toMatchObject({ status: 403 });
  });
});
