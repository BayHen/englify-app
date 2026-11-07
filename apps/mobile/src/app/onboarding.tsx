import { router } from 'expo-router';
import { useState } from 'react';
import { Page } from '@/components/page';
import { AppButton, AppCard, AppText } from '@/ui';
import { useAuth } from '@/auth/provider';
import type { LearningGoal, Proficiency } from '@/auth/api';

const goals: { value: LearningGoal; title: string; detail: string }[] = [
  { value: 'conversation', title: 'Conversation', detail: 'Feel at ease in daily chats.' },
  { value: 'travel', title: 'Travel', detail: 'Navigate new places with confidence.' },
  { value: 'work', title: 'Work', detail: 'Communicate clearly with colleagues.' },
  { value: 'exams', title: 'Exams', detail: 'Build a steady study routine.' },
];
const levels: { value: Proficiency; title: string }[] = [
  { value: 'beginner', title: 'Just starting' },
  { value: 'intermediate', title: 'Finding my flow' },
  { value: 'advanced', title: 'Building fluency' },
];

export default function Onboarding() {
  const { saveOnboarding } = useAuth();
  const [goal, setGoal] = useState<LearningGoal | null>(null);
  const [level, setLevel] = useState<Proficiency | null>(null);
  const [minutes, setMinutes] = useState(10);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  async function submit() {
    if (!goal || !level) return;
    setBusy(true); setError('');
    try { await saveOnboarding({ learning_goal: goal, initial_proficiency: level, daily_goal_minutes: minutes }); router.replace('/home'); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save your choices'); }
    finally { setBusy(false); }
  }
  return <Page eyebrow="YOUR FIRST STEP" title="Make English part of your day" description="Choose a goal and starting point. These preferences are saved to your profile.">
    <AppText variant="heading">What brings you here?</AppText>
    {goals.map((item) => <AppCard key={item.value} tone={goal === item.value ? 'primary' : 'surface'} onPress={() => setGoal(item.value)} accessibilityLabel={`${item.title}${goal === item.value ? ', selected' : ''}`}><AppText variant="label">{item.title}</AppText><AppText tone="muted">{item.detail}</AppText></AppCard>)}
    <AppText variant="heading">Your starting level</AppText>
    {levels.map((item) => <AppCard key={item.value} tone={level === item.value ? 'primary' : 'surface'} onPress={() => setLevel(item.value)} accessibilityLabel={`${item.title}${level === item.value ? ', selected' : ''}`}><AppText variant="label">{item.title}</AppText></AppCard>)}
    <AppText variant="heading">Daily learning goal</AppText>
    {[5, 10, 15, 20].map((value) => <AppCard key={value} tone={minutes === value ? 'reward' : 'surface'} onPress={() => setMinutes(value)} accessibilityLabel={`${value} minutes a day${minutes === value ? ', selected' : ''}`}><AppText variant="label">{value} minutes a day</AppText></AppCard>)}
    {!!error && <AppText tone="error" accessibilityRole="alert">{error}</AppText>}
    <AppButton label="Save my learning plan" onPress={() => { void submit(); }} disabled={!goal || !level} loading={busy} size="large" />
  </Page>;
}
