import { useCallback, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { readJourneyMap, refreshJourneyMap } from './journey-map-cache';
import { router, useFocusEffect, type Href } from 'expo-router';
import { View } from 'react-native';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppModal, AppText, EmptyState, ErrorState, LoadingSkeleton, XPProgressBar } from '@/ui';
import { getJourneyDailyPlan, getJourneyGamification, getJourneyLearningProfile, getJourneySummary, type DailyPlan, type JourneyCourse, type JourneyGamification, type JourneyLearningProfile, type JourneyLesson, type JourneySummary } from './api';
import { useAuth } from '@/auth/provider';
import { getCachedJourney } from '@/features/offline/storage';
import { SyncStatus } from '@/features/offline/sync-status';
import { AdventurePath } from './adventure-path';
import { toggleExpandedUnit } from './unit-accordion';

const legacyEverydayEnglishCourseId = '22222222-2222-4222-8222-222222222201';

export function JourneyScreen() {
  const { profile } = useAuth();
  const userId = profile?.id;
  const queryClient = useQueryClient();
  const [courses, setCourses] = useState<JourneyCourse[]>(() => readJourneyMap(queryClient, userId) ?? []);
  const [summary, setSummary] = useState<JourneySummary | null>(null);
  const [learningProfile, setLearningProfile] = useState<JourneyLearningProfile | null>(null);
  const [dailyPlan, setDailyPlan] = useState<DailyPlan | null>(null);
  const [gamification, setGamification] = useState<JourneyGamification | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [offline, setOffline] = useState(false);
  const [lockedLesson, setLockedLesson] = useState<JourneyLesson | null>(null);
  const [expandedUnitId, setExpandedUnitId] = useState<string | null>(null);
  const load = useCallback(async () => {
    if (!userId) return;
    let received = false;
    void getCachedJourney(userId).then((cached) => {
      if (!received && cached && !readJourneyMap(queryClient, userId)) {
        setCourses((current) => current.length ? current : cached.courses);
      }
    }).catch(() => undefined);
    setLoading(true); setError('');
    const refreshDetails = Promise.allSettled([
      getJourneySummary().then(setSummary),
      getJourneyLearningProfile().then(setLearningProfile),
      getJourneyDailyPlan().then(setDailyPlan),
      getJourneyGamification().then(setGamification),
    ]);
    try {
      const journey = await refreshJourneyMap(queryClient, userId);
      received = true;
      setCourses(journey);
      setOffline(false);
    } catch (cause) {
      const cached = userId ? await getCachedJourney(userId).catch(() => null) : null;
      if (cached) setCourses((current) => current.length ? current : cached.courses);
      setOffline(true);
      setError(cause instanceof Error ? cause.message : 'Could not load journey');
    } finally {
      setLoading(false);
    }
    await refreshDetails;
  }, [userId, queryClient]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  const visibleCourses = courses.filter((course) => course.id !== legacyEverydayEnglishCourseId);
  return <Page eyebrow="THE LEARNING TRAIL" title="Your adventure" description="Every lesson moves your story forward." compact>
    <SyncStatus />
    {gamification ? <AppCard tone="reward" style={{ gap: 7 }}><AppText variant="heading">{gamification.learning_streak.current_streak} day learning streak</AppText><AppText tone="muted">Best {gamification.learning_streak.longest_streak} days · {gamification.learning_streak.total_active_days} active days</AppText><AppText variant="caption">{gamification.quests.filter((quest) => quest.completed).length}/{gamification.quests.length} active quests completed</AppText></AppCard> : null}
    {offline ? <AppCard tone="reward"><AppText variant="label">Offline journey</AppText><AppText tone="muted">Showing the last downloaded map. Unlocks and XP update after synchronization.</AppText></AppCard> : null}
    {loading && courses.length === 0 ? <LoadingSkeleton lines={5} /> : error && courses.length === 0 ? <ErrorState message={error} retry={() => { void load(); }} /> : courses.length ? <>
      <AppCard tone="primary" style={{ gap: 7 }}><AppText variant="caption">YOUR LEARNING PATH</AppText><AppText variant="heading">{learningProfile?.selected_cefr ?? 'Choose a level'} · {learningProfile?.goal ?? 'General English'}</AppText><AppText tone="muted">Recommended placement: {learningProfile?.recommended_cefr ?? 'Not assessed'} · {learningProfile?.daily_minutes ?? 10} minutes/day</AppText><AppButton label="Edit learning goals" variant="secondary" onPress={() => router.push('/learning-preferences')} /></AppCard>
      <View style={{ gap: 9 }}><AppText variant="heading">Today&apos;s learning plan</AppText>{dailyPlan?.items.length ? dailyPlan.items.map((item) => <AppCard key={item.id} style={{ gap: 6 }}><AppText variant="label">{item.title}</AppText><AppText variant="caption" tone="muted">About {item.estimated_minutes} min · {item.completed_at ? 'Completed' : 'Ready'}</AppText>{item.lesson_id && !item.completed_at ? <AppButton label="Open activity" size="medium" variant="secondary" onPress={() => router.push(`/lesson/${item.lesson_id}` as Href)} /> : null}</AppCard>) : <AppText tone="muted">No eligible activities yet.</AppText>}</View>
      <View style={{ gap: 9 }}><AppText variant="heading">Recommended for you</AppText>{learningProfile?.recommendations.length ? learningProfile.recommendations.map((item) => <AppCard key={`${item.reason_code}-${item.lesson_id}`} style={{ gap: 6 }}><AppText variant="label">{item.title}</AppText><AppText tone="muted">{item.reason_vi}</AppText><AppButton label="Open lesson" size="medium" variant="secondary" onPress={() => router.push(item.destination as Href)} /></AppCard>) : <AppText tone="muted">Complete a few activities to improve recommendations.</AppText>}<AppText variant="caption" tone="muted">{learningProfile?.insight}</AppText></View>
      {summary ? <AppCard tone="primary" style={{ gap: 8 }}><AppText variant="heading">Level {summary.level} · {summary.xp_total} XP</AppText><XPProgressBar value={summary.xp_into_level} max={summary.xp_for_next_level} label="XP toward next level" /><AppText tone="muted">{summary.completed_lessons} / {summary.total_lessons} lessons complete · Replay to improve mastery.</AppText></AppCard> : null}
      {visibleCourses.map((course) => <View key={course.id} style={{ gap: 14 }}><View style={{ gap: 3 }}><AppText variant="caption" tone="primary">{course.cefr_level ? `${course.cefr_level} LEARNING PATH` : 'LEARNING PATH'}</AppText><AppText variant="heading">{course.title}</AppText></View>
        {course.continue_lesson ? <AppCard tone="primary" style={{ gap: 8 }}><AppText variant="caption">CONTINUE LEARNING</AppText><AppText variant="heading">{course.continue_lesson.title}</AppText><AppText tone="muted">{course.continue_lesson.objective}</AppText><AppButton label={course.continue_lesson.state === 'in_progress' ? 'Continue lesson' : course.continue_lesson.state === 'completed' || course.continue_lesson.state === 'mastered' ? 'Review lesson' : course.continue_lesson.kind === 'checkpoint' ? 'Start checkpoint' : 'Start lesson'} onPress={() => router.push(`/lesson/${course.continue_lesson!.id}` as Href)} /></AppCard> : null}
        {(course.chapters?.length ? course.chapters : [{ id: `${course.id}-legacy`, title: 'Learning path', description: '', position: 1, compatibility: true, units: course.units }]).map((chapter) => <View key={chapter.id} style={{ gap: 10 }}><View style={{ gap: 3 }}><AppText variant="caption" tone="primary">CHAPTER {chapter.position === 2147483647 ? '· EXISTING CONTENT' : chapter.position}</AppText><AppText variant="heading">{chapter.title}</AppText>{Boolean(chapter.description) ? <AppText tone="muted">{chapter.description}</AppText> : null}<AppText variant="caption" tone="muted">{chapter.units.filter((unit) => unit.is_required !== false && unit.progress_percent === 100).length} of {chapter.units.filter((unit) => unit.is_required !== false).length} required units completed</AppText></View>
          {chapter.units.map((unit) => <AdventurePath key={unit.id} unit={unit} expanded={expandedUnitId===unit.id} onToggle={()=>setExpandedUnitId((current)=>toggleExpandedUnit(current,unit.id))} onLocked={setLockedLesson} />)}</View>)}
      </View>)}
    </> : <EmptyState title="No published lessons yet" message="Load the development seed data after applying migrations." />}
    <AppButton label="Refresh journey" variant="secondary" onPress={() => { void load(); }} />
    <NavLink href="/learning-plan" label="See your learning plan" />
    <NavLink href={'/journey-placement' as Href} label="Take or retake placement test" />
    <AppModal visible={lockedLesson !== null} title="Lesson locked" onClose={() => setLockedLesson(null)}>
      <AppText>{lockedLesson?.locked_reason ?? 'Complete the required lessons first.'}</AppText>
      {lockedLesson?.prerequisites?.map((item) => <AppText key={item.id} tone={item.completed ? 'success' : 'muted'}>{item.completed ? '✓' : '○'} {item.title}</AppText>)}
      <AppButton label="Got it" onPress={() => setLockedLesson(null)} />
    </AppModal>
  </Page>;
}
