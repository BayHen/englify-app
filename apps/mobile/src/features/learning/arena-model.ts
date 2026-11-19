import type { ArenaAnswer, ArenaConfig, ArenaGroup, ArenaQuestion } from './arena-api';

export const arenaTopics = { grammar: 'Grammar', vocabulary: 'Vocabulary', reading: 'Reading Comprehension', everyday: 'Everyday English',
  business: 'Business English', travel: 'Travel English', sentence_structure: 'Sentence Structure', phrasal_verbs: 'Phrasal Verbs', idioms: 'Idioms' } as const;
export const arenaKinds = { multiple_choice: 'Multiple Choice', fill_blank: 'Fill in the Blank', matching: 'Matching',
  grammar_correction: 'Grammar Correction', sentence_order: 'Sentence Ordering', reading: 'Reading Comprehension' } as const;
export function availableArenaQuestions(groups: ArenaGroup[], config: ArenaConfig): number {
  return groups.filter(g => g.cefr_level === config.level && (config.topic === null || g.topic === config.topic)
    && (config.kind === null || g.kind === config.kind) && (config.difficulty === null || g.difficulty === config.difficulty))
    .reduce((total, g) => total + g.available, 0);
}
// Completeness only. Correctness and XP are never calculated on the client.
export function isArenaAnswerComplete(question: ArenaQuestion, answer: ArenaAnswer | undefined): boolean {
  if (question.kind === 'matching') {
    if (!answer || typeof answer !== 'object' || Array.isArray(answer)) return false;
    const selected = question.left_items.map(item => answer[item.id]);
    return Object.keys(answer).length === question.left_items.length && new Set(selected).size === selected.length
      && selected.every(id => question.right_items.some(item => item.id === id));
  }
  if (question.kind === 'sentence_order') return Array.isArray(answer) && answer.length === question.options.length
    && new Set(answer).size === answer.length && answer.every(id => question.options.some(item => item.id === id));
  if (question.kind === 'multiple_choice' || question.kind === 'reading') return typeof answer === 'string'
    && question.options.some(item => item.id === answer);
  return typeof answer === 'string' && answer.trim().length > 0;
}
export function formatArenaAnswer(question: ArenaQuestion, answer: ArenaAnswer): string {
  if (Array.isArray(answer)) return answer.map(id => question.options.find(item => item.id === id)?.text ?? id).join(' ');
  if (typeof answer === 'object') return question.left_items.map(left => `${left.text} → ${question.right_items.find(right => right.id === answer[left.id])?.text ?? '—'}`).join('\n');
  return question.options.find(item => item.id === answer)?.text ?? answer;
}
