import { useCallback, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { readJourneyMap, refreshJourneyMap } from '@/features/learning/journey-map-cache';
import { router, useFocusEffect, type Href } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, View, useWindowDimensions } from 'react-native';
import { Page } from '@/components/page';
import { FoxMascot } from '@/components/fox-mascot';
import { useAuth } from '@/auth/provider';
import { useAppPalette } from '@/constants/app-theme';
import { AppButton, AppText, ErrorState, LoadingSkeleton } from '@/ui';
import { getGamification, type GamificationOverview, type QuestProgress } from '@/features/gamification/api';
import type { JourneyCourse } from '@/features/learning/api';
import { getCachedJourney } from '@/features/offline/storage';
import { nextLesson } from './next-lesson';
import { AnimatedXPProgress } from '@/features/gamification/animated-xp-progress';
import { ProfileAvatar } from '@/features/profile/profile-avatar';

const tools = [
  { title: 'Dictionary', detail: 'Find a word', href: '/dictionary', icon: { ios: 'text.book.closed.fill', android: 'menu_book', web: 'menu_book' }, tint: 'primary' },
  { title: 'Vocabulary review', detail: 'Review due words', href: '/vocabulary-review', icon: { ios: 'rectangle.on.rectangle.angled', android: 'style', web: 'style' }, tint: 'reward' },
  { title: 'Translation', detail: 'Phrase helper', href: '/translation', icon: { ios: 'arrow.left.arrow.right', android: 'translate', web: 'translate' }, tint: 'reward' },
  { title: 'Real English', detail: 'Talk naturally', href: '/real-english', icon: { ios: 'bubble.left.and.bubble.right.fill', android: 'forum', web: 'forum' }, tint: 'success' },
  { title: 'Speaking', detail: 'Find your voice', href: '/speaking', icon: { ios: 'mic.fill', android: 'mic', web: 'mic' }, tint: 'primary' },
  { title: 'Writing', detail: 'Shape a story', href: '/writing', icon: { ios: 'pencil.line', android: 'edit', web: 'edit' }, tint: 'reward' },
  { title: 'Quiz Arena', detail: 'Test yourself', href: '/quiz-arena', icon: { ios: 'sparkles', android: 'quiz', web: 'quiz' }, tint: 'success' },
] as const;

function heading(title: string, action?: string, href?: Href) {
  return <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}><AppText variant="heading" accessibilityRole="header">{title}</AppText>{action && href ? <Pressable accessibilityRole="link" onPress={() => router.push(href)}><AppText variant="label" tone="primary">{action}  →</AppText></Pressable> : null}</View>;
}

function QuestLine({ quest, index }: { quest: QuestProgress; index: number }) {
  const palette = useAppPalette();
  const icons = [
    { ios: 'book.fill', android: 'menu_book', web: 'menu_book' },
    { ios: 'checkmark.circle.fill', android: 'quiz', web: 'quiz' },
    { ios: 'mic.fill', android: 'mic', web: 'mic' },
    { ios: 'arrow.clockwise', android: 'refresh', web: 'refresh' },
  ] as const;
  return <Pressable accessibilityRole="button" accessibilityLabel={`${quest.title}, ${quest.progress} of ${quest.target}, ${quest.completed ? 'complete' : 'in progress'}`} onPress={() => router.push('/journey')} style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 10, opacity: pressed ? 0.72 : 1 })}>
    <View style={{ width: 42, height: 42, borderRadius: 15, alignItems: 'center', justifyContent: 'center', backgroundColor: quest.completed ? palette.rewardSoft : palette.primarySoft }}><SymbolView name={quest.completed ? { ios: 'checkmark.seal.fill', android: 'task_alt', web: 'task_alt' } : icons[index % icons.length]} size={21} tintColor={quest.completed ? palette.rewardOn : palette.primary} /></View>
    <View style={{ flex: 1, gap: 4 }}><AppText variant="label">{quest.title}</AppText><View style={{ height: 6, borderRadius: 3, backgroundColor: palette.primarySoft, overflow: 'hidden' }}><View style={{ width: `${Math.min(100, quest.target > 0 ? quest.progress / quest.target * 100 : 0)}%`, height: 6, backgroundColor: quest.completed ? palette.success : palette.primary }} /></View><AppText variant="caption" tone="muted">{quest.completed ? 'Completed' : `${quest.progress} / ${quest.target}`} · +{quest.reward_xp} XP</AppText></View>
  </Pressable>;
}

