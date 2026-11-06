import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppCard } from './app-card';
import { AppText } from './app-text';
import { XPProgressBar } from './xp-progress-bar';

export type QuestCardProps = {
  title: string;
  description: string;
  rewardXp: number;
  progress: number;
  target: number;
  onPress?: () => void;
};

export function QuestCard({ title, description, rewardXp, progress, target, onPress }: QuestCardProps) {
  const palette = useAppPalette();
  const complete = progress >= target && target > 0;
  return <AppCard onPress={onPress} accessibilityLabel={`${title}, ${complete ? 'complete' : `${progress} of ${target}`}, reward ${rewardXp} XP`} style={{ gap: designTokens.spacing.md }}>
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', gap: designTokens.spacing.sm }}>
      <View style={{ flex: 1 }}><AppText variant="heading">{title}</AppText><AppText tone="muted">{description}</AppText></View>
      <View style={{ borderRadius: designTokens.radius.pill, backgroundColor: palette.rewardSoft, paddingHorizontal: designTokens.spacing.md, paddingVertical: designTokens.spacing.xs }}><AppText variant="label" style={{ color: palette.dark ? palette.text : palette.rewardOn }}>+{rewardXp} XP</AppText></View>
    </View>
    <XPProgressBar value={progress} max={target} label={complete ? 'Quest complete' : 'Quest progress'} showValue={false} />
    <AppText variant="caption" tone={complete ? 'success' : 'muted'}>{complete ? 'Completed' : `${progress} of ${target} steps`}</AppText>
  </AppCard>;
}
