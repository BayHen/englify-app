import { useCallback, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { readJourneyMap, refreshJourneyMap } from './journey-map-cache';
import { router, useFocusEffect, type Href } from 'expo-router';
import { View } from 'react-native';
import Animated, { FadeIn } from 'react-native-reanimated';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppModal, AppText, EmptyState, ErrorState, LoadingSkeleton, XPProgressBar } from '@/ui';
import { getJourneyDailyPlan, getJourneyGamification, getJourneyLearningProfile, getJourneySummary, type DailyPlan, type JourneyCourse, type JourneyGamification, type JourneyLearningProfile, type JourneyLesson, type JourneySummary } from './api';
import { useAuth } from '@/auth/provider';
import { getCachedJourney } from '@/features/offline/storage';
import { SyncStatus } from '@/features/offline/sync-status';
import { AdventurePath } from './adventure-path';
import { designTokens } from '@englify/shared';
import { NoirArtwork } from '@/ui/noir-artwork';
import { useReducedMotion } from '@/ui/use-reduced-motion';
import { useAppPalette } from '@/constants/app-theme';

const legacyEverydayEnglishCourseId = '22222222-2222-4222-8222-222222222201';

export function JourneyScreen({ previewCourses }: { previewCourses?: JourneyCourse[] }) {
  const { profile } = useAuth();
  const userId = profile?.id;
  const queryClient = useQueryClient();
  const [courses, setCourses] = useState<JourneyCourse[]>(() => previewCourses ?? readJourneyMap(queryClient, userId) ?? []);
  const [summary, setSummary] = useState<JourneySummary | null>(null);
  const [learningProfile, setLearningProfile] = useState<JourneyLearningProfile | null>(null);
  const [dailyPlan, setDailyPlan] = useState<DailyPlan | null>(null);
  const [gamification, setGamification] = useState<JourneyGamification | null>(null);
  const [loading, setLoading] = useState(!previewCourses);
  const [error, setError] = useState('');
  const [offline, setOffline] = useState(false);
  const [lockedLesson, setLockedLesson] = useState<JourneyLesson | null>(null);
  const [chapterId, setChapterId] = useState<string | null>(null);
  const [showMap, setShowMap] = useState(false);
  const palette = useAppPalette();
  const reducedMotion = useReducedMotion();
  const load = useCallback(async () => {
    if (previewCourses || !userId) return;
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
  }, [previewCourses, userId, queryClient]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  const [showDetails, setShowDetails] = useState(false);
  const visibleCourses = courses.filter((course) => course.id !== legacyEverydayEnglishCourseId);
  const continuation = visibleCourses.flatMap((course) => course.continue_lesson ? [{ course, lesson: course.continue_lesson }] : []);
  const next = continuation.find(({ lesson }) => lesson.state === 'in_progress')
    ?? continuation.find(({ lesson }) => lesson.state === 'available');
  const stages = visibleCourses.flatMap((course) => (
    course.chapters?.length ? course.chapters : [{
      id: course.id, title: course.title, description: '', position: 1, units: course.units,
    }]
  ).map((chapter) => ({ course, chapter })));
  const activeStage = stages.find(({ chapter }) => chapter.id === chapterId)
    ?? stages.find(({ chapter }) => chapter.units.some(({ lessons }) => lessons.some(({ id }) => id === next?.lesson.id)))
    ?? stages[0];
  const stageIndex = activeStage ? stages.indexOf(activeStage) : -1;
  const requiredUnits = activeStage?.chapter.units.filter((unit) => unit.is_required !== false) ?? [];
  const completedUnits = requiredUnits.filter((unit) => unit.progress_percent === 100).length;
  const stageNext = next && activeStage?.chapter.units.some(
    (unit) => unit.lessons.some((lesson) => lesson.id === next.lesson.id),
  ) ? next.lesson : null;
  const { spacing, radius } = designTokens;
  return <Page eyebrow={previewCourses ? 'DESIGN PREVIEW · SAMPLE DATA' : 'JOURNEY'} title="Your learning path" compact>
    {offline ? <AppCard tone="reward"><AppText variant="label">Offline journey</AppText><AppText tone="muted">Showing the last downloaded map. Unlocks and XP update after synchronization.</AppText></AppCard> : null}
    {loading && courses.length === 0 ? <LoadingSkeleton lines={5} /> : error && courses.length === 0 ? <ErrorState message={error} retry={() => { void load(); }} /> : courses.length ? <>
      {activeStage ? <Animated.View key={activeStage.chapter.id}
        entering={reducedMotion ? undefined : FadeIn.duration(designTokens.motion.standard)}
        style={{ gap: spacing.lg }}>
        <View style={{ padding: spacing.xl, gap: spacing.sm, borderRadius: radius.xl, backgroundColor: palette.hero, overflow: 'hidden' }}>
          <NoirArtwork />
          <AppText variant="label" style={{ color: palette.heroAccent }}>
            {activeStage.course.title} · Stage {stageIndex + 1} / {stages.length}
          </AppText>
          <AppText variant="display" accessibilityRole="header" style={{ color: palette.heroOn, paddingRight: spacing.xxxl }}>{activeStage.chapter.title}</AppText>
          {activeStage.chapter.description ? <AppText style={{ color: palette.heroMuted }}>{activeStage.chapter.description}</AppText> : null}
          <AppText variant="caption" style={{ color: palette.heroOn }}>{completedUnits} / {requiredUnits.length} required units completed</AppText>
          <XPProgressBar value={completedUnits} max={requiredUnits.length} label="Chapter progress" showValue={false} />
          {stageNext ? <AppButton
            label={stageNext.state === 'in_progress' ? 'Continue lesson' : stageNext.kind === 'checkpoint' ? 'Start checkpoint' : 'Start lesson'}
            accessibilityHint={stageNext.title}
            onPress={() => router.push({ pathname: '/lesson/[id]', params: { id: stageNext.id } })}
          /> : null}
        </View>
        <AppButton label="Browse all chapters" variant="secondary" onPress={() => setShowMap(true)} />
        {activeStage.chapter.units.map((unit) => <AdventurePath key={unit.id} unit={unit} expanded currentLessonId={next?.lesson.id} onLocked={setLockedLesson} />)}
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm }}>
          {stageIndex > 0 ? <AppButton label="Previous chapter" variant="secondary" onPress={() => setChapterId(stages[stageIndex - 1].chapter.id)} /> : null}
          {stageIndex + 1 < stages.length ? <AppButton label="Next chapter" variant="secondary" onPress={() => setChapterId(stages[stageIndex + 1].chapter.id)} /> : null}
        </View>
      </Animated.View> : null}
      <AppButton label={showDetails ? 'Hide learning overview' : 'Show learning overview'} variant="secondary" onPress={() => setShowDetails((value) => !value)} />
      {showDetails ? <View style={{ gap: 12 }}>
    {gamification ? <AppCard tone="reward" style={{ gap: 7 }}><AppText variant="heading">{gamification.learning_streak.current_streak} day learning streak</AppText><AppText tone="muted">Best {gamification.learning_streak.longest_streak} days · {gamification.learning_streak.total_active_days} active days</AppText><AppText variant="caption">{gamification.quests.filter((quest) => quest.completed).length}/{gamification.quests.length} active quests completed</AppText></AppCard> : null}
      <AppCard tone="primary" style={{ gap: 7 }}><AppText variant="caption">YOUR LEARNING PATH</AppText><AppText variant="heading">{learningProfile?.selected_cefr ?? 'Choose a level'} · {learningProfile?.goal ?? 'General English'}</AppText><AppText tone="muted">Recommended placement: {learningProfile?.recommended_cefr ?? 'Not assessed'} · {learningProfile?.daily_minutes ?? 10} minutes/day</AppText><AppButton label="Edit learning goals" variant="secondary" onPress={() => router.push('/learning-preferences')} /></AppCard>
      <View style={{ gap: 9 }}><AppText variant="heading">Today&apos;s learning plan</AppText>{dailyPlan?.items.length ? dailyPlan.items.map((item) => <AppCard key={item.id} style={{ gap: 6 }}><AppText variant="label">{item.title}</AppText><AppText variant="caption" tone="muted">About {item.estimated_minutes} min · {item.completed_at ? 'Completed' : 'Ready'}</AppText>{item.lesson_id && !item.completed_at ? <AppButton label="Open activity" size="medium" variant="secondary" onPress={() => router.push(`/lesson/${item.lesson_id}` as Href)} /> : null}</AppCard>) : <AppText tone="muted">No eligible activities yet.</AppText>}</View>
      <View style={{ gap: 9 }}><AppText variant="heading">Recommended for you</AppText>{learningProfile?.recommendations.length ? learningProfile.recommendations.map((item) => <AppCard key={`${item.reason_code}-${item.lesson_id}`} style={{ gap: 6 }}><AppText variant="label">{item.title}</AppText><AppText tone="muted">{item.reason_vi}</AppText><AppButton label="Open lesson" size="medium" variant="secondary" onPress={() => router.push(item.destination as Href)} /></AppCard>) : <AppText tone="muted">Complete a few activities to improve recommendations.</AppText>}<AppText variant="caption" tone="muted">{learningProfile?.insight}</AppText></View>
      {summary ? <AppCard tone="primary" style={{ gap: 8 }}><AppText variant="heading">Level {summary.level} · {summary.xp_total} XP</AppText><XPProgressBar value={summary.xp_into_level} max={summary.xp_for_next_level} label="XP toward next level" /><AppText tone="muted">{summary.completed_lessons} / {summary.total_lessons} lessons complete · Replay to improve mastery.</AppText></AppCard> : null}
      </View> : null}
      <AppModal visible={showMap} title="Learning roadmap" onClose={() => setShowMap(false)}>
        {stages.map(({ course, chapter }, index) => <AppButton key={chapter.id}
          label={`${index + 1}. ${course.title} · ${chapter.title}`}
          variant={activeStage?.chapter.id === chapter.id ? 'primary' : 'secondary'}
          onPress={() => { setChapterId(chapter.id); setShowMap(false); }}
        />)}
      </AppModal>
    </> : <EmptyState title="No published lessons yet" message="Load the development seed data after applying migrations." />}
    <SyncStatus />
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
