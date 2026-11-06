import { describe, expect, it } from 'vitest';
import { checkDraft, featureLinks, quizQuestions, searchWords, translateSample } from './data';

describe('offline learning demos', () => {
  it('keeps each learning destination reachable from the dashboard', () => {
    expect(featureLinks.map((item) => item.href)).toEqual(['/journey', '/dictionary', '/translation', '/real-english', '/speaking', '/writing', '/quiz-arena', '/rewards']);
  });
  it('searches English and Vietnamese without network calls', () => {
    expect(searchWords('TÒ MÒ').map((entry) => entry.word)).toEqual(['curious']);
    expect(searchWords('missing')).toEqual([]);
  });
  it('matches curated phrases in either direction only', () => {
    expect(translateSample('How is it going')?.vietnamese).toBe('Dạo này thế nào?');
    expect(translateSample('Dạo này thế nào?')?.english).toBe('How is it going?');
    expect(translateSample('arbitrary text')).toBeUndefined();
  });
  it('checks writing format without claiming to grade language', () => {
    expect(checkDraft('I practice English every day with my friends.')).toHaveLength(3);
    expect(checkDraft('')).toEqual([]);
  });
  it('has valid local quiz answers', () => {
    expect(quizQuestions.every((question) => question.options[question.answer])).toBe(true);
  });
});
