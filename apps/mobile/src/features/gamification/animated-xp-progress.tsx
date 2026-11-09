import { useEffect } from 'react';
import { View } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from '@/ui';
import { progressRatio } from '@/ui/xp-progress-bar';
import { useReducedMotion } from '@/ui/use-reduced-motion';

export function AnimatedXPProgress({ value, max, hero = false }: { value: number; max: number; hero?: boolean }) {
  const palette = useAppPalette();
  const reduced = useReducedMotion();
  const ratio = progressRatio(value, max);
  const progress = useSharedValue(ratio);
  useEffect(() => {
    progress.value = reduced ? ratio : withTiming(ratio, { duration: designTokens.motion.relaxed });
  }, [progress, ratio, reduced]);
  const fill = useAnimatedStyle(() => ({ width: `${progress.value * 100}%` }));
  return <View style={{ gap: designTokens.spacing.sm }}>
    {!hero ? <AppText variant="label">{value} / {max} XP to next level</AppText> : null}
    <View accessibilityRole="progressbar" accessibilityLabel="XP to next level" accessibilityValue={{ min: 0, max: Math.max(1, max), now: Math.min(value, max) }} style={{ height: 12, borderRadius: designTokens.radius.pill, backgroundColor: hero ? 'rgba(255,255,255,0.42)' : palette.primarySoft, overflow: 'hidden' }}>
      <Animated.View style={[fill, { height: '100%', borderRadius: designTokens.radius.pill, backgroundColor: palette.reward }]} />
    </View>
  </View>;
}
