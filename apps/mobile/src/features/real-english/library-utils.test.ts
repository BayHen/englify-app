import { describe, expect, it } from 'vitest';
import { lessonMatchesQuery, paginate, type SearchableLesson } from './library-utils';

const lesson: SearchableLesson = {
  title: 'Buying Baking Supplies',
  description: 'Learn useful shopping English.',
  content_type: 'dialogue',
  real_english_phrases: [{ english_text: 'I am buying flour.', vietnamese_translation: 'Tôi đang mua bột mì.', usage_context: 'At a grocery store' }],
  real_english_dialogues: [{ title: 'At the checkout', real_english_dialogue_lines: [{
    speaker: 'Cashier', english_text: 'Did you find everything?', vietnamese_translation: 'Bạn đã tìm thấy mọi thứ chưa?',
  }] }],
};

describe('Real English unified library', () => {
  it('searches lesson titles, phrases, Vietnamese and dialogue text', () => {
    expect(lessonMatchesQuery(lesson, 'baking')).toBe(true);
    expect(lessonMatchesQuery(lesson, 'bột mì')).toBe(true);
    expect(lessonMatchesQuery(lesson, 'ban da tim')).toBe(true);
    expect(lessonMatchesQuery(lesson, 'airport')).toBe(false);
  });

  it('shows no more than five items and clamps invalid pages', () => {
    const values = Array.from({ length: 12 }, (_, index) => index + 1);
    expect(paginate(values, 1).items).toEqual([1, 2, 3, 4, 5]);
    expect(paginate(values, 3)).toEqual({ page: 3, pageCount: 3, items: [11, 12] });
    expect(paginate(values, 99).page).toBe(3);
  });
});
