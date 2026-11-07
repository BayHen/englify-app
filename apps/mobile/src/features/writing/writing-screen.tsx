import { useCallback, useRef, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import { randomUUID } from 'expo-crypto';
import { View } from 'react-native';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppInput, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { getExercises, getWritingHistory, submitWriting, type Exercise, type Submission } from './api';

export function WritingScreen() {
  const [exercises, setExercises] = useState<Exercise[]>([]);
  const [history, setHistory] = useState<Submission[]>([]);
  const [selected, setSelected] = useState<Exercise | null>(null);
  const [body, setBody] = useState('');
  const [chosen, setChosen] = useState<number[]>([]);
  const [useGrammar, setUseGrammar] = useState(false);
  const [result, setResult] = useState<Submission | null>(null);
  const [reviewing, setReviewing] = useState<Submission | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const requestId = useRef<string | null>(null);
  const inFlight = useRef(false);
  const load = useCallback(async () => {
    setLoading(true);
    try { const [available, previous] = await Promise.all([getExercises(), getWritingHistory()]); setExercises(available); setHistory(previous); setError(''); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load writing practice.'); }
    finally { setLoading(false); }
  }, []);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  function select(exercise: Exercise) { setSelected(exercise); setBody(''); setChosen([]); setResult(null); setReviewing(null); setError(''); requestId.current = null; }
  function chooseToken(index: number) {
    if (!selected || chosen.includes(index)) return;
    const next = [...chosen, index];
    setChosen(next); setBody(next.map((item) => selected.tokens[item]).join(' '));
    requestId.current = null;
  }
  async function submit() {
    if (!selected || !body.trim() || inFlight.current) return;
    inFlight.current = true; setBusy(true); setError('');
    try {
      requestId.current ??= randomUUID();
      const saved = await submitWriting(requestId.current, selected.id, body.trim(), useGrammar);
      setResult(saved); setHistory((old) => [saved, ...old.filter((item) => item.id !== saved.id)]);
      requestId.current = null;
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not submit writing. Try again.'); }
    finally { inFlight.current = false; setBusy(false); }
  }
  const displayed = reviewing ?? result;
  return <Page eyebrow="WRITING PRACTICE" title="Write and review" description="Structured exercises use clear answer rules. Paragraph feedback is guidance, not an essay score.">
    {loading ? <LoadingSkeleton lines={4} /> : error && !exercises.length ? <ErrorState message={error} retry={() => { void load(); }} /> : exercises.length ? <>
      <View style={{ gap: 8 }}><AppText variant="heading">Choose an exercise</AppText>{exercises.map((item) => <AppButton key={item.id} label={`${item.kind.replaceAll('_', ' ')} · ${item.prompt}`} variant={selected?.id === item.id ? 'primary' : 'secondary'} onPress={() => select(item)} />)}</View>
      {selected && <AppCard tone="primary" style={{ gap: 12 }}><AppText variant="caption" tone="primary">{selected.kind.replaceAll('_', ' ').toUpperCase()}</AppText><AppText variant="heading">{selected.prompt}</AppText><AppText tone="muted">{selected.hint}</AppText>
        {selected.kind === 'sentence_order' ? <><AppText variant="label">Tap the words in order</AppText><View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{selected.tokens.map((word, index) => <AppButton key={`${word}-${index}`} label={word} size="medium" variant={chosen.includes(index) ? 'primary' : 'secondary'} disabled={chosen.includes(index)} onPress={() => chooseToken(index)} />)}</View><AppButton label="Clear order" variant="secondary" onPress={() => { setChosen([]); setBody(''); requestId.current = null; }} /><AppText>Your sentence: {body || '—'}</AppText></> : <AppInput label={selected.kind === 'paragraph' ? 'Your paragraph' : selected.kind === 'fill_blank' ? 'Missing word' : 'Your sentence'} value={body} onChangeText={(value) => { setBody(value); requestId.current = null; setResult(null); }} multiline={selected.kind === 'paragraph'} style={selected.kind === 'paragraph' ? { minHeight: 140, textAlignVertical: 'top' } : undefined} />}
        <AppText tone="muted">Optional grammar check sends this text to your configured self-hosted LanguageTool server. Without it, rule feedback still works.</AppText><AppButton label={useGrammar ? 'Grammar check: on' : 'Grammar check: off'} variant="secondary" onPress={() => setUseGrammar(!useGrammar)} /><AppButton label="Submit writing" disabled={busy || !body.trim()} onPress={() => { void submit(); }} />
      </AppCard>}
      {!!error && <ErrorState message={error} retry={() => { void submit(); }} />}
      {displayed && <AppCard style={{ gap: 8 }}><AppText variant="heading">{reviewing ? 'Previous submission' : 'Feedback'}</AppText><AppText variant="label">Original: {displayed.body}</AppText><AppText tone="primary">Rule check: {displayed.feedback?.rule_result?.replaceAll('_', ' ') ?? 'No feedback'}</AppText>{displayed.feedback?.suggestions.map((item, index) => <AppText key={index}>{item}</AppText>)}<AppText tone="muted">Grammar: {displayed.feedback?.grammar_status ?? 'not requested'}</AppText>{displayed.feedback?.grammar_matches.map((item, index) => <AppText key={index}>{item.message}{item.replacements.length ? ` Try: ${item.replacements.join(', ')}` : ''}</AppText>)}</AppCard>}
      <View style={{ gap: 8 }}><AppText variant="heading">Writing history</AppText>{history.length ? history.map((item) => <AppCard key={item.id} onPress={() => { setReviewing(item); setResult(null); }} accessibilityLabel={`Review writing from ${item.created_at}`} style={{ gap: 4 }}><AppText variant="label">{item.prompt}</AppText><AppText variant="caption" tone="muted">{new Date(item.created_at).toLocaleString()} · {item.body.slice(0, 90)}</AppText></AppCard>) : <EmptyState title="No writing saved yet" message="Submit an exercise to keep its original text and feedback in your history." />}</View>
    </> : <EmptyState title="No writing exercises" message="Apply the writing migration and development seed, then refresh." />}
    <NavLink href="/home" label="Back to dashboard" />
  </Page>;
}
