import { useCallback, useEffect, useRef, useState } from 'react';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { View } from 'react-native';
import Animated, { FadeIn } from 'react-native-reanimated';
import * as Speech from 'expo-speech';
import * as Crypto from 'expo-crypto';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppInput, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { useReducedMotion } from '@/ui/use-reduced-motion';
import { getAttempts, getLesson, startLesson, submitLesson, type Answer, type LessonDetail, type QuizResult, type Question } from './api';
import { downloadLesson } from './api';
import { useAuth } from '@/auth/provider';
import { ApiError } from '@/lib/api';
import { cacheLesson, getCachedLesson, listEvents, queueEvent } from '@/features/offline/storage';
import { SyncStatus } from '@/features/offline/sync-status';

function MatchingQuestion({ question, answer, onChange }: { question: Question; answer: Record<string, string>; onChange: (value: Record<string, string>) => void }) {
  const left = Array.isArray(question.payload.left) ? question.payload.left as { id: string; text: string }[] : [];
  const right = Array.isArray(question.payload.right) ? question.payload.right as { id: string; text: string }[] : [];
  return <View style={{ gap: 8 }}>{left.map((item) => <View key={item.id} style={{ gap: 5 }}><AppText variant="label">{item.text}</AppText>
    {right.map((choice) => <AppButton key={choice.id} label={choice.text} variant={answer[item.id] === choice.id ? 'primary' : 'secondary'} onPress={() => onChange({ ...answer, [item.id]: choice.id })} />)}
  </View>)}</View>;
}

function RewardFeedback({ rewards }: { rewards: QuizResult['rewards'] }) {
  const reduced = useReducedMotion();
  if (!rewards.length) return null;
  return <Animated.View entering={reduced ? undefined : FadeIn.duration(420)} style={{ gap: 8 }} accessibilityLiveRegion="polite">
    {rewards.map((reward, index) => <AppCard key={`${reward.kind}-${reward.title}-${index}`} tone={reward.kind === 'xp' ? 'primary' : 'reward'} style={{ gap: 5 }}>
      <AppText variant="heading">{reward.kind === 'level' ? 'Level up! ' : reward.kind === 'badge' ? 'Badge unlocked! ' : reward.kind === 'quest' ? 'Quest complete! ' : ''}{reward.title}</AppText>
      <AppText>{reward.message}{reward.amount > 0 && reward.kind !== 'xp' ? ` +${reward.amount} XP` : ''}</AppText>
    </AppCard>)}
  </Animated.View>;
}

