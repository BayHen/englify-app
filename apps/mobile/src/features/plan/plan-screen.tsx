import { useCallback, useState } from 'react';
import { router, useFocusEffect, type Href } from 'expo-router';
import { View } from 'react-native';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppInput, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { completePlanTask, getPlan, regeneratePlan, reschedulePlan, savePlanPreferences, type LearningPlan, type PlanGoal, type PlanLevel, type PlanPreferences, type PlanTask } from './api';

const goals: PlanGoal[] = ['conversation', 'travel', 'work', 'exams'];
const levels: PlanLevel[] = ['beginner', 'intermediate', 'advanced'];
const destinations: Record<PlanTask['kind'], string> = { lesson: '/journey', vocabulary: '/dictionary', review: '/dictionary', speaking: '/speaking', writing: '/writing' };

export function PlanScreen() {
  const [plan, setPlan] = useState<LearningPlan | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [goal, setGoal] = useState<PlanGoal>('conversation');
  const [level, setLevel] = useState<PlanLevel>('beginner');
  const [minutes, setMinutes] = useState('10');
  const [topics, setTopics] = useState('');
  const load = useCallback(async () => {
    setLoading(true);
    try {
      const value = await getPlan();
      setPlan(value); setGoal(value.preferences.learning_goal); setLevel(value.preferences.initial_proficiency);
      setMinutes(String(value.preferences.daily_goal_minutes)); setTopics(value.preferences.preferred_topics.join(', ')); setError(null);
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load the plan.'); }
    finally { setLoading(false); }
  }, []);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  async function change(action: () => Promise<LearningPlan>) {
    if (busy) return;
    setBusy(true);
    try { setPlan(await action()); setError(null); setEditing(false); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not update the plan.'); }
    finally { setBusy(false); }
  }
  function save() {
    const daily = Number(minutes);
    const selectedTopics = topics.split(',').map((item) => item.trim()).filter(Boolean);
    if (!Number.isInteger(daily) || daily < 1 || daily > 180 || selectedTopics.length > 8 || selectedTopics.some((item) => item.length > 40)) {
      setError('Choose 1–180 minutes and up to 8 topics of 40 characters each.'); return;
    }
    const value: PlanPreferences = { learning_goal: goal, initial_proficiency: level, daily_goal_minutes: daily, preferred_topics: selectedTopics };
    void change(() => savePlanPreferences(value));
  }
  const days = [...new Set(plan?.tasks.map((task) => task.scheduled_on) ?? [])];
  return <Page eyebrow="YOUR STUDY ROUTE" title="Learning plan" description="A personal, rule-based schedule from your goals and learning history. Dates follow UTC.">
    {loading ? <LoadingSkeleton /> : error && !plan ? <ErrorState message={error} retry={() => { void load(); }} /> : plan ? <>
      <AppCard tone="primary" style={{ gap: 8 }}><AppText variant="heading">This week</AppText><AppText>{plan.completed_count} of {plan.total_count} tasks completed · {plan.weekly_minutes} planned minutes</AppText><AppText tone="muted">{plan.preferences.daily_goal_minutes} minutes/day · {plan.preferences.learning_goal} · {plan.preferences.initial_proficiency}</AppText></AppCard>
      {!!error && <ErrorState message={error} retry={() => setError(null)} />}
      <View style={{ gap: 10 }}><AppButton label="Change goals and topics" variant="secondary" onPress={() => setEditing(!editing)} /><AppButton label="Regenerate next 7 days" disabled={busy} onPress={() => { void change(regeneratePlan); }} /><AppButton label="Reschedule missed tasks" variant="secondary" disabled={busy} onPress={() => { void change(reschedulePlan); }} /></View>
      {editing && <AppCard style={{ gap: 12 }}><AppText variant="heading">Study preferences</AppText><AppText>Goal</AppText><View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{goals.map((item) => <AppButton key={item} label={item} size="medium" variant={item === goal ? 'primary' : 'secondary'} onPress={() => setGoal(item)} />)}</View><AppText>Level</AppText><View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{levels.map((item) => <AppButton key={item} label={item} size="medium" variant={item === level ? 'primary' : 'secondary'} onPress={() => setLevel(item)} />)}</View><AppInput label="Minutes per day" value={minutes} onChangeText={setMinutes} keyboardType="number-pad" /><AppInput label="Preferred topics, separated by commas" value={topics} onChangeText={setTopics} placeholder="travel, food, work" /><AppButton label="Save and regenerate" disabled={busy} onPress={save} /></AppCard>}
      {days.length ? days.map((day) => <View key={day} style={{ gap: 10 }}><AppText variant="heading" accessibilityRole="header">{day}</AppText>{plan.tasks.filter((task) => task.scheduled_on === day).map((task) => <AppCard key={task.id} style={{ gap: 7 }}><AppText variant="label">{task.status === 'completed' ? '✓ ' : ''}{task.title}</AppText><AppText variant="caption" tone="muted">{task.kind} · {task.duration_minutes} min{task.target_count ? ` · goal ${task.target_count}` : ''}{task.topic ? ` · ${task.topic}` : ''}</AppText>{task.scheduled_on !== task.original_date && <AppText variant="caption" tone="primary">Moved from {task.original_date}</AppText>}{task.kind === 'lesson' && task.lesson_state === 'locked' && <AppText variant="caption" tone="muted">Complete the previous lesson to unlock this one.</AppText>}{task.status === 'pending' && <View style={{ gap: 8 }}><AppButton label={task.kind === 'lesson' ? 'Open lesson' : 'Open practice'} size="medium" variant="secondary" disabled={task.kind === 'lesson' && task.lesson_state === 'locked'} onPress={() => router.push((task.kind === 'lesson' && task.lesson_id ? `/lesson/${task.lesson_id}` : destinations[task.kind]) as Href)} />{task.kind !== 'lesson' && <AppButton label="Mark practiced" size="medium" disabled={busy} onPress={() => { void change(() => completePlanTask(task.id)); }} />}</View>}</AppCard>)}</View>) : <EmptyState title="No tasks yet" message="Published lessons or study activities are not available. Try regenerating after content is added." />}
      <AppText variant="caption" tone="muted">Practice tasks are self-reported. Lesson completion is verified by its quiz. Practice here does not award XP automatically.</AppText>
    </> : null}
    <NavLink href="/home" label="Back to dashboard" />
  </Page>;
}
