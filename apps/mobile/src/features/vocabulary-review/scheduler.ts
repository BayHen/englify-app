import type { RecallRating } from './api';

export const ratings: { value: RecallRating; label: string; hint: string }[] = [
  { value: 1, label: 'Again', hint: 'Review again soon' },
  { value: 2, label: 'Hard', hint: 'Short interval' },
  { value: 3, label: 'Good', hint: 'Normal interval' },
  { value: 4, label: 'Easy', hint: 'Longer interval' },
];

export function cardDirection(index: number): 'en-vi' | 'vi-en' { return index % 2 === 0 ? 'en-vi' : 'vi-en'; }
