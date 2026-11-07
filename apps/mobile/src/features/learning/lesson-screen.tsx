import { useEffect, useRef, useState } from 'react';
import { router, useLocalSearchParams } from 'expo-router';
import { Animated, View } from 'react-native';
import * as Speech from 'expo-speech';
import * as Crypto from 'expo-crypto';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppInput, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { useReducedMotion } from '@/ui/use-reduced-motion';
import { getAttempts, getLesson, startLesson, submitLesson, type Answer, type LessonDetail, type QuizResult, type Question } from './api';

function MatchingQuestion({ question, answer, onChange }: { question: Question; answer: Record<string, string>; onChange: (value: Record<string, string>) => void }) {
  const left = Array.isArray(question.payload.left) ? question.payload.left as { id: string; text: string }[] : [];
  const right = Array.isArray(question.payload.right) ? question.payload.right as { id: string; text: string }[] : [];
  return <View style={{ gap: 8 }}>{left.map((item) => <View key={item.id} style={{ gap: 5 }}><AppText variant="label">{item.text}</AppText>
    {right.map((choice) => <AppButton key={choice.id} label={choice.text} variant={answer[item.id] === choice.id ? 'primary' : 'secondary'} onPress={() => onChange({ ...answer, [item.id]: choice.id })} />)}
  </View>)}</View>;
}

function RewardFeedback({ rewards }: { rewards: QuizResult['rewards'] }) {
  const reduced = useReducedMotion();
  const [opacity] = useState(() => new Animated.Value(0));
  useEffect(() => {
    if (reduced) { opacity.setValue(1); return; }
    const animation = Animated.timing(opacity, { toValue: 1, duration: 450, useNativeDriver: true });
    animation.start();
    return () => animation.stop();
  }, [opacity, reduced]);
  if (!rewards.length) return null;
  return <Animated.View style={{ opacity, gap: 8 }} accessibilityLiveRegion="polite">
    {rewards.map((reward, index) => <AppCard key={`${reward.kind}-${reward.title}-${index}`} tone={reward.kind === 'xp' ? 'primary' : 'reward'} style={{ gap: 5 }}>
      <AppText variant="heading">{reward.kind === 'level' ? 'Level up! ' : reward.kind === 'badge' ? 'Badge unlocked! ' : reward.kind === 'quest' ? 'Quest complete! ' : ''}{reward.title}</AppText>
      <AppText>{reward.message}{reward.amount > 0 && reward.kind !== 'xp' ? ` +${reward.amount} XP` : ''}</AppText>
    </AppCard>)}
  </Animated.View>;
}

export function LessonScreen() {
  const params = useLocalSearchParams<{ id: string }>();
  const id = params.id;
  const [lesson, setLesson] = useState<LessonDetail | null>(null);
  const [attempts, setAttempts] = useState<QuizResult[]>([]);
  const [answers, setAnswers] = useState<Record<string, Answer>>({});
  const [result, setResult] = useState<QuizResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const requestId = useRef<string | null>(null);
  const submitting = useRef(false);
  useEffect(() => {
    if (!id) return;
    let live = true;
    void (async () => {
      try {
        const [detail, history] = await Promise.all([getLesson(id), getAttempts(id)]);
        if (live) { setLesson(detail); setAttempts(history); }
      } catch (cause) { if (live) setError(cause instanceof Error ? cause.message : 'Could not load lesson'); }
      finally { if (live) setLoading(false); }
    })();
    return () => { live = false; Speech.stop(); };
  }, [id]);
  function setAnswer(questionId: string, value: Answer) { setAnswers((old) => ({ ...old, [questionId]: value })); requestId.current = null; setResult(null); }
  async function begin() {
    if (!lesson || !id) return;
    setBusy(true); setError('');
    try { const started = await startLesson(id); setLesson({ ...lesson, state: started.state }); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not start lesson'); }
    finally { setBusy(false); }
  }
  async function submit() {
    if (!lesson || !id || submitting.current) return;
    if (lesson.questions.some((question) => !answers[question.id] || (typeof answers[question.id] === 'object' && Object.keys(answers[question.id]).length === 0))) { setError('Answer every question before submitting.'); return; }
    submitting.current = true; setBusy(true); setError('');
    requestId.current ??= Crypto.randomUUID();
    try {
      const graded = await submitLesson(id, requestId.current, answers);
      setResult(graded); setLesson({ ...lesson, state: graded.state }); setAttempts([graded, ...attempts]);
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Submission failed. Retry sends the same attempt ID.'); }
    finally { submitting.current = false; setBusy(false); }
  }
  return <Page eyebrow="LESSON" title={lesson?.title ?? 'Loading lesson'} description={lesson?.objective ?? 'Preparing your learning activity.'}>
    {loading ? <LoadingSkeleton lines={5} /> : error && !lesson ? <ErrorState message={error} /> : lesson ? <>
      <AppCard tone="primary"><AppText variant="label">Status: {lesson.state.replace('_', ' ')}</AppText><AppText tone="muted">Answers are checked by the server. Passing requires at least 70% correct.</AppText></AppCard>
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
      {lesson.questions.length > 0 && !result && <AppButton label="Submit answers" onPress={() => { void submit(); }} loading={busy} />}
      {attempts.length > 0 && <AppCard><AppText variant="label">Previous attempts: {attempts.length}</AppText><AppText tone="muted">Latest: {attempts[0].correct_count}/{attempts[0].question_count} correct</AppText></AppCard>}
    </> : <EmptyState title="Lesson unavailable" message="Return to the journey to choose an unlocked lesson." />}
    <NavLink href="/journey" label="Back to journey" />
  </Page>;
}
