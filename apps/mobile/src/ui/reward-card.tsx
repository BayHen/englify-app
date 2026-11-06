import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppCard } from './app-card';
import { AppText } from './app-text';

export type RewardCardProps = { title: string; description: string; costXp: number; claimed?: boolean; onPress?: () => void };
export function RewardCard({ title, description, costXp, claimed = false, onPress }: RewardCardProps) {
  const palette = useAppPalette();
  return <AppCard tone="reward" onPress={onPress} accessibilityLabel={`${title}, ${claimed ? 'claimed' : `${costXp} XP`}`} style={{ minHeight: 144, justifyContent: 'space-between', gap: designTokens.spacing.md }}>
    <View><AppText variant="heading">{title}</AppText><AppText tone="muted">{description}</AppText></View>
    <AppText variant="label" style={{ color: palette.dark ? palette.text : palette.rewardOn }}>{claimed ? 'Claimed' : `${costXp} XP`}</AppText>
  </AppCard>;
}
