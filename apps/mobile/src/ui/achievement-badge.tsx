import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from './app-text';

export type AchievementBadgeProps = { title: string; description?: string; unlocked: boolean };
export function AchievementBadge({ title, description, unlocked }: AchievementBadgeProps) {
  const palette = useAppPalette();
  return <View accessible accessibilityLabel={`${title}, ${unlocked ? 'unlocked' : 'locked'}${description ? `, ${description}` : ''}`} style={{ width: 112, alignItems: 'center', gap: designTokens.spacing.sm, opacity: unlocked ? 1 : 0.5 }}>
    <View style={{ width: 72, height: 72, borderRadius: designTokens.radius.xl, backgroundColor: unlocked ? palette.rewardSoft : palette.border, borderColor: unlocked ? palette.reward : palette.border, borderWidth: 2, justifyContent: 'center', alignItems: 'center' }}><AppText variant="title" style={{ color: unlocked ? (palette.dark ? palette.text : palette.rewardOn) : palette.muted }}>{unlocked ? '★' : '·'}</AppText></View>
    <AppText variant="label" style={{ textAlign: 'center' }}>{title}</AppText>
    {description && <AppText variant="caption" tone="muted" style={{ textAlign: 'center' }}>{description}</AppText>}
  </View>;
}
