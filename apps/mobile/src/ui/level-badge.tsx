import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from './app-text';

export type LevelBadgeProps = { level: number; title?: string };
export function LevelBadge({ level, title }: LevelBadgeProps) {
  const palette = useAppPalette();
  return <View accessible accessibilityLabel={`Level ${level}${title ? `, ${title}` : ''}`} style={{ alignSelf: 'flex-start', flexDirection: 'row', alignItems: 'center', gap: designTokens.spacing.sm, backgroundColor: palette.rewardSoft, borderRadius: designTokens.radius.pill, paddingHorizontal: designTokens.spacing.md, paddingVertical: designTokens.spacing.sm }}>
    <AppText variant="label" style={{ color: palette.dark ? palette.text : palette.rewardOn }}>★ {level}</AppText>
    {title && <AppText variant="caption" style={{ color: palette.text }}>{title}</AppText>}
  </View>;
}
