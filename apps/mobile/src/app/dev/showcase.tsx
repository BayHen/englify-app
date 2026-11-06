import { Redirect } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { Page } from '@/components/page';
import { useAppPalette } from '@/constants/app-theme';
import { useAppStore, type ThemeMode } from '@/state/app-store';
import { AchievementBadge, AppBottomSheet, AppButton, AppCard, AppInput, AppModal, AppText, EmptyState, ErrorState, LessonNode, LevelBadge, LoadingSkeleton, QuestCard, RewardCard, XPProgressBar } from '@/ui';

function ShowcaseContent() {
  const palette = useAppPalette();
  const themeMode = useAppStore((state) => state.themeMode);
  const setThemeMode = useAppStore((state) => state.setThemeMode);
  const [input, setInput] = useState('');
  const [modalOpen, setModalOpen] = useState(false);
  const [sheetOpen, setSheetOpen] = useState(false);

  return <Page eyebrow="DEVELOPMENT ONLY" title="Quest design system" description="A living preview of components, states, and themes. Sample values below are illustrative only.">
    <AppText variant="heading">Color & type</AppText>
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: designTokens.spacing.sm }}>
      {[palette.primary, palette.reward, palette.success, palette.error, palette.surface].map((color) => <View key={color} accessibilityLabel={`Color ${color}`} style={{ width: 54, height: 54, borderRadius: designTokens.radius.lg, backgroundColor: color, borderColor: palette.border, borderWidth: 1 }} />)}
    </View>
    <AppText variant="display">Learn with joy.</AppText>
    <AppText tone="muted">Every small step adds up. This body text scales with device settings.</AppText>

    <AppText variant="heading" style={{ marginTop: designTokens.spacing.lg }}>Appearance</AppText>
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: designTokens.spacing.sm }}>
      {(['system', 'light', 'dark'] as ThemeMode[]).map((mode) => <AppButton key={mode} label={mode} variant={themeMode === mode ? 'primary' : 'secondary'} onPress={() => setThemeMode(mode)} />)}
    </View>

    <AppText variant="heading" style={{ marginTop: designTokens.spacing.lg }}>Actions & input</AppText>
    <AppButton label="Start learning" size="large" onPress={() => setModalOpen(true)} />
    <AppButton label="Claim reward preview" variant="reward" onPress={() => setSheetOpen(true)} />
    <AppButton label="Secondary action" variant="secondary" onPress={() => setModalOpen(true)} />
    <AppButton label="Loading action" loading onPress={() => {}} />
    <AppInput label="Practice phrase" placeholder="Type a phrase" value={input} onChangeText={setInput} hint="Example input; not saved" />
    <AppInput label="Input with feedback" placeholder="Try again" error="Please enter a phrase." />

    <AppText variant="heading" style={{ marginTop: designTokens.spacing.lg }}>Progress & rewards</AppText>
    <LevelBadge level={4} title="Word explorer" />
    <XPProgressBar value={120} max={200} label="Sample level XP" />
    <QuestCard title="Daily practice" description="Complete a short learning session" rewardXp={30} progress={2} target={3} onPress={() => setSheetOpen(true)} />
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: designTokens.spacing.md }}>
      <View style={{ flexGrow: 1, flexBasis: 150 }}><RewardCard title="New avatar" description="A sample reward" costXp={150} onPress={() => setSheetOpen(true)} /></View>
      <View style={{ flexGrow: 1, flexBasis: 150 }}><RewardCard title="Theme pack" description="Already claimed sample" costXp={200} claimed /></View>
    </View>

    <AppText variant="heading" style={{ marginTop: designTokens.spacing.lg }}>Journey & achievements</AppText>
    <AppCard><LessonNode title="First hello" order={1} status="completed" onPress={() => setModalOpen(true)} /><LessonNode title="At the café" order={2} status="available" onPress={() => setModalOpen(true)} /><LessonNode title="Around town" order={3} status="locked" /></AppCard>
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: designTokens.spacing.lg }}><AchievementBadge title="First step" description="Sample badge" unlocked /><AchievementBadge title="On a roll" description="Sample badge" unlocked={false} /></View>

    <AppText variant="heading" style={{ marginTop: designTokens.spacing.lg }}>Feedback states</AppText>
    <EmptyState title="No quests yet" message="New quests will appear here." actionLabel="Explore" onAction={() => setSheetOpen(true)} />
    <ErrorState title="Connection lost" message="Check your connection and try again." retry={() => setModalOpen(true)} />
    <AppCard><LoadingSkeleton lines={3} /></AppCard>

    <AppModal visible={modalOpen} title="A friendly moment" onClose={() => setModalOpen(false)}><AppText>This dialog uses the shared color and type system.</AppText></AppModal>
    <AppBottomSheet visible={sheetOpen} title="Reward preview" onClose={() => setSheetOpen(false)}><AppText>Rewards are shown here as examples. No XP is spent.</AppText></AppBottomSheet>
  </Page>;
}

export default function Showcase() {
  if (!__DEV__) return <Redirect href="/home" />;
  return <ShowcaseContent />;
}
