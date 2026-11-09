import { useCallback, useState } from 'react';
import { router, useFocusEffect, type Href } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, View, useWindowDimensions } from 'react-native';
import { Page } from '@/components/page';
import { FoxMascot } from '@/components/fox-mascot';
import { useAuth } from '@/auth/provider';
import { useAppPalette } from '@/constants/app-theme';
import { AppButton, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { getGamification, type GamificationOverview, type QuestProgress } from '@/features/gamification/api';
import { getJourney, type JourneyCourse } from '@/features/learning/api';
import { getCachedJourney } from '@/features/offline/storage';
import { nextLesson } from './next-lesson';
import { AnimatedXPProgress } from '@/features/gamification/animated-xp-progress';

const tools = [
  { title: 'Dictionary', detail: 'Find a word', href: '/dictionary', icon: { ios: 'text.book.closed.fill', android: 'menu_book', web: 'menu_book' }, tint: 'primary' },
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
  const palette = useAppPalette();
  const { width } = useWindowDimensions();
  const [overview, setOverview] = useState<GamificationOverview | null>(preview?.overview ?? null);
  const [courses, setCourses] = useState<JourneyCourse[]>(preview?.courses ?? []);
  const [loading, setLoading] = useState(!preview);
  const [error, setError] = useState('');
  const [offline, setOffline] = useState(false);
  const load = useCallback(async () => {
    if (preview) return;
    setLoading(true); setError(''); setOverview(null); setCourses([]);
    const [stats, journey] = await Promise.allSettled([getGamification(), getJourney()]);
    if (stats.status === 'fulfilled') setOverview(stats.value);
    if (journey.status === 'fulfilled') { setCourses(journey.value); setOffline(false); }
    else if (userId) { const cached = await getCachedJourney(userId); if (cached) { setCourses(cached.courses); setOffline(true); } }
    if (stats.status === 'rejected' && journey.status === 'rejected') setError('Learning data is unavailable. Check your connection and try again.');
    setLoading(false);
  }, [userId, preview]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  const next = nextLesson(courses);
  const daily = overview?.quests.filter((quest) => quest.period === 'daily') ?? [];
  const unlocked = overview?.badges.filter((badge) => badge.unlocked).slice(0, 3) ?? [];
  const given = profile?.display_name?.trim().split(/\s+/)[0] || 'Explorer';
  const compact = width < 370;
  const headerAccessory = <Pressable accessibilityRole="button" accessibilityLabel="Open profile and appearance settings" onPress={() => router.push('/profile')} style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 8, opacity: pressed ? 0.7 : 1 })}><View style={{ width: 36, height: 36, borderRadius: 18, backgroundColor: palette.rewardSoft, alignItems: 'center', justifyContent: 'center' }}><AppText variant="label">{given.slice(0, 1).toUpperCase()}</AppText></View><SymbolView name={{ ios: 'gearshape.fill', android: 'settings', web: 'settings' }} size={20} tintColor={palette.muted} /></Pressable>;
  return <Page eyebrow="A NEW DAY TO GROW" title={`Hi, ${given}!`} description="A little English every day goes a long way." compact headerAccessory={headerAccessory}>
    {preview ? <View style={{ backgroundColor: palette.rewardSoft, padding: 8, borderRadius: 12 }}><AppText variant="caption">DESIGN PREVIEW · SAMPLE DATA · No progress is saved</AppText></View> : null}
    {loading ? <LoadingSkeleton lines={6} /> : error && !overview && !courses.length ? <ErrorState message={error} retry={() => { void load(); }} /> : <>
      <View style={{ borderRadius: 30, backgroundColor: palette.hero, padding: 20, overflow: 'hidden', gap: 14 }}>
        <View style={{ position: 'absolute', right: -32, top: -55, width: 175, height: 175, borderRadius: 90, backgroundColor: 'rgba(255,255,255,0.12)' }} />
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 5 }}><View style={{ flex: 1, gap: 6 }}><AppText variant="caption" style={{ color: palette.heroAccent, fontWeight: '800', letterSpacing: 1 }}>YOUR ADVENTURE</AppText><AppText variant={compact ? 'heading' : 'title'} style={{ color: palette.heroOn }}>{next ? 'Ready for your next step?' : 'Your journey starts here'}</AppText><AppText style={{ color: palette.heroMuted }}>{next?.lesson.title ?? 'Choose a lesson to begin.'}</AppText></View><FoxMascot size={compact ? 86 : 108} /></View>
        {overview ? <View style={{ gap: 7 }}><AppText variant="label" style={{ color: palette.heroOn }}>Level {overview.level} · {overview.total_xp} XP</AppText><AnimatedXPProgress value={overview.xp_into_level} max={overview.xp_for_next_level} hero /></View> : <AppText variant="caption" style={{ color: palette.heroMuted }}>XP appears when the learning service is available.</AppText>}
        <AppButton label={next ? 'Continue learning' : 'Open journey'} variant="reward" onPress={() => router.push(next ? `/lesson/${next.lesson.id}` as Href : '/journey')} />
      </View>
      {offline ? <AppText variant="caption" tone="muted">Offline map · progress refreshes after synchronization.</AppText> : null}
      <View style={{ gap: 10 }}>{heading('Daily quests', 'All rewards', '/rewards')}{daily.length ? <View style={{ backgroundColor: palette.surface, borderRadius: 22, paddingHorizontal: 16, paddingVertical: 6 }}>{daily.slice(0, 4).map((quest, index) => <QuestLine key={quest.id} quest={quest} index={index} />)}</View> : <AppText tone="muted">{overview ? 'No daily quests available yet.' : 'Connect to see your quests.'}</AppText>}</View>
      <View style={{ gap: 10 }}>{heading('Learning adventure', 'View map', '/journey')}{next ? <Pressable accessibilityRole="button" accessibilityLabel={`Continue ${next.lesson.title}`} onPress={() => router.push(`/lesson/${next.lesson.id}` as Href)} style={({ pressed }) => ({ backgroundColor: palette.rewardSoft, borderRadius: 24, padding: 18, flexDirection: 'row', alignItems: 'center', gap: 14, opacity: pressed ? 0.8 : 1 })}><View style={{ width: 58, height: 58, borderRadius: 19, backgroundColor: palette.reward, justifyContent: 'center', alignItems: 'center' }}><SymbolView name={{ ios: 'map.fill', android: 'map', web: 'map' }} size={30} tintColor={palette.rewardOn} /></View><View style={{ flex: 1, gap: 3 }}><AppText variant="caption" tone="muted">{next.course.title}</AppText><AppText variant="heading">{next.lesson.title}</AppText><AppText variant="caption" tone="muted">{next.lesson.state === 'in_progress' ? 'In progress' : 'Ready to begin'} →</AppText></View></Pressable> : <EmptyState title="Your path is waiting" message="Open Journey to see available lessons." actionLabel="Open journey" onAction={() => router.push('/journey')} />}</View>
      <View style={{ gap: 10 }}>{heading('Explore your way', 'See all', '/explore')}<View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 10 }}>{tools.map((tool) => <Pressable key={tool.href} accessibilityRole="button" accessibilityLabel={tool.title} onPress={() => router.push(tool.href)} style={({ pressed }) => ({ width: compact ? '48%' : '31%', flexGrow: 1, minHeight: 108, borderRadius: 20, backgroundColor: palette.surface, padding: 13, justifyContent: 'space-between', opacity: pressed ? 0.75 : 1 })}><SymbolView name={tool.icon} size={26} tintColor={tool.tint === 'reward' ? palette.rewardOn : tool.tint === 'success' ? palette.success : palette.primary} /><View><AppText variant="label">{tool.title}</AppText><AppText variant="caption" tone="muted">{tool.detail}</AppText></View></Pressable>)}</View></View>
      <View style={{ gap: 10 }}>{heading('Milestones', 'See badges', '/rewards')}{unlocked.length ? <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{unlocked.map((badge) => <View key={badge.id} style={{ flexDirection: 'row', alignItems: 'center', gap: 8, borderRadius: 18, backgroundColor: palette.primarySoft, padding: 10 }}><SymbolView name={{ ios: 'seal.fill', android: 'verified', web: 'verified' }} size={20} tintColor={palette.primary} /><AppText variant="caption">{badge.title}</AppText></View>)}</View> : <AppText tone="muted">Your first badge is waiting on the path.</AppText>}</View>
    </>}
  </Page>;
}
