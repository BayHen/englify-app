import { useState } from 'react';
import { Pressable, View } from 'react-native';
import { router } from 'expo-router';
import { Page } from '@/components/page';
import { useAppPalette } from '@/constants/app-theme';
import { AppButton, AppCard, AppText, ErrorState, LoadingSkeleton } from '@/ui';
import { finalizePlacementTest, startPlacementTest, submitPlacementAnswer, type PlacementResult, type PlacementSession } from './api';

export function PlacementScreen() {
  const palette = useAppPalette();
  const [session, setSession] = useState<PlacementSession | null>(null);
  const [index, setIndex] = useState(0);
  const [selected, setSelected] = useState<number | null>(null);
  const [result, setResult] = useState<PlacementResult | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const question = session?.questions[index];
  async function begin() { setBusy(true); setError(''); try { setSession(await startPlacementTest()); setIndex(0); } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not start placement test.'); } finally { setBusy(false); } }
  async function next() {
    if (!session || !question || selected === null || busy) return;
    setBusy(true); setError('');
    try {
      await submitPlacementAnswer(session.session_id, question.id, selected);
      if (index + 1 === session.questions.length) setResult(await finalizePlacementTest(session.session_id));
      else { setIndex((value) => value + 1); setSelected(null); }
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save the answer.'); }
    finally { setBusy(false); }
  }
  return <Page eyebrow="CEFR PLACEMENT" title="Find a useful starting point" description="Optional assessment of grammar, vocabulary and reading. This is not an official CEFR certificate." compact>
    {busy && !session ? <LoadingSkeleton lines={4} /> : null}
    {error ? <ErrorState message={error} retry={() => { if (!session) void begin(); else setError(''); }} /> : null}
    {result ? <AppCard tone="primary" style={{ gap: 10 }}><AppText variant="caption">SUGGESTED STARTING LEVEL</AppText><AppText variant="title">{result.recommended_cefr}</AppText><AppText>Confidence: {result.confidence}</AppText><AppText tone="muted">Your grammar, vocabulary and reading evidence suggests this may be a useful starting point.</AppText><AppText variant="caption" tone="muted">{result.disclaimer}</AppText><AppButton label="Choose learning level" onPress={() => router.push('/learning-preferences')} /><AppButton label="Back to Journey" variant="secondary" onPress={() => router.replace('/journey')} /></AppCard>
      : question ? <View style={{ gap: 14 }}><AppText variant="caption" tone="primary">QUESTION {index + 1} OF {session!.questions.length} · {question.skill.toUpperCase()} · {question.cefr_level}</AppText><AppText variant="heading">{question.prompt}</AppText>{question.options.map((option, optionIndex) => <Pressable key={`${question.id}-${optionIndex}`} accessibilityRole="radio" accessibilityState={{ checked: selected === optionIndex }} onPress={() => setSelected(optionIndex)} style={({ pressed }) => ({ padding: 15, borderRadius: 18, borderWidth: 1, borderColor: selected === optionIndex ? palette.primary : palette.border, backgroundColor: selected === optionIndex ? palette.primarySoft : palette.surface, opacity: pressed ? .75 : 1 })}><AppText>{option}</AppText></Pressable>)}<AppButton label={index + 1 === session!.questions.length ? 'Finish assessment' : 'Save and continue'} disabled={selected === null} loading={busy} onPress={() => { void next(); }} /></View>
      : !busy ? <AppCard style={{ gap: 10 }}><AppText variant="heading">What this assessment covers</AppText><AppText tone="muted">15 validated multiple-choice questions across five difficulty bands. Answers are graded by the server and cannot be changed after submission.</AppText><AppButton label="Start placement test" onPress={() => { void begin(); }} /></AppCard> : null}
  </Page>;
}
