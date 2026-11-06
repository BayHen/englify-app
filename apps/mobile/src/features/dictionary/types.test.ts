import { describe, expect, it } from 'vitest';
import { filterCachedWords, type DictionaryWord } from './types';

const words = [
  { id: '1', term: 'curious', translation: 'tò mò' },
  { id: '2', term: 'journey', translation: 'hành trình' },
] as DictionaryWord[];

describe('offline dictionary search', () => {
  it('finds cached English prefixes and Vietnamese meanings', () => {
    expect(filterCachedWords(words, 'CUR').map((word) => word.term)).toEqual(['curious']);
    expect(filterCachedWords(words, 'hành').map((word) => word.term)).toEqual(['journey']);
    expect(filterCachedWords(words, 'missing')).toEqual([]);
  });
});
