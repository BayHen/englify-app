import type { ReactNode } from 'react';
import { Pressable, View, type StyleProp, type ViewStyle } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';

export type AppCardProps = {
  children: ReactNode;
  tone?: 'surface' | 'primary' | 'reward';
  onPress?: () => void;
  accessibilityLabel?: string;
  style?: StyleProp<ViewStyle>;
};

export function AppCard({ children, tone = 'surface', onPress, accessibilityLabel, style }: AppCardProps) {
  const palette = useAppPalette();
  const backgroundColor = tone === 'primary' ? palette.primarySoft : tone === 'reward' ? palette.rewardSoft : palette.surface;
  const cardStyle: StyleProp<ViewStyle> = [{ padding: designTokens.spacing.xl, borderRadius: designTokens.radius.xl, backgroundColor, borderWidth: 1, borderColor: palette.border, ...designTokens.shadow.soft }, style];
  if (onPress) return <Pressable accessibilityRole="button" accessibilityLabel={accessibilityLabel} onPress={onPress} style={({ pressed }) => [cardStyle, { opacity: pressed ? 0.84 : 1 }]}>{children}</Pressable>;
  return <View style={cardStyle}>{children}</View>;
}
