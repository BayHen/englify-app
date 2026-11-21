import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { useGuestRecent } from './guest-recent';

const storage = vi.hoisted(() => new Map<string, string>());
vi.mock('./cache-storage', () => ({
  readStorage: async (key: string) => storage.get(key) ?? null,
  writeStorage: async (key: string, value: string) => { storage.set(key, value); },
}));
beforeEach(() => vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('Offline'))));
afterEach(() => vi.unstubAllGlobals());

describe('daily vocabulary and guest history', () => {
  it('persists verified API suggestions along with local words', async () => {
    const fetcher = vi.fn().mockResolvedValue(new Response(JSON.stringify([
      { word: 'bread', defs: ['n\tFood made from flour.'] },
      { word: 'rainbow', defs: ['n\tAn arc of colors in the sky.'] },
      { word: 'bad phrase', defs: ['n\tNot a single word.'] },
    ])));
    vi.stubGlobal('fetch', fetcher);
    const { loadDailyVocabulary } = await import('./daily');
    const date = new Date(2026, 10, 24);
    const first = await loadDailyVocabulary(date);
    expect(first).toHaveLength(5);
    expect(first.map((word) => word.term)).toEqual(expect.arrayContaining(['bread', 'rainbow']));
    vi.resetModules();
    const restarted = await import('./daily');
    expect(await restarted.loadDailyVocabulary(date)).toEqual(first);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });
  it('persists five valid words by local date, including across module restart', async () => {
    const { loadDailyVocabulary } = await import('./daily');
    const first = await loadDailyVocabulary(new Date(2026, 10, 21, 23, 59));
    expect(new Set(first.map((word) => word.term)).size).toBe(5);
    expect(first.every((word) => word.translation && word.definition)).toBe(true);
    expect(storage.has('daily-vocabulary:2026-11-21')).toBe(true);
    vi.resetModules();
    const restarted = await import('./daily');
    expect(await restarted.loadDailyVocabulary(new Date(2026, 10, 21, 23, 59))).toEqual(first);
    const tomorrow = await restarted.loadDailyVocabulary(new Date(2026, 10, 22, 0, 1));
    expect(tomorrow).toHaveLength(5);
    expect(tomorrow.some((word) => first.some((previous) => previous.term === word.term))).toBe(false);
    expect(useGuestRecent.getState().words).toEqual([]);
  });

  it('deduplicates and caps session history, supports removal and never writes to storage', () => {
    const before = [...storage.entries()];
    const { add, remove, clear } = useGuestRecent.getState();
    for (let index = 0; index < 22; index++) add(`word-${index}`);
    add(' DARK '); add('word-21'); add('dark'); add(' ');
    expect(useGuestRecent.getState().words).toHaveLength(20);
    expect(useGuestRecent.getState().words.slice(0, 2)).toEqual(['dark', 'word-21']);
    remove('dark');
    expect(useGuestRecent.getState().words).not.toContain('dark');
    clear();
    expect(useGuestRecent.getState().words).toEqual([]);
    expect([...storage.entries()]).toEqual(before);
  });
});
