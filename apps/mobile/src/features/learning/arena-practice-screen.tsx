import { useEffect, useRef, useState } from 'react';
import { router, useLocalSearchParams, usePreventRemove } from 'expo-router';
import { randomUUID } from 'expo-crypto';
import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { Page } from '@/components/page';
import { AppButton, AppCard, AppModal, AppText, EmptyState, ErrorState, LoadingSkeleton, XPProgressBar } from '@/ui';
import { endArena, getArenaSession, startArena, submitArena, type ArenaAnswer, type ArenaConfig, type ArenaSession } from './arena-api';
import { arenaKinds, arenaTopics, formatArenaAnswer, isArenaAnswerComplete } from './arena-model';
import { ArenaQuestionInput } from './arena-question-input';
import { QuestionReportButton } from './question-report-button';

const gap = designTokens.spacing.md;
export function ArenaPracticeScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <PracticeSession key={id} id={id} />;
}

function PracticeSession({ id }: { id: string }) {
  const [session, setSession] = useState<ArenaSession | null>(null);
  const [answers, setAnswers] = useState<Record<string, ArenaAnswer>>({});
  const [index, setIndex] = useState(0); const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false); const [error, setError] = useState(''); const [review, setReview] = useState(false);
  const [onlyIncorrect, setOnlyIncorrect] = useState(false); const [reload, setReload] = useState(0);
  const [leaveAction, setLeaveAction] = useState<(() => void) | null>(null);
  const retryAction = useRef<() => void>(() => {});
  const inFlight = useRef(false); const replayId = useRef<string | null>(null);
  const disablePrevention = usePreventRemove(session?.status === 'active', ({ repeat }) => setLeaveAction(() => repeat));
  useEffect(() => {
    let live = true;
    void getArenaSession(id).then(value => { if (live) { setSession(value); setAnswers({}); setIndex(0); setReview(false); } })
      .catch(cause => { if (live) { retryAction.current = () => { setLoading(true); setError(''); setReload(value => value + 1); }; setError(cause instanceof Error ? cause.message : 'Could not load this practice quiz.'); } })
      .finally(() => { if (live) setLoading(false); });
    return () => { live = false; };
  }, [id, reload]);
  async function submit() {
    if (!session || inFlight.current) return;
    const missing = session.questions.findIndex(question => !isArenaAnswerComplete(question, answers[question.id]));
    if (missing >= 0) { setIndex(missing); setError('Complete every question before submitting.'); return; }
    retryAction.current = () => { void submit(); };
    inFlight.current = true; setBusy(true); setError('');
    try { setSession(await submitArena(session.id, answers)); setLeaveAction(null); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not submit. Your answers are kept; retry this quiz.'); }
    finally { inFlight.current = false; setBusy(false); }
  }
  async function end() {
    if (inFlight.current) return; inFlight.current = true; setBusy(true); setError('');
    retryAction.current = () => { void end(); };
    try { await endArena(session?.id ?? id); if (session) setSession({ ...session, status: 'abandoned' }); disablePrevention(); const action = leaveAction; setLeaveAction(null); action?.(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not end practice. Your answers are still here.'); }
    finally { inFlight.current = false; setBusy(false); }
  }
  async function again() {
    if (!session || inFlight.current) return; inFlight.current = true; setBusy(true); setError(''); replayId.current ??= randomUUID();
    const config: ArenaConfig = { level: session.cefr_level, topic: session.topic, kind: session.kind,
      difficulty: session.difficulty, count: session.question_count as ArenaConfig['count'] };
    retryAction.current = () => { void again(); };
    try { const next = await startArena(replayId.current, config); replayId.current = null; router.replace({ pathname: '/quiz-practice/[id]', params: { id: next.id } }); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not start another quiz.'); }
    finally { inFlight.current = false; setBusy(false); }
  }
  const question = session?.questions[index];
  const answered = session?.questions.filter(item => isArenaAnswerComplete(item, answers[item.id])).length ?? 0;
  const reviewItems = session?.result?.review.filter(item => !onlyIncorrect || !item.correct) ?? [];
  return <Page eyebrow="QUIZ PRACTICE" title={session ? `${session.cefr_level} · ${session.topic ? arenaTopics[session.topic] : 'Mixed Practice'}` : 'Quiz Practice'}
    description="No time limit. Move between questions freely; submit when you are ready.">
    {loading ? <LoadingSkeleton lines={5} /> : session?.status === 'active' && question ? <>
      <AppCard style={{ gap }}><AppText variant="label">Question {index + 1} of {session.question_count} · {answered} answered</AppText>
        <XPProgressBar value={answered} max={session.question_count} label="Answered questions" showValue={false} />
        <AppText variant="caption" tone="primary">{arenaKinds[question.kind]}</AppText>
        {Boolean(question.passage) ? <AppText>{question.passage}</AppText> : null}
        <AppText variant="heading">{question.prompt}</AppText>
        <ArenaQuestionInput question={question} answer={answers[question.id]} disabled={busy} onChange={value => {
          if (!inFlight.current) { setAnswers(current => ({ ...current, [question.id]: value })); setError(''); }
        }} />
      </AppCard>
      <View style={{ flexDirection: 'row', gap }}><AppButton label="Previous question" style={{ flex: 1 }} variant="secondary" disabled={busy || index === 0} onPress={() => setIndex(value => value - 1)} />
        <AppButton label="Next question" style={{ flex: 1 }} variant="secondary" disabled={busy || index >= session.questions.length - 1} onPress={() => setIndex(value => value + 1)} /></View>
      <AppButton label="Submit Quiz" loading={busy} onPress={() => { void submit(); }} />
      <AppButton label="End unfinished quiz" variant="ghost" disabled={busy} onPress={() => setLeaveAction(() => () => router.replace('/quiz-arena'))} />
    </> : session?.status === 'completed' ? <>
      <AppCard tone="reward" style={{ gap }}><AppText variant="title">Practice complete</AppText>
        <AppText variant="heading">{session.correct_count} / {session.question_count} correct · {session.accuracy}%</AppText>
        <AppText>{session.question_count - (session.correct_count ?? 0)} incorrect · {Math.floor((session.duration_seconds ?? 0) / 60)}m {(session.duration_seconds ?? 0) % 60}s spent</AppText>
        <AppText tone="primary">{session.earned_xp} XP earned</AppText>
        <AppText tone="muted">{session.earned_xp > 0 ? 'Your daily Practice reward has been recorded.' : 'Keep practising for mastery. XP is limited to one qualifying quiz per UTC day.'}</AppText>
        <AppText variant="label">Recommended review areas</AppText>
        <AppText>{session.result?.review_topics.length ? session.result.review_topics.map(topic => arenaTopics[topic]).join(' · ') : 'Excellent accuracy. Try another topic or a higher CEFR level.'}</AppText>
      </AppCard>
      <AppButton label={review ? 'Hide answer review' : 'Review Answers'} variant="secondary" onPress={() => setReview(value => !value)} />
      {review ? <View style={{ gap }}><AppButton label={onlyIncorrect ? 'Show all answers' : 'Review incorrect answers only'} variant="secondary" onPress={() => setOnlyIncorrect(value => !value)} />
        {reviewItems.length === 0 ? <EmptyState title="No incorrect answers" message="You answered every question correctly." /> : reviewItems.map((item, position) =>
          <AppCard key={item.question.id} style={{ gap }}><AppText variant="caption" tone={item.correct ? 'primary' : 'error'}>{item.correct ? 'Correct' : 'Incorrect'} · Review {position + 1}</AppText>
            {Boolean(item.question.passage) ? <AppText>{item.question.passage}</AppText> : null}
            <AppText variant="heading">{item.question.prompt}</AppText>
            <AppText>Your answer: {formatArenaAnswer(item.question, item.given_answer)}</AppText>
            <AppText>Correct answer: {formatArenaAnswer(item.question, item.correct_answer)}</AppText>
            <AppText tone="muted">Giải thích: {item.explanation_vi}</AppText>
            <QuestionReportButton sessionId={session.id} questionId={item.question.id} />
          </AppCard>)}
      </View> : null}
      <AppButton label="Practice Again" loading={busy} onPress={() => { void again(); }} />
    </> : session?.status === 'abandoned' ? <EmptyState title="Practice ended" message="No result or XP was awarded for this unfinished quiz." /> : null}
    {Boolean(error) ? <ErrorState message={error} retry={() => retryAction.current()} /> : null}
    {!loading && !session && Boolean(error) ? <AppButton label="End unavailable quiz" variant="secondary" onPress={() => setLeaveAction(() => () => router.replace('/quiz-arena'))} /> : null}
    {session?.status !== 'active' ? <AppButton label="Back to Quiz Arena" variant="secondary" onPress={() => router.replace('/quiz-arena')} /> : null}
    <AppModal visible={leaveAction !== null} title="End unfinished quiz?" onClose={() => { if (!busy) setLeaveAction(null); }}>
      <AppText>Your answers will be discarded. This session will remain in history as ended, without XP.</AppText>
      <AppButton label="Keep practising" variant="secondary" disabled={busy} onPress={() => setLeaveAction(null)} />
      <AppButton label="End quiz and leave" loading={busy} onPress={() => { void end(); }} />
      {Boolean(error) ? <AppText tone="error">{error}</AppText> : null}
    </AppModal>
  </Page>;
}
