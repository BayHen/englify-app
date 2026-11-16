import { describe, expect, it } from 'vitest';
import { paginateDictionary } from './pagination';

describe('dictionary pagination', () => {
  const words = Array.from({ length: 12 }, (_, index) => `word-${index + 1}`);

  it('shows at most five words and keeps stable page boundaries', () => {
    expect(paginateDictionary(words, 1)).toMatchObject({ items: words.slice(0, 5), page: 1, totalPages: 3 });
    expect(paginateDictionary(words, 2)).toMatchObject({ items: words.slice(5, 10), page: 2, totalPages: 3 });
    expect(paginateDictionary(words, 3)).toMatchObject({ items: words.slice(10), page: 3, totalPages: 3 });
  });

  it('clamps stale pages after the list becomes shorter', () => {
    expect(paginateDictionary(words.slice(0, 3), 8)).toMatchObject({ items: words.slice(0, 3), page: 1, totalPages: 1 });
    expect(paginateDictionary([], 0)).toMatchObject({ items: [], page: 1, totalPages: 1, totalItems: 0 });
  });
});