export function HomeScreen({ preview }: { preview?: { overview: GamificationOverview; courses: JourneyCourse[] } }) {
  const { profile } = useAuth();
  const userId = profile?.id;
  const queryClient = useQueryClient();
  const palette = useAppPalette();
  const { width } = useWindowDimensions();
  const [overview, setOverview] = useState<GamificationOverview | null>(preview?.overview ?? null);
  const [courses, setCourses] = useState<JourneyCourse[]>(() => preview?.courses ?? readJourneyMap(queryClient, userId) ?? []);
  const [loading, setLoading] = useState(!preview);
  const [error, setError] = useState('');
  const [offline, setOffline] = useState(false);
  const load = useCallback(async () => {
    if (preview || !userId) return;
    let received = false;
    void getCachedJourney(userId).then((cached) => {
      if (!received && cached && !readJourneyMap(queryClient, userId)) {
        setCourses((current) => current.length ? current : cached.courses);
      }
    }).catch(() => undefined);
    setLoading(true); setError('');
    const [stats, journey] = await Promise.allSettled([
      getGamification().then(setOverview),
      refreshJourneyMap(queryClient, userId).then((data) => {
        received = true;
        setCourses(data);
        setOffline(false);
      }),
    ]);
    if (journey.status === 'rejected' && userId) {
      const cached = await getCachedJourney(userId).catch(() => null);
      if (cached) setCourses((current) => current.length ? current : cached.courses);
      setOffline(true);
    }
    if (stats.status === 'rejected' && journey.status === 'rejected') setError('Learning data is unavailable. Check your connection and try again.');
    setLoading(false);
  }, [userId, queryClient, preview]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  const next = nextLesson(courses);
  const daily = overview?.quests.filter((quest) => quest.period === 'daily') ?? [];
  const unlocked = overview?.badges.filter((badge) => badge.unlocked).slice(0, 3) ?? [];
  const given = profile?.display_name?.trim().split(/\s+/)[0] || 'Explorer';
  const compact = width < 370;
  const headerAccessory = <Pressable accessibilityRole="button" accessibilityLabel="Open profile and appearance settings" onPress={() => router.push('/profile')} style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 8, opacity: pressed ? 0.7 : 1 })}><ProfileAvatar name={given} path={profile?.avatar_url} size={36} /><SymbolView name={{ ios: 'gearshape.fill', android: 'settings', web: 'settings' }} size={20} tintColor={palette.muted} /></Pressable>;
  return <Page eyebrow="HOME" title={`Hi, ${given}!`} description={next ? 'Your next lesson is ready below.' : 'Choose an activity to practise English.'} compact headerAccessory={headerAccessory}>
    {preview ? <View style={{ backgroundColor: palette.rewardSoft, padding: 8, borderRadius: 12 }}><AppText variant="caption">DESIGN PREVIEW · SAMPLE DATA · No progress is saved</AppText></View> : null}
    {loading && !overview && courses.length === 0 ? <LoadingSkeleton lines={6} /> : error && !overview && !courses.length ? <ErrorState message={error} retry={() => { void load(); }} /> : <>
      <View style={{ borderRadius: 30, backgroundColor: palette.hero, padding: 20, overflow: 'hidden', gap: 14 }}>
        <View style={{ position: 'absolute', right: -32, top: -55, width: 175, height: 175, borderRadius: 90, backgroundColor: 'rgba(255,255,255,0.12)' }} />
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 5 }}><View style={{ flex: 1, gap: 6 }}><AppText variant="caption" style={{ color: palette.heroAccent, fontWeight: '800', letterSpacing: 1 }}>YOUR ADVENTURE</AppText><AppText variant={compact ? 'heading' : 'title'} style={{ color: palette.heroOn }}>{next?.lesson.title ?? 'Your journey starts here'}</AppText><AppText style={{ color: palette.heroMuted }}>{next?.course.title ?? 'Choose a lesson to begin.'}</AppText></View><FoxMascot size={compact ? 86 : 108} /></View>
        {overview ? <View style={{ gap: 7 }}><AppText variant="label" style={{ color: palette.heroOn }}>Level {overview.level} · {overview.total_xp} XP</AppText><AnimatedXPProgress value={overview.xp_into_level} max={overview.xp_for_next_level} hero /></View> : <AppText variant="caption" style={{ color: palette.heroMuted }}>XP appears when the learning service is available.</AppText>}
        <AppButton label={next ? 'Continue learning' : 'Open journey'} variant="reward" onPress={() => router.push(next ? `/lesson/${next.lesson.id}` as Href : '/journey')} />
      </View>
      {offline ? <AppText variant="caption" tone="muted">Offline map · progress refreshes after synchronization.</AppText> : null}
      <View style={{ gap: 10 }}>{heading('Daily quests', 'All rewards', '/rewards')}{daily.length ? <View style={{ backgroundColor: palette.surface, borderRadius: 22, paddingHorizontal: 16, paddingVertical: 6 }}>{daily.slice(0, 4).map((quest, index) => <QuestLine key={quest.id} quest={quest} index={index} />)}</View> : <AppText tone="muted">{overview ? 'No daily quests available yet.' : 'Connect to see your quests.'}</AppText>}</View>
      <View style={{ gap: 10 }}>
        {heading('Explore your way', 'See all', '/explore')}
        <View style={{ borderRadius: 20, overflow: 'hidden', backgroundColor: palette.surface }}>
          {tools.map((tool, index) => <Pressable key={tool.href} accessibilityRole="button"
            onPress={() => router.push(tool.href as Href)}
            style={({ pressed }) => ({
              minHeight: 56, flexDirection: 'row', alignItems: 'center', gap: 12, padding: 12,
              borderTopWidth: index ? 1 : 0, borderColor: palette.border,
              backgroundColor: pressed ? palette.primarySoft : palette.surface,
            })}>
            <SymbolView name={tool.icon} size={24} tintColor={tool.tint === 'success' ? palette.success : palette.primary} />
            <View style={{ flex: 1 }}>
              <AppText variant="label">{tool.title}</AppText>
              <AppText variant="caption" tone="muted">{tool.detail}</AppText>
            </View>
            <AppText tone="primary">›</AppText>
          </Pressable>)}
        </View>
      </View>
      <View style={{ gap: 10 }}>{heading('Milestones', 'See badges', '/rewards')}{unlocked.length ? <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{unlocked.map((badge) => <View key={badge.id} style={{ flexDirection: 'row', alignItems: 'center', gap: 8, borderRadius: 18, backgroundColor: palette.primarySoft, padding: 10 }}><SymbolView name={{ ios: 'seal.fill', android: 'verified', web: 'verified' }} size={20} tintColor={palette.primary} /><AppText variant="caption">{badge.title}</AppText></View>)}</View> : <AppText tone="muted">Your first badge is waiting on the path.</AppText>}</View>
    </>}
  </Page>;
}
