import { describe, expect, it } from 'vitest';
import { cardDirection, ratings } from './scheduler';

describe('vocabulary review presentation', () => {
  it('alternates both recall directions deterministically', () => {
    expect([0, 1, 2, 3].map(cardDirection)).toEqual(['en-vi', 'vi-en', 'en-vi', 'vi-en']);
  });
  it('keeps the four ordered recall ratings', () => {
    expect(ratings.map((rating) => rating.value)).toEqual([1, 2, 3, 4]);
  });
});
