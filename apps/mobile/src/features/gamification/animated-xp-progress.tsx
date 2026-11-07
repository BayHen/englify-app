import { useEffect, useState } from 'react';
import { Animated, View } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from '@/ui';
import { progressRatio } from '@/ui/xp-progress-bar';
import { useReducedMotion } from '@/ui/use-reduced-motion';

export function AnimatedXPProgress({ value, max }: { value: number; max: number }) {
  const palette = useAppPalette();
  const reduced = useReducedMotion();
  const [progress] = useState(() => new Animated.Value(0));
  const ratio = progressRatio(value, max);
  useEffect(() => {
    if (reduced) { progress.setValue(ratio); return; }
    const animation = Animated.timing(progress, { toValue: ratio, duration: 650, useNativeDriver: false });
    animation.start();
    return () => animation.stop();
  }, [progress, ratio, reduced]);
  return <View style={{ gap: designTokens.spacing.sm }}>
    <AppText variant="label">{value} / {max} XP to next level</AppText>
    <View accessibilityRole="progressbar" accessibilityLabel="XP to next level" accessibilityValue={{ min: 0, max: Math.max(1, max), now: Math.min(value, max) }} style={{ height: 12, borderRadius: designTokens.radius.pill, backgroundColor: palette.primarySoft, overflow: 'hidden' }}>
      <Animated.View style={{ width: progress.interpolate({ inputRange: [0, 1], outputRange: ['0%', '100%'] }), height: '100%', borderRadius: designTokens.radius.pill, backgroundColor: palette.reward }} />
    </View>
  </View>;
}
