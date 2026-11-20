import { router, type Href } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, ScrollView, View, useWindowDimensions } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import Animated, { FadeInDown } from 'react-native-reanimated';
import { Page } from '@/components/page';
import { QuestTabBar } from '@/components/quest-tab-bar';
import { useAppPalette } from '@/constants/app-theme';
import { AppButton, AppText } from '@/ui';
import { useReducedMotion } from '@/ui/use-reduced-motion';
import { designTokens } from '@englify/shared';

type Tool = { label: string; detail: string; href: Href; ios: string; android: string; color: 'primary' | 'reward' | 'success' };
const explore: Tool[] = [
  { label: 'Dictionary', detail: 'Search, save and revisit words', href: '/dictionary', ios: 'text.book.closed.fill', android: 'menu_book', color: 'primary' },
  { label: 'Translation', detail: 'Look up useful phrase pairs', href: '/translation', ios: 'arrow.left.arrow.right', android: 'translate', color: 'reward' },
  { label: 'Real English', detail: 'Idioms, slang and context', href: '/real-english', ios: 'bubble.left.and.bubble.right.fill', android: 'forum', color: 'success' },
];
const practice: Tool[] = [
  { label: 'Speaking', detail: 'Listen, record and replay', href: '/speaking', ios: 'mic.fill', android: 'mic', color: 'primary' },
  { label: 'Writing', detail: 'Practice sentences and paragraphs', href: '/writing', ios: 'pencil.line', android: 'edit', color: 'reward' },
  { label: 'Quiz Arena', detail: 'Challenge what you know', href: '/quiz-arena', ios: 'checkmark.circle.fill', android: 'quiz', color: 'success' },
];

function ToolRow({ tool }: { tool: Tool }) {
  const palette = useAppPalette();
  const fill = tool.color === 'primary' ? palette.primarySoft : tool.color === 'reward' ? palette.rewardSoft : palette.mintSoft;
  const tint = tool.color === 'primary' ? palette.primary : tool.color === 'reward' ? (palette.dark ? palette.reward : palette.rewardOn) : palette.success;
  return <Pressable accessibilityRole="button" accessibilityLabel={`Open ${tool.label}`} onPress={() => router.push(tool.href)} style={({ pressed }) => ({ minHeight: 86, flexDirection: 'row', alignItems: 'center', gap: 15, borderRadius: 21, padding: 13, backgroundColor: palette.surface, opacity: pressed ? 0.75 : 1 })}>
    <View style={{ width: 58, height: 58, borderRadius: 19, backgroundColor: fill, justifyContent: 'center', alignItems: 'center' }}><SymbolView name={{ ios: tool.ios as never, android: tool.android as never, web: tool.android as never }} size={27} tintColor={tint} /></View>
    <View style={{ flex: 1, gap: 3 }}><AppText variant="heading">{tool.label}</AppText><AppText variant="caption" tone="muted">{tool.detail}</AppText></View><AppText tone="primary">→</AppText>
  </Pressable>;
}

function DiscoveryCard({ tool, wide = false }: { tool: Tool; wide?: boolean }) {
  const palette = useAppPalette();
  const fill = tool.color === 'primary' ? palette.primarySoft : tool.color === 'reward' ? palette.rewardSoft : palette.mintSoft;
  const tint = tool.color === 'primary' ? palette.primary : tool.color === 'reward' ? (palette.dark ? palette.reward : palette.rewardOn) : palette.success;
  return <Pressable accessibilityRole="button" accessibilityLabel={`Open ${tool.label}. ${tool.detail}`} onPress={() => router.push(tool.href)} style={({ pressed }) => ({ flex: 1, minWidth: 0, minHeight: wide ? 126 : 174, padding: designTokens.spacing.lg, borderRadius: designTokens.radius.xl, backgroundColor: fill, borderWidth: 1, borderColor: palette.border, opacity: pressed ? 0.78 : 1, transform: [{ scale: pressed ? 0.985 : 1 }], flexDirection: wide ? 'row' : 'column', alignItems: wide ? 'center' : 'stretch', gap: designTokens.spacing.md })}>
    <View style={{ width: 48, height: 48, borderRadius: 16, backgroundColor: palette.surface, alignItems: 'center', justifyContent: 'center' }}><SymbolView name={{ ios: tool.ios as never, android: tool.android as never, web: tool.android as never }} size={25} tintColor={tint} /></View>
    <View style={{ flex: 1, gap: 4 }}><AppText variant="heading">{tool.label}</AppText><AppText variant="caption" tone="muted">{tool.detail}</AppText></View>
    <SymbolView name={{ ios: 'arrow.up.right', android: 'arrow_outward', web: 'arrow_outward' }} size={17} tintColor={tint} />
  </Pressable>;
}

