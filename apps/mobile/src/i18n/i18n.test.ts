import { beforeEach, describe, expect, it, vi } from 'vitest';
import { en } from './en';
import { vi as vietnamese } from './vi';
import { translate, translateLiteral } from './translate';

describe('interface translations', () => {
  it('uses English by default and has a Vietnamese value for every key', () => {
    expect(translate('en', 'nav.home')).toBe('Home');
    expect(Object.keys(vietnamese).sort()).toEqual(Object.keys(en).sort());
  });

  it('switches both directions without changing standardized learning values', () => {
    expect(translate('vi', 'preferences.englishLevel')).toBe('Trình độ tiếng Anh hiện tại');
    expect(translate('en', 'preferences.englishLevel')).toBe('Current English level');
    expect(['A1', 'A2', 'B1', 'B2', 'C1', 'C2']).toEqual(['A1', 'A2', 'B1', 'B2', 'C1', 'C2']);
  });

  it('translates registered interface copy without translating learning content', () => {
    expect(translateLiteral('vi', 'Search dictionary')).toBe('Tra từ điển');
    expect(translateLiteral('vi', 'Writing history')).toBe('Lịch sử bài viết');
    expect(translateLiteral('en', 'Search dictionary')).toBe('Search dictionary');
    expect(translateLiteral('vi', 'The traveler ordered coffee.')).toBe('The traveler ordered coffee.');
  });
});

describe('language persistence', () => {
  beforeEach(() => {
    vi.resetModules();
    Object.defineProperty(globalThis, 'localStorage', { configurable: true, value: {
      values: new Map<string, string>(),
      getItem(key: string) { return this.values.get(key) ?? null; },
      setItem(key: string, value: string) { this.values.set(key, value); },
    } });
  });

  it('restores a locally selected language and its pending synchronization state', async () => {
    vi.doMock('react-native', () => ({ Platform: { OS: 'web' } }));
    vi.doMock('expo-secure-store', () => ({ getItemAsync: vi.fn(), setItemAsync: vi.fn() }));
    const storage = await import('./storage');
    await storage.writeStoredLanguage({ language: 'vi', pendingSync: true });
    await expect(storage.readStoredLanguage()).resolves.toEqual({ language: 'vi', pendingSync: true });
  });
});
