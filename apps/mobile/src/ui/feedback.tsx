import { useEffect, useState } from 'react';
import { Animated, View } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppButton } from './app-button';
import { AppCard } from './app-card';
import { AppText } from './app-text';
import { useReducedMotion } from './use-reduced-motion';

export type EmptyStateProps = { title?: string; message?: string; actionLabel?: string; onAction?: () => void };
export function EmptyState({ title = 'Nothing here yet', message = 'Your next adventure will appear here.', actionLabel, onAction }: EmptyStateProps) {
  return <AppCard style={{ alignItems: 'center', gap: designTokens.spacing.sm }}>
    <AppText variant="heading">{title}</AppText>
    <AppText tone="muted" style={{ textAlign: 'center' }}>{message}</AppText>
    {!!actionLabel && onAction && <AppButton label={actionLabel} onPress={onAction} variant="secondary" style={{ marginTop: designTokens.spacing.md }} />}
  </AppCard>;
}

export type ErrorStateProps = { title?: string; message?: string; retry?: () => void };
export function ErrorState({ title = 'Something went wrong', message = 'We couldn’t load this right now.', retry }: ErrorStateProps) {
  return <AppCard style={{ gap: designTokens.spacing.sm }}>
    <AppText variant="heading" tone="error" accessibilityRole="alert">{title}</AppText>
    <AppText tone="muted">{message}</AppText>
    {retry && <AppButton label="Try again" onPress={retry} style={{ marginTop: designTokens.spacing.md }} />}
  </AppCard>;
}

export type LoadingSkeletonProps = { lines?: number; height?: number; accessibilityLabel?: string };
export function LoadingSkeleton({ lines = 3, height = 16, accessibilityLabel = 'Loading content' }: LoadingSkeletonProps) {
  const palette = useAppPalette();
  const reduced = useReducedMotion();
  const [opacity] = useState(() => new Animated.Value(1));

  useEffect(() => {
    if (reduced) { opacity.setValue(1); return; }
    const animation = Animated.loop(Animated.sequence([
      Animated.timing(opacity, { toValue: 0.45, duration: designTokens.motion.relaxed, useNativeDriver: true }),
      Animated.timing(opacity, { toValue: 1, duration: designTokens.motion.relaxed, useNativeDriver: true }),
    ]));
    animation.start();
    return () => animation.stop();
  }, [opacity, reduced]);

  return <View accessible accessibilityLabel={accessibilityLabel} accessibilityState={{ busy: true }} style={{ gap: designTokens.spacing.md, paddingVertical: designTokens.spacing.md }}>
    {Array.from({ length: Math.max(1, Math.min(lines, 8)) }, (_, index) => <Animated.View key={index} style={{ height, width: index === lines - 1 ? '65%' : '100%', borderRadius: designTokens.radius.sm, backgroundColor: palette.skeleton, opacity }} />)}
  </View>;
}
