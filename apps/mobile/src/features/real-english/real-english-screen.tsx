import { useCallback, useRef, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import * as Speech from 'expo-speech';
import { randomUUID } from 'expo-crypto';
import { View } from 'react-native';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppInput, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { getContextQuiz, saveExpression, searchExpressions, submitContextQuiz, unsaveExpression, type ContextQuiz, type Expression, type ExpressionKind, type QuizResult } from './api';

const kinds: { value: ExpressionKind | 'all'; label: string }[] = [
  { value: 'all', label: 'All' }, { value: 'slang', label: 'Slang' },
  { value: 'idiom', label: 'Idioms' }, { value: 'phrasal_verb', label: 'Phrasal verbs' },
  { value: 'casual_expression', label: 'Casual' },
  { value: 'everyday_conversation', label: 'Everyday' },
  { value: 'movie_style_dialogue', label: 'Original scenes' },
];

export function RealEnglishScreen() {
  const [query, setQuery] = useState('');
  const [submitted, setSubmitted] = useState('');
  const [kind, setKind] = useState<ExpressionKind | 'all'>('all');
  const [savedOnly, setSavedOnly] = useState(false);
  const [items, setItems] = useState<Expression[]>([]);
  const [selected, setSelected] = useState<Expression | null>(null);
  const [quiz, setQuiz] = useState<ContextQuiz | null>(null);
  const [result, setResult] = useState<QuizResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const pendingRequestId = useRef<string | null>(null);
  const load = useCallback(async () => {
    setLoading(true);
    try { setItems(await searchExpressions(submitted, kind === 'all' ? undefined : kind, savedOnly)); setError(''); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load expressions.'); }
    finally { setLoading(false); }
  }, [submitted, kind, savedOnly]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  async function open(item: Expression) {
    setSelected(item); setQuiz(null); setResult(null); setError('');
    pendingRequestId.current = null;
    try { setQuiz(await getContextQuiz(item.id)); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load the context quiz.'); }
  }
  async function toggleSave() {
    if (!selected || busy) return;
    setBusy(true);
    try {
      const updated = selected.saved ? await unsaveExpression(selected.id) : await saveExpression(selected.id);
      setSelected(updated); setItems((old) => old.map((item) => item.id === updated.id ? updated : item).filter((item) => !savedOnly || item.saved));
      setError('');
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save this expression.'); }
    finally { setBusy(false); }
  }
  async function answer(option: string) {
    if (!selected || !quiz || busy || result) return;
    setBusy(true);
    try {
      pendingRequestId.current ??= randomUUID();
      setResult(await submitContextQuiz(selected.id, pendingRequestId.current, option));
      pendingRequestId.current = null; setError('');
    }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not submit your answer.'); }
    finally { setBusy(false); }
  }
  function speak(text: string) {
    Speech.stop();
    Speech.speak(text, { language: 'en-US', rate: 0.85 });
  }
  return <Page eyebrow="REAL ENGLISH" title="English in context" description="Explore original examples and dialogues. Save expressions and practice a context question.">
    <AppInput label="Search expression or Vietnamese meaning" value={query} onChangeText={setQuery} placeholder="Try no biggie" onSubmitEditing={() => setSubmitted(query.trim())} />
    <AppButton label="Search" onPress={() => setSubmitted(query.trim())} />
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{kinds.map((entry) => <AppButton key={entry.value} label={entry.label} size="medium" variant={kind === entry.value ? 'primary' : 'secondary'} onPress={() => setKind(entry.value)} />)}</View>
    <AppButton label={savedOnly ? 'Show all expressions' : 'Show saved expressions'} variant="secondary" onPress={() => setSavedOnly(!savedOnly)} />
    {loading ? <LoadingSkeleton lines={4} /> : error && !selected ? <ErrorState message={error} retry={() => { void load(); }} /> : items.length ? items.map((item) => <AppCard key={item.id} onPress={() => { void open(item); }} accessibilityLabel={`Open ${item.expression}`} style={{ gap: 5 }}><AppText variant="caption" tone="primary">{item.kind.replaceAll('_', ' ').toUpperCase()} · {item.formality}</AppText><AppText variant="heading">{item.expression}{item.saved ? ' ★' : ''}</AppText><AppText tone="muted">{item.meaning_vi}</AppText></AppCard>) : <EmptyState title={savedOnly ? 'No saved expressions' : 'No expressions found'} message={savedOnly ? 'Save an expression from the list to see it here.' : 'Try a different word or category. Development content may need to be seeded.'} />}
    {selected && <AppCard tone="primary" style={{ gap: 12 }}>
      <AppText variant="caption" tone="primary">{selected.kind.replaceAll('_', ' ').toUpperCase()} · {selected.formality}</AppText>
      <AppText variant="title">{selected.expression}</AppText>
      <AppText variant="heading">{selected.meaning_vi}</AppText>
      <AppText>{selected.context_explanation}</AppText>
      <AppText variant="label">Example</AppText><AppText>{selected.example_en}</AppText><AppText tone="muted">{selected.example_vi}</AppText>
      <AppText variant="label">Region</AppText><AppText tone="muted">{selected.region_note}</AppText>
      {selected.dialogue.length > 0 && <View style={{ gap: 6 }}><AppText variant="label">Original dialogue</AppText>{selected.dialogue.map((line, index) => <AppText key={`${line.speaker}-${index}`}>{line.speaker}: {line.line}</AppText>)}</View>}
      <AppText variant="caption" tone="muted">Source: {selected.source_name} · {selected.license_id}. {selected.provenance_note}</AppText>
      <AppButton label={selected.saved ? 'Remove from saved' : 'Save expression'} variant="secondary" disabled={busy} onPress={() => { void toggleSave(); }} />
      <AppButton label="Listen with device voice" variant="secondary" onPress={() => speak(selected.expression)} />
      <AppText tone="muted">Speaking practice: listen, say the expression aloud, then repeat it in your own sentence. Device speech is a model, not a pronunciation score.</AppText>
      {!!error && <ErrorState message={error} retry={() => { if (quiz) setError(''); else void open(selected); }} />}
      {quiz ? <View style={{ gap: 8 }}><AppText variant="heading">Context quiz</AppText><AppText>{quiz.prompt}</AppText>{quiz.options.map((option) => <AppButton key={option.id} label={option.text} variant={result?.correct_option === option.id ? 'primary' : 'secondary'} disabled={busy || Boolean(result)} onPress={() => { void answer(option.id); }} />)}{result && <AppCard tone={result.is_correct ? 'reward' : 'surface'} style={{ gap: 6 }}><AppText variant="heading">{result.is_correct ? 'Correct!' : 'Good try'}</AppText><AppText>{result.explanation}</AppText><AppButton label="Try again" variant="secondary" onPress={() => setResult(null)} /></AppCard>}</View> : !error && <LoadingSkeleton lines={2} />}
      <AppButton label="Close details" variant="secondary" onPress={() => { Speech.stop(); setSelected(null); setError(''); }} />
    </AppCard>}
    <NavLink href="/home" label="Back to dashboard" />
  </Page>;
}