export function ExploreScreen() {
  const palette = useAppPalette();
  const reducedMotion = useReducedMotion();
  const { width } = useWindowDimensions();
  const narrow = width < 350;
  return <SafeAreaView style={{ flex: 1, backgroundColor: palette.background }} edges={['top', 'bottom']}>
    <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={{ alignItems: 'center', paddingHorizontal: designTokens.spacing.lg, paddingBottom: designTokens.spacing.xl }}>
      <View style={{ width: '100%', maxWidth: 560, paddingTop: designTokens.spacing.md, gap: designTokens.spacing.xl }}>
        <View style={{ gap: designTokens.spacing.sm }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: designTokens.spacing.sm }}><SymbolView name={{ ios: 'safari.fill', android: 'explore', web: 'explore' }} size={18} tintColor={palette.primary} /><AppText variant="caption" tone="primary" style={{ letterSpacing: 1.6 }} weight="heavy">DISCOVER & LEARN</AppText></View>
          <AppText variant="title" accessibilityRole="header">Explore English</AppText>
          <AppText tone="muted" style={{ maxWidth: 330 }}>Discover words, expressions, and real-life English.</AppText>
        </View>
        <Animated.View entering={reducedMotion ? undefined : FadeInDown.duration(340)}>
          <Pressable accessibilityRole="button" accessibilityLabel="Open the Real English reading library" onPress={() => router.push('/real-english')} style={({ pressed }) => ({ minHeight: 154, borderRadius: 28, backgroundColor: palette.hero, padding: designTokens.spacing.lg, overflow: 'hidden', opacity: pressed ? 0.85 : 1, flexDirection: 'row', alignItems: 'center', gap: designTokens.spacing.md })}>
            <View style={{ flex: 1, gap: designTokens.spacing.sm }}><AppText variant="caption" style={{ color: palette.heroAccent, letterSpacing: 1.2 }} weight="heavy">REAL ENGLISH</AppText><AppText variant="heading" style={{ color: palette.heroOn }}>English in the wild</AppText><AppText variant="caption" style={{ color: palette.heroMuted }}>Read everyday conversations and discover what expressions mean in context.</AppText><AppText variant="label" style={{ color: palette.heroAccent }}>Browse the reading library  →</AppText></View>
            <View importantForAccessibility="no-hide-descendants" style={{ width: narrow ? 76 : 96, height: 104, justifyContent: 'center', alignItems: 'center' }}><View style={{ width: 78, height: 78, borderRadius: 39, backgroundColor: palette.reward, alignItems: 'center', justifyContent: 'center', transform: [{ rotate: '-13deg' }] }}><SymbolView name={{ ios: 'safari.fill', android: 'explore', web: 'explore' }} size={42} tintColor={palette.rewardOn} /></View><View style={{ position: 'absolute', top: 0, right: 0, width: 18, height: 18, borderRadius: 9, backgroundColor: palette.reward }} /></View>
          </Pressable>
        </Animated.View>
        <View style={{ gap: designTokens.spacing.md }}><View style={{ gap: 2 }}><AppText variant="heading" accessibilityRole="header">Choose your path</AppText><AppText variant="caption" tone="muted">Three ways to make English yours.</AppText></View>
          <View style={{ flexDirection: narrow ? 'column' : 'row', gap: designTokens.spacing.md }}><DiscoveryCard tool={{ ...explore[0], detail: 'Find meanings, examples & pronunciation.' }} /><DiscoveryCard tool={{ ...explore[1], detail: 'Understand words and phrases.' }} /></View>
          <AppButton label="Open learning Journey" variant="secondary" onPress={() => router.push('/journey')} />
        </View>
      </View>
    </ScrollView>
    <QuestTabBar />
  </SafeAreaView>;
}
export function PracticeScreen() {
  const palette = useAppPalette();
  const { spacing, radius } = designTokens;
  return <Page eyebrow="PRACTICE" title="Skill studio" description="Train your voice, your writing, or your quick recall." compact>
    <View style={{ gap: spacing.md, padding: spacing.xl, borderRadius: radius.xl, backgroundColor: palette.hero }}>
      <SymbolView name={{ ios: 'waveform', android: 'graphic_eq', web: 'graphic_eq' }} size={42} tintColor={palette.heroAccent} />
      <AppText variant="title" style={{ color: palette.heroOn }}>Speaking studio</AppText>
      <AppText style={{ color: palette.heroMuted }}>Listen to a model, record your voice, and compare the two.</AppText>
      <AppButton label="Open speaking studio" variant="reward" onPress={() => router.push('/speaking')} />
    </View>
    <AppText variant="heading" accessibilityRole="header">Write or challenge yourself</AppText>
    <View style={{ gap: spacing.sm }}>
      {practice.slice(1).map((tool) => <ToolRow key={tool.label} tool={tool} />)}
    </View>
    <AppButton label="View learning plan" variant="secondary" onPress={() => router.push('/learning-plan')} />
  </Page>;
}
