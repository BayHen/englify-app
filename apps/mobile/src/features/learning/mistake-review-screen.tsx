import { useCallback, useRef, useState } from 'react';
import { router, useFocusEffect, type Href } from 'expo-router';
import { randomUUID } from 'expo-crypto';
import { designTokens } from '@englify/shared';
import { Page } from '@/components/page';
import { AppButton, AppCard, AppText, ErrorState, LoadingSkeleton, XPProgressBar } from '@/ui';
import type { ArenaAnswer } from './arena-api';
import { ArenaQuestionInput } from './arena-question-input';
import { formatArenaAnswer, isArenaAnswerComplete } from './arena-model';
import { getMistakeReview, submitMistakeReview, type ReviewSession } from './mistake-review-api';

const gap = designTokens.spacing.md;
export function MistakeReviewScreen({ id }: { id: string }) {
  const [session, setSession] = useState<ReviewSession | null>(null); const [draft, setDraft] = useState<ArenaAnswer | undefined>();
  const [busy, setBusy] = useState(false); const [error, setError] = useState(''); const request = useRef<string | null>(null);
  const load = useCallback(async () => { setError(''); try { setSession(await getMistakeReview(id)); } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not restore review.'); } }, [id]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  const item = session?.current_item;
  async function submit() { if (!item || draft === undefined || busy) return; setBusy(true); setError(''); request.current ??= randomUUID(); try { const next = await submitMistakeReview(id, item.id, request.current, draft); request.current = null; setDraft(undefined); setSession(next); } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not submit answer. Retry is safe.'); } finally { setBusy(false); } }
  return <Page eyebrow="SPACED REPETITION" title="Review mistakes" description="Answers are graded by the server. Correct keys stay hidden until the session ends.">
    {!session && !error ? <LoadingSkeleton lines={5} /> : null}
    {session?.status === 'active' && item ? <><AppCard tone="primary" style={{ gap }}><AppText variant="heading">Question {session.answered_count + 1} of {session.requested_count}</AppText><XPProgressBar value={session.answered_count} max={session.requested_count} label="Review progress" showValue={false} /><AppText variant="caption" tone="muted">{item.cefr_level} · {item.topic} · mastery stage {item.review_stage}/5</AppText></AppCard><AppCard style={{ gap }}><AppText variant="heading">{item.question.prompt}</AppText>{Boolean(item.question.passage) ? <AppText>{item.question.passage}</AppText> : null}<ArenaQuestionInput question={item.question} answer={draft} disabled={busy} onChange={setDraft} /><AppButton label="Check answer" loading={busy} disabled={!isArenaAnswerComplete(item.question, draft)} onPress={() => { void submit(); }} /></AppCard></> : null}
    {session?.status === 'completed' ? <><AppCard tone="reward" style={{ gap }}><AppText variant="title">Review complete</AppText><AppText variant="heading">{session.correct_count}/{session.requested_count} correct</AppText><AppText tone="muted">0 XP · mastery schedule updated in UTC</AppText></AppCard>{(session.review ?? []).map(result => <AppCard key={result.progress_id} style={{ gap }}><AppText variant="label" tone={result.correct ? 'primary' : 'error'}>{result.correct ? 'Correct' : 'Incorrect'} · stage {result.stage_after}/5</AppText><AppText variant="heading">{result.question.prompt}</AppText><AppText>Your answer: {formatArenaAnswer(result.question, result.given_answer)}</AppText><AppText>Correct answer: {formatArenaAnswer(result.question, result.correct_answer)}</AppText><AppText tone="muted">Giải thích: {result.explanation_vi}</AppText><AppText variant="caption" tone="muted">Next review: {new Date(result.next_review_at).toLocaleString()}</AppText></AppCard>)}<AppButton label="Back to Mistake Review" onPress={() => router.replace('/mistakes' as Href)} /></> : null}
    {Boolean(error) ? <ErrorState message={error} retry={() => { void load(); }} /> : null}
  </Page>;
}
