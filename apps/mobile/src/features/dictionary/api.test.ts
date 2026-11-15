import { beforeEach, describe, expect, it, vi } from 'vitest';
import { saveWord, searchDictionary } from './api';

const state = vi.hoisted(() => ({ client: null as unknown }));
vi.mock('@/auth/supabase', () => ({ getSupabase: () => state.client }));

function query<T>(data: T, error: { message: string } | null = null, status = 200) {
  const builder = {
    select: vi.fn(), eq: vi.fn(), is: vi.fn(), order: vi.fn(), limit: vi.fn(),
    ilike: vi.fn(), in: vi.fn(), single: vi.fn(), maybeSingle: vi.fn(),
    upsert: vi.fn(), delete: vi.fn(), then: (resolve: (result: unknown) => unknown) =>
      Promise.resolve({ data, error, status }).then(resolve),
  };
  for (const name of ['select', 'eq', 'is', 'order', 'limit', 'ilike', 'in', 'delete'] as const) builder[name].mockReturnValue(builder);
  builder.single.mockResolvedValue({ data, error, status });
  builder.maybeSingle.mockResolvedValue({ data, error, status });
  builder.upsert.mockResolvedValue({ data: null, error, status });
  return builder;
}

beforeEach(() => { state.client = null; });

describe('dictionary Supabase repository', () => {
  it('reads published English words without calling FastAPI', async () => {
    const word = { id: 'word-1', term: 'hello', definition: 'greeting' };
    const words = query([word]);
    const from = vi.fn().mockReturnValue(words);
    state.client = { auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) }, from };
    await expect(searchDictionary('')).resolves.toEqual([word]);
    expect(from).toHaveBeenCalledWith('dictionary_entries');
    expect(words.eq).toHaveBeenCalledWith('language', 'en');
    expect(words.eq).toHaveBeenCalledWith('is_published', true);
    expect(words.is).toHaveBeenCalledWith('archived_at', null);
  });

  it('saves with the authenticated UID and an idempotent unique conflict', async () => {
    const word = { id: 'word-1', term: 'hello' };
    const catalog = query(word);
    const insert = query(null);
    const saved = query({ id: 'saved-1', created_at: '2026-11-10T00:00:00Z', next_review_at: null });
    const from = vi.fn().mockReturnValueOnce(catalog).mockReturnValueOnce(insert).mockReturnValueOnce(saved);
    state.client = { auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) }, from };
    const result = await saveWord('word-1', 'caller-supplied-token');
    expect(result.id).toBe('saved-1');
    expect(result.word).toEqual(word);
    expect(insert.upsert).toHaveBeenCalledWith(
      { user_id: 'user-1', entry_id: 'word-1', note: '' },
      { onConflict: 'user_id,entry_id', ignoreDuplicates: true },
    );
  });

  it('keeps network failure distinguishable for offline queueing', async () => {
    const words = query(null, { message: 'fetch failed' }, 0);
    state.client = { auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) }, from: () => words };
    await expect(searchDictionary('')).rejects.toMatchObject({ status: 0 });
  });
});
