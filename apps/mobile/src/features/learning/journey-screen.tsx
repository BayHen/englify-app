import { useCallback, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import { View } from 'react-native';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppText, EmptyState, ErrorState, LoadingSkeleton, XPProgressBar } from '@/ui';
import { getJourney, getJourneySummary, type JourneyCourse, type JourneySummary } from './api';
import { useAuth } from '@/auth/provider';
import { cacheJourney, getCachedJourney } from '@/features/offline/storage';
import { SyncStatus } from '@/features/offline/sync-status';
import { AdventurePath } from './adventure-path';

export function JourneyScreen() {
  const { profile } = useAuth();
  const userId = profile?.id;
  const [courses, setCourses] = useState<JourneyCourse[]>([]);
  const [summary, setSummary] = useState<JourneySummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [offline, setOffline] = useState(false);
  const load = useCallback(async () => {
    setLoading(true); setError('');
    try { const [journey, progress] = await Promise.all([getJourney(), getJourneySummary()]); setCourses(journey); setSummary(progress); setOffline(false); if (userId) await cacheJourney(userId, { courses: journey, savedAt: new Date().toISOString() }); }
    catch (cause) { const cached = userId ? await getCachedJourney(userId) : null; if (cached) { setCourses(cached.courses); setOffline(true); } else setError(cause instanceof Error ? cause.message : 'Could not load journey'); }
    finally { setLoading(false); }
  }, [userId]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  return <Page eyebrow="THE LEARNING TRAIL" title="Your adventure" description="Every lesson moves your story forward." compact>
    <SyncStatus />
    {offline ? <AppCard tone="reward"><AppText variant="label">Offline journey</AppText><AppText tone="muted">Showing the last downloaded map. Unlocks and XP update after synchronization.</AppText></AppCard> : null}
    {loading ? <LoadingSkeleton lines={5} /> : error ? <ErrorState message={error} retry={() => { void load(); }} /> : courses.length ? <>
      {summary ? <AppCard tone="primary" style={{ gap: 8 }}><AppText variant="heading">Level {summary.level} · {summary.xp_total} XP</AppText><XPProgressBar value={summary.xp_into_level} max={summary.xp_for_next_level} label="XP toward next level" /><AppText tone="muted">{summary.completed_lessons} / {summary.total_lessons} lessons complete · Replay to improve mastery.</AppText></AppCard> : null}
      {courses.map((course) => <View key={course.id} style={{ gap: 14 }}><AppText variant="heading">{course.title}</AppText>
        {course.units.map((unit) => <AdventurePath key={unit.id} unit={unit} />)}
      </View>)}
    </> : <EmptyState title="No published lessons yet" message="Load the development seed data after applying migrations." />}
    <AppButton label="Refresh journey" variant="secondary" onPress={() => { void load(); }} />
    <NavLink href="/learning-plan" label="See your learning plan" />
  </Page>;
}
