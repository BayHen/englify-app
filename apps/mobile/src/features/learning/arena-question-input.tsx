import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { AppButton, AppInput, AppText } from '@/ui';
import type { ArenaAnswer, ArenaQuestion } from './arena-api';

type Props = { question: ArenaQuestion; answer: ArenaAnswer | undefined; disabled: boolean; onChange: (answer: ArenaAnswer) => void };
export function ArenaQuestionInput({ question, answer, disabled, onChange }: Props) {
  const gap = designTokens.spacing.sm;
  if (question.kind === 'matching') {
    const pairs = answer && typeof answer === 'object' && !Array.isArray(answer) ? answer : {};
    return <View style={{ gap: designTokens.spacing.lg }}>{question.left_items.map(left => <View key={left.id} style={{ gap }}>
      <AppText variant="label">{left.text}</AppText>{question.right_items.map(right => <AppButton key={right.id}
        label={`${pairs[left.id] === right.id ? 'Selected: ' : ''}${right.text}`} disabled={disabled}
        variant={pairs[left.id] === right.id ? 'primary' : 'secondary'}
        onPress={() => { const next = { ...pairs }; for (const id of Object.keys(next)) if (next[id] === right.id) delete next[id]; next[left.id] = right.id; onChange(next); }} />)}
    </View>)}</View>;
  }
  if (question.kind === 'sentence_order') {
    const ordered = Array.isArray(answer) ? answer : [];
    return <View style={{ gap }}>
      <AppText accessibilityLiveRegion="polite">{ordered.map(id => question.options.find(item => item.id === id)?.text).join(' ') || 'Tap the tokens in order.'}</AppText>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap }}>{question.options.map(item => <AppButton key={item.id}
        label={item.text} size="medium" disabled={disabled || ordered.includes(item.id)} variant="secondary" onPress={() => onChange([...ordered, item.id])} />)}</View>
      <AppButton label="Undo last token" variant="secondary" disabled={disabled || ordered.length === 0} onPress={() => onChange(ordered.slice(0, -1))} />
      <AppButton label="Clear order" variant="ghost" disabled={disabled || ordered.length === 0} onPress={() => onChange([])} />
    </View>;
  }
  if (question.kind === 'multiple_choice' || question.kind === 'reading') return <View style={{ gap }}>{question.options.map(item => <AppButton key={item.id}
    label={`${answer === item.id ? 'Selected: ' : ''}${item.text}`} disabled={disabled}
    variant={answer === item.id ? 'primary' : 'secondary'} onPress={() => onChange(item.id)} />)}</View>;
  return <AppInput label={question.kind === 'grammar_correction' ? 'Write the corrected sentence' : 'Your answer'} value={typeof answer === 'string' ? answer : ''}
    editable={!disabled} onChangeText={onChange} autoCapitalize="none" maxLength={2000} multiline={question.kind === 'grammar_correction'} />;
}
