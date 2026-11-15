import { useCallback, useRef, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import * as Speech from 'expo-speech';
import { randomUUID } from 'expo-crypto';
import { View } from 'react-native';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppInput, AppModal, AppText, ErrorState, LoadingSkeleton } from '@/ui';
import { getContextQuiz, saveExpression, searchExpressions, submitContextQuiz, unsaveExpression, type ContextQuiz, type Expression, type ExpressionKind, type QuizResult } from './api';
import { RealEnglishLibrary } from './real-english-library';

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
  const [listError, setListError] = useState('');
  const [detailError, setDetailError] = useState('');
  const pendingRequestId = useRef<string | null>(null);
  const load = useCallback(async () => {
    setLoading(true);
    try { setItems(await searchExpressions(submitted, kind === 'all' ? undefined : kind, savedOnly)); setListError(''); }
    catch (cause) { setListError(cause instanceof Error ? cause.message : 'Could not load expressions.'); }
    finally { setLoading(false); }
  }, [submitted, kind, savedOnly]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  async function open(item: Expression) {
    setSelected(item); setQuiz(null); setResult(null); setDetailError('');
    pendingRequestId.current = null;
    try { setQuiz(await getContextQuiz(item.id)); }
    catch (cause) { setDetailError(cause instanceof Error ? cause.message : 'Could not load the context quiz.'); }
  }
  async function toggleSave() {
    if (!selected || busy) return;
    setBusy(true);
    try {
      const updated = selected.saved ? await unsaveExpression(selected.id) : await saveExpression(selected.id);
      setSelected(updated); setItems((old) => old.map((item) => item.id === updated.id ? updated : item).filter((item) => !savedOnly || item.saved));
      setDetailError('');
    } catch (cause) { setDetailError(cause instanceof Error ? cause.message : 'Could not save this expression.'); }
    finally { setBusy(false); }
  }
  async function answer(option: string) {
    if (!selected || !quiz || busy || result) return;
    setBusy(true);
    try {
      pendingRequestId.current ??= randomUUID();
      setResult(await submitContextQuiz(selected.id, pendingRequestId.current, option));
      pendingRequestId.current = null; setDetailError('');
    }
    catch (cause) { setDetailError(cause instanceof Error ? cause.message : 'Could not submit your answer.'); }
    finally { setBusy(false); }
  }
  function speak(text: string) {
    Speech.stop();
    Speech.speak(text, { language: 'en-US', rate: 0.85 });
  }
  function closeDetails() {
    Speech.stop();
    setSelected(null);
    setDetailError('');
  }
  return <Page eyebrow="REAL ENGLISH" title="English in context" description="Explore original examples and dialogues. Save expressions and practice a context question.">
    <AppInput label="Search lessons, expressions or Vietnamese" value={query} onChangeText={setQuery} placeholder="Try baking, bột mì, or no biggie" onSubmitEditing={() => setSubmitted(query.trim())} />
    <AppButton label="Search" onPress={() => setSubmitted(query.trim())} />
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{kinds.map((entry) => <AppButton key={entry.value} label={entry.label} size="medium" variant={kind === entry.value ? 'primary' : 'secondary'} onPress={() => setKind(entry.value)} />)}</View>
    <AppButton label={savedOnly ? 'Show all readings' : 'Show saved readings'} variant="secondary" onPress={() => setSavedOnly(!savedOnly)} />
    <RealEnglishLibrary expressions={items} expressionsLoading={loading} expressionError={listError}
      query={submitted} kind={kind} savedOnly={savedOnly} onOpenExpression={(item) => { void open(item); }}
      retryExpressions={() => { void load(); }} />
    <AppModal visible={Boolean(selected)} title={selected?.expression ?? 'Expression'} onClose={closeDetails}>
    {selected ? <View style={{ gap: 12 }}>
      <AppText variant="caption" tone="primary">{selected.kind.replaceAll('_', ' ').toUpperCase()} · {selected.formality}</AppText>
      <AppText variant="title">{selected.expression}</AppText>
      <AppText variant="heading">{selected.meaning_vi}</AppText>
      <AppText>{selected.context_explanation}</AppText>
      <AppText variant="label">Example</AppText><AppText>{selected.example_en}</AppText><AppText tone="muted">{selected.example_vi}</AppText>
      <AppText variant="label">Region</AppText><AppText tone="muted">{selected.region_note}</AppText>
      {selected.dialogue.length > 0 ? <View style={{ gap: 6 }}><AppText variant="label">Original dialogue</AppText>{selected.dialogue.map((line, index) => <AppText key={`${line.speaker}-${index}`}>{line.speaker}: {line.line}</AppText>)}</View> : null}
      <AppText variant="caption" tone="muted">Source: {selected.source_name} · {selected.license_id}. {selected.provenance_note}</AppText>
      <AppButton label={selected.saved ? 'Remove from saved' : 'Save expression'} variant="secondary" disabled={busy} onPress={() => { void toggleSave(); }} />
      <AppButton label="Listen with device voice" variant="secondary" onPress={() => speak(selected.expression)} />
      <AppText tone="muted">Speaking practice: listen, say the expression aloud, then repeat it in your own sentence. Device speech is a model, not a pronunciation score.</AppText>
      {Boolean(detailError) ? <ErrorState message={detailError} retry={() => { if (quiz) setDetailError(''); else void open(selected); }} /> : null}
      {quiz ? <View style={{ gap: 8 }}><AppText variant="heading">Context quiz</AppText><AppText>{quiz.prompt}</AppText>{quiz.options.map((option) => <AppButton key={option.id} label={option.text} variant={result?.correct_option === option.id ? 'primary' : 'secondary'} disabled={busy || Boolean(result)} onPress={() => { void answer(option.id); }} />)}{result ? <AppCard tone={result.is_correct ? 'reward' : 'surface'} style={{ gap: 6 }}><AppText variant="heading">{result.is_correct ? 'Correct!' : 'Good try'}</AppText><AppText>{result.explanation}</AppText><AppButton label="Try again" variant="secondary" onPress={() => setResult(null)} /></AppCard> : null}</View> : !detailError ? <LoadingSkeleton lines={2} /> : null}
    </View> : null}
    </AppModal>
    <NavLink href="/home" label="Back to dashboard" />
  </Page>;
}
