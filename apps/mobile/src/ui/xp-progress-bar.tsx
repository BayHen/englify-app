import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from './app-text';

export function progressRatio(value: number, max: number): number {
  if (!Number.isFinite(value) || !Number.isFinite(max) || max <= 0) return 0;
  return Math.max(0, Math.min(1, value / max));
}

export type XPProgressBarProps = { value: number; max: number; label?: string; showValue?: boolean };
export function XPProgressBar({ value, max, label = 'XP progress', showValue = true }: XPProgressBarProps) {
  const palette = useAppPalette();
  const ratio = progressRatio(value, max);
  const safeMax = Math.max(0, Number.isFinite(max) ? max : 0);
  const safeValue = Math.round(ratio * safeMax);
  return <View style={{ gap: designTokens.spacing.sm }}>
    {showValue && <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}><AppText variant="label">{label}</AppText><AppText variant="label" tone="primary">{safeValue} / {safeMax} XP</AppText></View>}
    <View accessibilityRole="progressbar" accessibilityLabel={label} accessibilityValue={{ min: 0, max: safeMax || 1, now: safeValue }} style={{ height: 12, borderRadius: designTokens.radius.pill, backgroundColor: palette.primarySoft, overflow: 'hidden' }}>
      <View style={{ width: `${ratio * 100}%`, height: '100%', borderRadius: designTokens.radius.pill, backgroundColor: palette.primary }} />
    </View>
  </View>;
}