export function LessonScreen() {
  const { profile } = useAuth();
  const userId = profile?.id;
  const params = useLocalSearchParams<{ id: string }>();
  const id = params.id;
  const [lesson, setLesson] = useState<LessonDetail | null>(null);
  const [attempts, setAttempts] = useState<QuizResult[]>([]);
  const [answers, setAnswers] = useState<Record<string, Answer>>({});
  const [result, setResult] = useState<QuizResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [offline, setOffline] = useState(false);
  const [contentVersion, setContentVersion] = useState<string | null>(null);
  const [queued, setQueued] = useState(false);
  const requestId = useRef<string | null>(null);
  const submitting = useRef(false);
  useFocusEffect(useCallback(() => {
    if (!id || !userId) return;
    void listEvents(userId).then((events) => {
      const latest = events.filter((event) => event.kind === 'lesson_submission' && (event.payload as { lessonId: string }).lessonId === id).at(-1);
      if (latest?.status === 'synced' && latest.result && requestId.current === latest.id) { setResult(latest.result); setQueued(false); }
      else if (latest?.status === 'pending') setQueued(true);
      else if (latest?.status === 'conflict' || latest?.status === 'rejected') { setQueued(false); setError(latest.message ?? 'Offline attempt requires review.'); }
    });
  }, [id, userId]));
  useEffect(() => {
    if (!id) return;
    let live = true;
    void (async () => {
      try {
        const [detail, history, cached] = await Promise.all([getLesson(id), getAttempts(id), userId ? getCachedLesson(userId, id) : Promise.resolve(null)]);
        if (live) { setLesson(detail); setAttempts(history); setContentVersion(cached?.contentVersion ?? null); setOffline(false); }
      } catch (cause) { const cached = userId ? await getCachedLesson(userId, id) : null; if (live) { if (cached) { setLesson(cached.lesson); setContentVersion(cached.contentVersion); setOffline(true); } else setError(cause instanceof Error ? cause.message : 'Could not load lesson'); } }
      finally { if (live) setLoading(false); }
    })();
    return () => { live = false; Speech.stop(); };
  }, [id, userId]);
  async function download() {
    if (!id || !userId) return;
    setBusy(true); setError('');
    try { const pack = await downloadLesson(id); await cacheLesson(userId, id, { lesson: pack.lesson, contentVersion: pack.content_version, savedAt: new Date().toISOString() }); setLesson(pack.lesson); setContentVersion(pack.content_version); setOffline(false); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Download failed'); }
    finally { setBusy(false); }
  }
  function setAnswer(questionId: string, value: Answer) { setAnswers((old) => ({ ...old, [questionId]: value })); requestId.current = null; setResult(null); }
  async function begin() {
    if (!lesson || !id) return;
    setBusy(true); setError('');
    try { if (offline) { setLesson({ ...lesson, state: 'in_progress' }); return; } const started = await startLesson(id); setLesson({ ...lesson, state: started.state }); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not start lesson'); }
    finally { setBusy(false); }
  }
  async function submit() {
    if (!lesson || !id || submitting.current) return;
    if (lesson.questions.some((question) => !answers[question.id] || (typeof answers[question.id] === 'object' && Object.keys(answers[question.id]).length === 0))) { setError('Answer every question before submitting.'); return; }
    submitting.current = true; setBusy(true); setError('');
    requestId.current ??= Crypto.randomUUID();
    try {
      if (offline) {
        if (!userId || !contentVersion) throw new Error('Download this lesson while online before submitting offline.');
        const existing = (await listEvents(userId)).find((event) => event.id === requestId.current);
        if (!existing) await queueEvent({ id: requestId.current, userId, kind: 'lesson_submission', payload: { lessonId: id, contentVersion, answers }, status: 'pending', attempts: 0, nextRetryAt: 0, message: null, createdAt: new Date().toISOString(), result: null });
        setQueued(true); return;
      }
      const graded = await submitLesson(id, requestId.current, answers);
      setResult(graded); setLesson({ ...lesson, state: graded.state }); setAttempts([graded, ...attempts]);
    } catch (cause) {
      if (cause instanceof ApiError && cause.status === 0 && userId && contentVersion) {
        await queueEvent({ id: requestId.current, userId, kind: 'lesson_submission', payload: { lessonId: id, contentVersion, answers }, status: 'pending', attempts: 0, nextRetryAt: 0, message: null, createdAt: new Date().toISOString(), result: null });
        setOffline(true); setQueued(true);
      } else setError(cause instanceof Error ? cause.message : 'Submission failed. Retry sends the same attempt ID.');
    }
    finally { submitting.current = false; setBusy(false); }
  }
  return <Page eyebrow="LESSON" title={lesson?.title ?? 'Loading lesson'} description={lesson?.objective ?? 'Preparing your learning activity.'}>
    <SyncStatus />
    {loading ? <LoadingSkeleton lines={5} /> : error && !lesson ? <ErrorState message={error} /> : lesson ? <>
      <AppCard tone="primary"><AppText variant="label">Status: {lesson.state.replace('_', ' ')}</AppText><AppText tone="muted">Answers are checked by the server. Passing requires at least 70% correct.</AppText>{offline ? <AppText tone="muted">Offline copy. Results and XP appear after server validation.</AppText> : null}</AppCard>
      {!offline ? <AppButton label={contentVersion ? 'Update offline download' : 'Download for offline use'} variant="secondary" onPress={() => { void download(); }} loading={busy} /> : null}
      {lesson.state === 'available' && <AppButton label="Start lesson" onPress={() => { void begin(); }} loading={busy} />}
      {lesson.items.map((item, index) => <AppCard key={index} style={{ gap: 5 }}><AppText variant="caption" tone="primary">{item.kind.toUpperCase()}</AppText><AppText>{item.body.text ?? ''}</AppText></AppCard>)}
      {lesson.questions.length ? lesson.questions.map((question, index) => <AppCard key={question.id} style={{ gap: 10 }}><AppText variant="caption" tone="primary">QUESTION {index + 1} · {question.kind.replace('_', ' ')}</AppText><AppText variant="heading">{question.prompt}</AppText>
        {question.kind === 'multiple_choice' ? question.options.map((option) => <AppButton key={option.id} label={option.text} variant={answers[question.id] === option.id ? 'primary' : 'secondary'} onPress={() => setAnswer(question.id, option.id)} />) :
         question.kind === 'matching' ? <MatchingQuestion question={question} answer={typeof answers[question.id] === 'object' ? answers[question.id] as Record<string, string> : {}} onChange={(value) => setAnswer(question.id, value)} /> : <>
          {question.kind === 'listening' && <AppButton label="Play audio with device voice" variant="secondary" onPress={() => { Speech.stop(); Speech.speak(String(question.payload.speak_text ?? ''), { language: 'en-US' }); }} />}
          <AppInput label="Your answer" placeholder={String(question.payload.placeholder ?? 'Type your answer')} value={typeof answers[question.id] === 'string' ? answers[question.id] as string : ''} onChangeText={(text) => setAnswer(question.id, text)} autoCapitalize="none" />
        </>}
      </AppCard>) : <EmptyState title="No quiz ready" message="This lesson has no questions yet." />}
      {!!error && <ErrorState message={error} retry={() => { void submit(); }} />}
      {!!result && <AppCard tone={result.passed ? 'reward' : 'surface'} style={{ gap: 8 }}><AppText variant="heading">{result.passed ? 'Lesson complete!' : 'Keep practicing'}</AppText><AppText>{result.correct_count} / {result.question_count} correct · {result.earned_xp} XP earned</AppText><AppText tone="muted">{result.state === 'mastered' ? 'Mastered after a perfect replay.' : result.passed ? 'The next lesson is now available.' : 'Reach 70% to unlock the next lesson.'}</AppText><AppButton label="Back to journey" onPress={() => router.replace('/journey')} /></AppCard>}
      {!!result && <RewardFeedback rewards={result.rewards} />}
      {queued ? <AppCard tone="reward"><AppText variant="label">Attempt saved on this device</AppText><AppText tone="muted">Waiting for server validation. No XP has been awarded yet.</AppText></AppCard> : null}
      {lesson.questions.length > 0 && !result && !queued ? <AppButton label={offline ? 'Save attempt for sync' : 'Submit answers'} onPress={() => { void submit(); }} loading={busy} /> : null}
      {attempts.length > 0 && <AppCard><AppText variant="label">Previous attempts: {attempts.length}</AppText><AppText tone="muted">Latest: {attempts[0].correct_count}/{attempts[0].question_count} correct</AppText></AppCard>}
    </> : <EmptyState title="Lesson unavailable" message="Return to the journey to choose an unlocked lesson." />}
    <NavLink href="/journey" label="Back to journey" />
  </Page>;
}
