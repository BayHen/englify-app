import { useCallback, useRef, useState } from 'react';
import { router, useLocalSearchParams, usePreventRemove } from 'expo-router';
import { randomUUID } from 'expo-crypto';
import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { Page } from '@/components/page';
import { AppButton, AppCard, AppModal, AppText, ErrorState, LoadingSkeleton, XPProgressBar } from '@/ui';
import type { ArenaAnswer } from './arena-api';
import { ArenaQuestionInput } from './arena-question-input';
import { arenaKinds, formatArenaAnswer, isArenaAnswerComplete } from './arena-model';
import { startTimeAttack } from './time-attack-api';
import { remainingServerTime } from './time-attack-clock';
import { TimeAttackTimer } from './time-attack-timer';
import { useTimeAttackSession } from './use-time-attack-session';
import { QuestionReportButton } from './question-report-button';
const gap = designTokens.spacing.md;
const reasons = { all_questions: 'All questions completed', time_expired: 'Time expired', no_lives: 'No lives remaining', abandoned: 'Session abandoned' };
export function TimeAttackScreen() { const { id } = useLocalSearchParams<{ id: string }>(); return <TimeAttackGame key={id} id={id} />; }
function TimeAttackGame({ id }: { id: string }) {
  const game = useTimeAttackSession(id); const session = game.snapshot?.session; const question = session?.current_question;
  const [draft, setDraft] = useState<{ id: string; value: ArenaAnswer } | null>(null);
  const [deadlineReached, setDeadlineReached] = useState(false); const [review, setReview] = useState(false); const [onlyIncorrect, setOnlyIncorrect] = useState(false);
  const [leave, setLeave] = useState<(() => void) | null>(null); const [replayBusy, setReplayBusy] = useState(false); const [replayError, setReplayError] = useState('');
  const replayId = useRef<string | null>(null); const replayFlight = useRef(false);
  const disablePrevention = usePreventRemove(session?.status === 'active', ({ repeat }) => setLeave(() => repeat));
  const finish = game.finish;
  const expire = useCallback(async () => {
    setDeadlineReached(true); const value = await finish();
    if (value?.session.status === 'active') setDeadlineReached(false);
    else if (value) setLeave(null);
  }, [finish]);
  const answer = question && draft?.id === question.id ? draft.value : undefined;
  const locked = game.busy || !game.synced || !game.visible || deadlineReached || game.pending !== null;
  async function submit() {
    if (!session || !question || !game.snapshot) return;
    if (remainingServerTime(game.snapshot.clock, performance.now()) <= 0) { expire(); return; }
    if (!game.pending && !isArenaAnswerComplete(question, answer)) return;
    const value = await game.submit(question.id, session.answered_count + 1, game.pending?.answer ?? answer!);
    if (value?.session.status !== 'active' && value) setLeave(null);
  }
  async function abandon() {
    const value = await game.finish(true); if (value && value.session.status !== 'active') {
      disablePrevention(); const action = leave; setLeave(null); action?.();
    }
  }
  async function again() {
    if (!session || replayFlight.current) return; replayFlight.current = true; setReplayBusy(true); setReplayError(''); replayId.current ??= randomUUID();
    try { const next = await startTimeAttack(replayId.current, session.cefr_level, session.difficulty); replayId.current = null;
      router.replace({ pathname: '/time-attack/[id]', params: { id: next.session.id } }); }
    catch (cause) { setReplayError(cause instanceof Error ? cause.message : 'Could not start the next game.'); }
    finally { replayFlight.current = false; setReplayBusy(false); }
  }
  return <Page eyebrow="TIME ATTACK" title={session ? `${session.cefr_level} · ${session.difficulty.toUpperCase()}` : 'Time Attack'} description="One question at a time. Your official score, combo and lives come from the server.">
    {!session && !game.error ? <LoadingSkeleton lines={5} /> : null}
    {session?.status === 'active' && game.snapshot ? <>
      <AppCard tone="primary" style={{ gap }}>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap }}>
          <View><AppText variant="caption">TIME REMAINING</AppText><TimeAttackTimer clock={game.snapshot.clock} active={game.visible && game.synced} onExpire={expire} /></View>
          <View><AppText variant="caption">OFFICIAL SCORE</AppText><AppText variant="title">{session.score}</AppText></View>
        </View>
        <AppText accessibilityLabel={`${session.remaining_lives} lives remaining`}>Lives: {session.remaining_lives} / {session.initial_lives} · Combo: {session.combo} · Best combo: {session.max_combo}</AppText>
        <AppText>{session.answered_count} / {session.question_count} answered</AppText>
        <XPProgressBar value={session.answered_count} max={session.question_count} label="Game progress" showValue={false} />
        {!game.synced ? <AppText tone="muted">Synchronizing with the server. The deadline keeps running.</AppText> : null}
        {deadlineReached ? <AppText tone="muted">Checking the final result with the server…</AppText> : null}
      </AppCard>
      {session.last_answer ? <AppCard tone={session.last_answer.correct ? 'reward' : 'surface'} style={{ gap }}>
        <AppText variant="heading" accessibilityLiveRegion="polite">{session.last_answer.correct ? 'Correct!' : 'Incorrect — one life lost'}</AppText>
        <AppText>+{session.last_answer.points} points · {session.last_answer.multiplier_bps / 10000}× combo · +{session.last_answer.speed_bonus} speed</AppText>
      </AppCard> : null}
      {question ? <AppCard style={{ gap }}><AppText variant="caption" tone="primary">Question {session.answered_count + 1} · {arenaKinds[question.kind]}</AppText>
        {Boolean(question.passage) ? <AppText>{question.passage}</AppText> : null}<AppText variant="heading">{question.prompt}</AppText>
        <ArenaQuestionInput question={question} answer={answer} disabled={locked} onChange={value => setDraft({ id: question.id, value })} />
        <AppButton label={game.pending ? 'Retry answer' : 'Lock answer'} loading={game.busy} disabled={!game.synced || !game.visible || deadlineReached || (!game.pending && !isArenaAnswerComplete(question, answer))} onPress={() => { void submit(); }} />
      </AppCard> : !deadlineReached ? <AppButton label="Next timed question" loading={game.busy} disabled={!game.synced || !game.visible} onPress={game.refresh} /> : null}
      <AppButton label="End Time Attack" variant="ghost" disabled={game.busy} onPress={() => setLeave(() => () => router.replace('/quiz-arena'))} />
    </> : session ? <>
      <AppCard tone="reward" style={{ gap }}><AppText variant="title">{session.is_personal_best ? 'New personal best!' : 'Time Attack result'}</AppText>
        <AppText variant="heading">{session.score} Arena points</AppText><AppText>{session.completion_reason ? reasons[session.completion_reason] : 'Game finished'}</AppText>
        <AppText>{session.accuracy}% accuracy · {session.correct_count} correct · {session.answered_count - session.correct_count} incorrect · {session.question_count - session.answered_count} unanswered</AppText>
        <AppText>Maximum combo: {session.max_combo} · Time used: {((session.duration_ms ?? 0) / 1000).toFixed(1)}s · {session.difficulty.toUpperCase()}</AppText>
        <AppText tone="muted">Arena points are separate from XP. No XP was awarded for this game.</AppText>
      </AppCard>
      <AppButton label={review ? 'Hide game review' : 'Review Answers'} variant="secondary" onPress={() => setReview(value => !value)} />
      {review ? <View style={{ gap }}><AppButton label={onlyIncorrect ? 'Show every answered question' : 'Show incorrect answers only'} variant="secondary" onPress={() => setOnlyIncorrect(value => !value)} />
        {(session.review ?? []).filter(item => !onlyIncorrect || !item.correct).map(item => <AppCard key={item.question.id} style={{ gap }}>
          <AppText variant="label" tone={item.correct ? 'primary' : 'error'}>{item.correct ? 'Correct' : 'Incorrect'} · {item.points} points</AppText>
          {Boolean(item.question.passage) ? <AppText>{item.question.passage}</AppText> : null}<AppText variant="heading">{item.question.prompt}</AppText>
          <AppText>Your answer: {formatArenaAnswer(item.question, item.given_answer)}</AppText><AppText>Correct answer: {formatArenaAnswer(item.question, item.correct_answer)}</AppText>
          <AppText tone="muted">Giải thích: {item.explanation_vi}</AppText><AppText variant="caption">Server-observed response: {(item.elapsed_ms / 1000).toFixed(2)}s · Speed: +{item.speed_bonus}</AppText>
          <QuestionReportButton sessionId={session.id} questionId={item.question.id} />
        </AppCard>)}
        <AppText tone="muted">Only submitted answers are included in review. Unanswered questions count against overall accuracy.</AppText>
      </View> : null}
      <AppButton label="Play Again" loading={replayBusy} onPress={() => { void again(); }} />
      <AppButton label="Back to Quiz Arena" variant="secondary" onPress={() => router.replace('/quiz-arena')} />
    </> : null}
    {Boolean(game.error) ? <ErrorState message={game.error} retry={game.refresh} /> : null}
    {Boolean(replayError) ? <ErrorState message={replayError} retry={() => { void again(); }} /> : null}
    {!session && Boolean(game.error) ? <AppButton label="Back to Quiz Arena" variant="secondary" onPress={() => router.replace('/quiz-arena')} /> : null}
    <AppModal visible={leave !== null} title="End Time Attack?" onClose={() => { if (!game.busy) setLeave(null); }}>
      <AppText>The timer keeps running while this dialog is open. Ending the game preserves accepted answers but excludes it from personal records.</AppText>
      <AppButton label="Keep playing" variant="secondary" disabled={game.busy} onPress={() => setLeave(null)} />
      <AppButton label="End game and leave" loading={game.busy} onPress={() => { void abandon(); }} />
      {Boolean(game.error) ? <AppText tone="error">{game.error}</AppText> : null}
    </AppModal>
  </Page>;
}
