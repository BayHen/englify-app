import { describe, expect, it, vi } from 'vitest';
import { buildTatoebaUrl, parseTatoebaPage, searchTatoeba } from '../../../../../supabase/functions/_shared/tatoeba';
import realResponse from '../../../../../supabase/functions/_shared/fixtures/tatoeba-coffee-v1.json';

// Synthetic contract fixture based on Tatoeba's published OpenAPI schema; no IDs are claimed as real data.
const english = { id: 101, text: 'We need coffee.', lang: 'eng', owner: 'author_en',
  license: 'CC BY 2.0 FR', is_unapproved: false };
const vietnamese = { id: 202, text: 'Chúng ta cần cà phê.', lang: 'vie', owner: 'author_vi',
  license: 'CC BY 2.0 FR', is_unapproved: false, is_direct: true };
const page = { data: [{ ...english, translations: [vietnamese] }], paging: { has_next: false, next: null } };

describe('Tatoeba v1 reference adapter', () => {
  it('parses 21 direct pairs from a real public API v1 response', () => {
    const result = parseTatoebaPage(realResponse);
    expect(result.pairs).toHaveLength(21);
    expect(result.pairs.filter((pair) => pair.validationStatus === 'eligible')).toHaveLength(20);
    expect(result.hasNext).toBe(true);
    expect(result.next).toContain('after=');
    expect(result.pairs.every((pair) => pair.sourceUrl.endsWith(String(pair.englishId)))).toBe(true);
  });
  it('builds the official direct English–Vietnamese search query safely', () => {
    const url = new URL(buildTatoebaUrl('coffee & tea', 25));
    expect(url.origin).toBe('https://api.tatoeba.org');
    expect(url.searchParams.get('q')).toBe('coffee & tea');
    expect(url.searchParams.get('trans:lang')).toBe('vie');
    expect(url.searchParams.get('trans:is_direct')).toBe('yes');
    expect(url.searchParams.get('showtrans')).toBe('matching');
    expect(url.searchParams.has('showtrans:lang')).toBe(false);
    expect(url.searchParams.has('showtrans:is_direct')).toBe(false);
    expect(url.searchParams.get('limit')).toBe('25');
  });
  it('keeps both license and contributor identities for a direct pair', () => {
    expect(parseTatoebaPage(page).pairs).toMatchObject([{ englishId: 101, vietnameseId: 202,
      englishLicense: 'CC BY 2.0 FR', vietnameseLicense: 'CC BY 2.0 FR',
      englishContributor: 'author_en', vietnameseContributor: 'author_vi', validationStatus: 'eligible' }]);
  });
  it('blocks unresolved licenses and ignores indirect or malformed translations', () => {
    const unresolved = { ...vietnamese, owner: null, license: null };
    const indirect = { ...vietnamese, id: 203, is_direct: false };
    const parsed = parseTatoebaPage({ data: [{ ...english, translations: [unresolved, indirect, {}] }], paging: { has_next: false } });
    expect(parsed.pairs).toHaveLength(1);
    expect(parsed.pairs[0].validationStatus).toBe('blocked_license');
    expect(() => parseTatoebaPage({ data: [] })).toThrow('API v1');
    expect(() => parseTatoebaPage({ data: [null], paging: { has_next: false } })).toThrow('malformed');
  });
  it('rejects pagination URLs that could reach another host', () => {
    expect(() => parseTatoebaPage({ ...page, paging: { has_next: true, next: 'https://example.com/secret' } }))
      .toThrow('unsafe');
  });
  it('caches repeated searches and reports rate limits without inventing content', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify(page), { status: 200 })) as unknown as typeof fetch;
    expect((await searchTatoeba('coffee', { fetcher })).pairs).toHaveLength(1);
    expect((await searchTatoeba('coffee', { fetcher })).pairs).toHaveLength(1);
    expect(fetcher).toHaveBeenCalledTimes(1);
    const rateLimited = vi.fn(async () => new Response('{}', { status: 429 })) as unknown as typeof fetch;
    await expect(searchTatoeba('travel', { fetcher: rateLimited })).rejects.toMatchObject({ kind: 'rate_limited' });
  });
  it('classifies invalid JSON from the source as an invalid response', async () => {
    const fetcher = vi.fn(async () => new Response('{', { status: 200 })) as unknown as typeof fetch;
    await expect(searchTatoeba('invalid-json-test', { fetcher })).rejects.toMatchObject({ kind: 'invalid_response' });
    expect(fetcher).toHaveBeenCalledTimes(1);
  });
});
