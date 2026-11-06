import { Pressable, View } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from './app-text';

export type LessonNodeProps = { title: string; order: number; status: 'locked' | 'available' | 'completed'; onPress?: () => void };
export function LessonNode({ title, order, status, onPress }: LessonNodeProps) {
  const palette = useAppPalette();
  const locked = status === 'locked';
  return <Pressable accessibilityRole="button" accessibilityLabel={`Lesson ${order}, ${title}, ${status}`} accessibilityState={{ disabled: locked }} disabled={locked || !onPress} onPress={onPress} style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: designTokens.spacing.lg, opacity: locked ? 0.55 : pressed ? 0.78 : 1, minHeight: 68 })}>
    <View style={{ width: 58, height: 58, borderRadius: designTokens.radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: status === 'completed' ? palette.success : status === 'available' ? palette.primary : palette.border, ...designTokens.shadow.soft }}>
      <AppText variant="heading" style={{ color: status === 'locked' ? palette.muted : palette.primaryOn }}>{status === 'completed' ? '✓' : status === 'locked' ? '·' : order}</AppText>
    </View>
    <View style={{ flex: 1 }}><AppText variant="label">{title}</AppText><AppText variant="caption" tone="muted">{status === 'available' ? 'Ready to play' : status === 'completed' ? 'Completed' : 'Locked'}</AppText></View>
  </Pressable>;
}
