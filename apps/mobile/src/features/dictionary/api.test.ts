import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
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
afterEach(() => { vi.unstubAllGlobals(); vi.unstubAllEnvs(); });

describe('dictionary Supabase repository', () => {
  it('searches published words as a guest without importing or checking an account', async () => {
    const getSession = vi.fn();
    const invoke = vi.fn();
    const words = query([{ id: 'word-1', term: 'hello', definition: 'greeting' }]);
    state.client = { auth: { getSession }, functions: { invoke }, from: vi.fn().mockReturnValue(words) };
    await expect(searchDictionary('hello', false)).resolves.toHaveLength(1);
    expect(words.eq).toHaveBeenCalledWith('is_published', true);
    const fetcher = vi.fn().mockResolvedValue(new Response(null, { status: 404 }));
    vi.stubGlobal('fetch', fetcher);
    await expect(searchDictionary('not-in-catalog', false)).resolves.toHaveLength(1);
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(getSession).not.toHaveBeenCalled();
    expect(invoke).not.toHaveBeenCalled();
  });
  it('finds an exact guest word outside the catalog without importing it', async () => {
    const invoke = vi.fn();
    state.client = { from: vi.fn().mockReturnValue(query([])), functions: { invoke } };
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify([{
      word: 'medium', meanings: [{ partOfSpeech: 'noun', definitions: [{ definition: 'A means of communication.' }] }],
    }])));
    vi.stubGlobal('fetch', fetcher);
    await expect(searchDictionary('medium', false)).resolves.toEqual([
      expect.objectContaining({ id: 'public-lookup:medium', term: 'medium', translation: null, definition: 'A means of communication.' }),
    ]);
    expect(fetcher).toHaveBeenCalledWith('https://api.dictionaryapi.dev/api/v2/entries/en/medium', expect.anything());
    expect(invoke).not.toHaveBeenCalled();
  });
  it('keeps the editorial Vietnamese meaning separate from unrelated meanings of light', async () => {
    const catalog = query([{ id: 'adjective', term: 'light', part_of_speech: 'adjective', definition: 'Not heavy.', translation: 'nhẹ' }]);
    state.client = { from: vi.fn().mockReturnValue(catalog) };
    const words = await searchDictionary('light', false);
    expect(words).toEqual([
      expect.objectContaining({ part_of_speech: 'noun', translation: 'ánh sáng' }),
      expect.objectContaining({ part_of_speech: 'adjective', translation: 'nhẹ' }),
    ]);
  });
  it('shows both editorial senses of duck without treating the verb definition as a noun', async () => {
    state.client = { from: vi.fn().mockReturnValue(query([])) };
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(null, { status: 404 })));
    await expect(searchDictionary('duck', false)).resolves.toEqual([
      expect.objectContaining({ part_of_speech: 'noun', translation: 'con vịt' }),
      expect.objectContaining({ part_of_speech: 'verb', translation: 'cúi xuống, né' }),
    ]);
  });
  it('adds a suggested word translation without changing the definition translation', async () => {
    state.client = { from: vi.fn().mockReturnValue(query([])) };
    vi.stubEnv('EXPO_PUBLIC_SUPABASE_URL', 'https://example.supabase.co');
    vi.stubEnv('EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY', 'test-public-key');
    const fetcher = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify([{
        word: 'harbor', meanings: [{ partOfSpeech: 'noun', definitions: [{ definition: 'A sheltered place for boats.' }] }],
      }])))
      .mockResolvedValueOnce(new Response(JSON.stringify({
        provider: 'mymemory', sourceLanguage: 'en', targetLanguage: 'vi', translatedText: 'bến cảng',
      })));
    vi.stubGlobal('fetch', fetcher);
    await expect(searchDictionary('harbor', false)).resolves.toEqual([
      expect.objectContaining({ term: 'harbor', translation: null, suggested_translation: 'bến cảng' }),
    ]);
  });
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

  it('imports only a missing exact English word and returns its persistent UUID', async () => {
    const words = query([]);
    const imported = {
      id: '11111111-1111-4111-8111-111111111111', term: 'license', definition: 'An official permit.',
      translation: 'giấy phép', ipa: null, part_of_speech: 'noun', example: null, audio_url: null,
      source_name: 'Free Dictionary API', license_id: 'CC BY-SA 3.0',
    };
    const invoke = vi.fn().mockResolvedValue({ data: { word: imported }, error: null });
    state.client = {
      auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) },
      from: vi.fn().mockReturnValue(words), functions: { invoke },
    };
    await expect(searchDictionary('license')).resolves.toEqual([imported]);
    expect(invoke).toHaveBeenCalledWith('dictionary-import', { body: { word: 'license' } });
  });

  it('does not call the provider when Supabase already has the exact word', async () => {
    const existing = { id: 'word-1', term: 'license', definition: 'curated' };
    const words = query([existing]);
    const invoke = vi.fn();
    state.client = {
      auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) },
      from: vi.fn().mockReturnValue(words), functions: { invoke },
    };
    await expect(searchDictionary('license')).resolves.toEqual([existing]);
    expect(invoke).not.toHaveBeenCalled();
  });
});
