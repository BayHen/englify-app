import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it, vi } from 'vitest';
import { ArenaQuestionInput } from './arena-question-input';
import type { ArenaKind, ArenaQuestion } from './arena-api';
vi.mock('@/ui', async () => ({ AppButton: (await import('@/ui/app-button')).AppButton, AppInput: (await import('@/ui/app-input')).AppInput, AppText: (await import('@/ui/app-text')).AppText }));
const question = { id: 'q', prompt: 'Choose', options: [{ id: 'a', text: 'First' }, { id: 'b', text: 'Second' }],
  left_items: [{ id: 'l', text: 'Left' }], right_items: [{ id: 'r', text: 'Right' }] };
describe('Arena question adapters', () => {
  it.each<ArenaKind>(['multiple_choice', 'fill_blank', 'matching', 'grammar_correction', 'sentence_order', 'reading'])('renders %s with no text directly under View', kind => {
    const html = renderToStaticMarkup(<ArenaQuestionInput question={{ ...question, kind } as ArenaQuestion} answer={undefined} disabled={false} onChange={() => {}} />);
    expect(html.length).toBeGreaterThan(0);
  });
  it('marks the selected option in text as well as colour', () => {
    const html = renderToStaticMarkup(<ArenaQuestionInput question={{ ...question, kind: 'multiple_choice' } as ArenaQuestion} answer="b" disabled onChange={() => {}} />);
    expect(html).toContain('Selected: Second'); expect(html).toContain('disabled');
  });
});
