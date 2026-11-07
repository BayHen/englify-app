import { useCallback, useState } from 'react';
import { router, useFocusEffect, type Href } from 'expo-router';
import { View } from 'react-native';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppText, EmptyState, ErrorState, LessonNode, LoadingSkeleton, XPProgressBar } from '@/ui';
import { getJourney, getJourneySummary, type JourneyCourse, type JourneySummary } from './api';

export function JourneyScreen() {
  const [courses, setCourses] = useState<JourneyCourse[]>([]);
  const [summary, setSummary] = useState<JourneySummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const load = useCallback(async () => {
    setLoading(true); setError('');
    try { const [journey, progress] = await Promise.all([getJourney(), getJourneySummary()]); setCourses(journey); setSummary(progress); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load journey'); }
    finally { setLoading(false); }
  }, []);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  return <Page eyebrow="YOUR JOURNEY" title="Learning path" description="Complete each lesson to unlock the next. Your progress is saved to your account.">
    {loading ? <LoadingSkeleton lines={5} /> : error ? <ErrorState message={error} retry={() => { void load(); }} /> : courses.length ? <>
      {summary && <AppCard tone="primary" style={{ gap: 8 }}><AppText variant="heading">Level {summary.level} · {summary.xp_total} XP</AppText><XPProgressBar value={summary.xp_into_level} max={summary.xp_for_next_level} label="XP toward next level" /><AppText tone="muted">{summary.completed_lessons} / {summary.total_lessons} lessons complete · Replay to improve mastery.</AppText></AppCard>}
      {courses.map((course) => <View key={course.id} style={{ gap: 14 }}><AppText variant="heading">{course.title}</AppText>
        {course.units.map((unit) => <AppCard key={unit.id} style={{ gap: 10 }}><AppText variant="label" tone="primary">UNIT {unit.position} · {unit.title}</AppText>
          {unit.lessons.map((lesson) => <LessonNode key={lesson.id} order={lesson.position} title={lesson.title} status={lesson.state} onPress={() => router.push(`/lesson/${lesson.id}` as Href)} />)}
        </AppCard>)}
      </View>)}
    </> : <EmptyState title="No published lessons yet" message="Load the development seed data after applying migrations." />}
    <AppButton label="Refresh journey" variant="secondary" onPress={() => { void load(); }} />
    <NavLink href="/home" label="Back to dashboard" />
  </Page>;
}
