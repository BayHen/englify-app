import { useEffect, useRef, useState } from 'react';
import * as Speech from 'expo-speech';
import { randomUUID } from 'expo-crypto';
import { View } from 'react-native';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppInput, AppModal, AppText, ErrorState, LoadingSkeleton } from '@/ui';
import { getContextQuiz, getExpression, listRealEnglishTopics, saveExpression, submitContextQuiz, unsaveExpression,
  type CefrLevel, type ContextQuiz, type Expression, type LibraryCategory, type QuizResult, type TopicOption } from './api';
import { RealEnglishLibraryV2 } from './real-english-library-v2';
import { compactTopics } from './library-utils';

const kinds: { value: LibraryCategory | 'all'; label: string }[] = [
  { value: 'all', label: 'All content' },
  { value: 'expression', label: 'Expressions' },
  { value: 'dialogue', label: 'Dialogues' },
  { value: 'scenario', label: 'Scenarios' },
];

export function RealEnglishScreen() {
  const [query, setQuery] = useState('');
  const [submitted, setSubmitted] = useState('');
  const [kind, setKind] = useState<LibraryCategory | 'all'>('all');
  const [cefr, setCefr] = useState<CefrLevel | 'all'>('all');
  const [topic, setTopic] = useState('');
  const [topics, setTopics] = useState<TopicOption[]>([]);
  const [savedOnly, setSavedOnly] = useState(false);
  const [selected, setSelected] = useState<Expression | null>(null);
  const [quiz, setQuiz] = useState<ContextQuiz | null>(null);
  const [result, setResult] = useState<QuizResult | null>(null);
  const [busy, setBusy] = useState(false);
  const [detailError, setDetailError] = useState('');
  const pendingRequestId = useRef<string | null>(null);
  useEffect(() => { void listRealEnglishTopics().then(setTopics).catch(() => setTopics([])); }, []);
  async function open(id: string) {
    setQuiz(null); setResult(null); setDetailError('');
    pendingRequestId.current = null;
    try { const item = await getExpression(id); setSelected(item); setQuiz(await getContextQuiz(item.id)); }
    catch (cause) { setDetailError(cause instanceof Error ? cause.message : 'Could not load the context quiz.'); }
  }
  async function toggleSave() {
    if (!selected || busy) return;
    setBusy(true);
    try {
      const updated = selected.saved ? await unsaveExpression(selected.id) : await saveExpression(selected.id);
      setSelected(updated);
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
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{(['all', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'] as const).map((level) =>
      <AppButton key={level} label={level === 'all' ? 'All levels' : level} size="medium" variant={cefr === level ? 'primary' : 'secondary'} onPress={() => setCefr(level)} />)}</View>
    <AppText variant="label">Topics</AppText>
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}><AppButton label="All topics" size="medium" variant={!topic ? 'primary' : 'secondary'} onPress={() => setTopic('')} />
      {compactTopics(topics).map((entry) => <AppButton key={entry.slug} label={entry.title} size="medium" variant={topic === entry.slug ? 'primary' : 'secondary'} onPress={() => setTopic(entry.slug)} />)}</View>
    <AppText variant="label">Content type</AppText>
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{kinds.map((entry) => <AppButton key={entry.value} label={entry.label} size="medium" variant={kind === entry.value ? 'primary' : 'secondary'} onPress={() => setKind(entry.value)} />)}</View>
    <AppButton label={savedOnly ? 'Show all readings' : 'Show saved readings'} variant="secondary" onPress={() => setSavedOnly(!savedOnly)} />
    <RealEnglishLibraryV2 key={`${submitted}|${cefr}|${topic}|${kind}|${savedOnly}`} query={submitted} cefr={cefr} topic={topic} category={kind} savedOnly={savedOnly}
      onOpenExpression={(id) => { void open(id); }} />
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
      {Boolean(detailError) ? <ErrorState message={detailError} retry={() => { if (quiz) setDetailError(''); else void open(selected.id); }} /> : null}
      {quiz ? <View style={{ gap: 8 }}><AppText variant="heading">Context quiz</AppText><AppText>{quiz.prompt}</AppText>{quiz.options.map((option) => <AppButton key={option.id} label={option.text} variant={result?.correct_option === option.id ? 'primary' : 'secondary'} disabled={busy || Boolean(result)} onPress={() => { void answer(option.id); }} />)}{result ? <AppCard tone={result.is_correct ? 'reward' : 'surface'} style={{ gap: 6 }}><AppText variant="heading">{result.is_correct ? 'Correct!' : 'Good try'}</AppText><AppText>{result.explanation}</AppText><AppButton label="Try again" variant="secondary" onPress={() => setResult(null)} /></AppCard> : null}</View> : !detailError ? <LoadingSkeleton lines={2} /> : null}
    </View> : null}
    </AppModal>
    <NavLink href="/home" label="Back to dashboard" />
  </Page>;
}
