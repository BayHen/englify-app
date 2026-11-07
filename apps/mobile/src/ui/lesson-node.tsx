import { Pressable, View } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from './app-text';

export type LessonNodeProps = { title: string; order: number; status: 'locked' | 'available' | 'in_progress' | 'completed' | 'mastered'; onPress?: () => void };
export function LessonNode({ title, order, status, onPress }: LessonNodeProps) {
  const palette = useAppPalette();
  const locked = status === 'locked';
  const visualStatus = status === 'in_progress' ? 'available' : status === 'mastered' ? 'completed' : status;
  return <Pressable accessibilityRole="button" accessibilityLabel={`Lesson ${order}, ${title}, ${status}`} accessibilityState={{ disabled: locked }} disabled={locked || !onPress} onPress={onPress} style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: designTokens.spacing.lg, opacity: locked ? 0.55 : pressed ? 0.78 : 1, minHeight: 68 })}>
    <View style={{ width: 58, height: 58, borderRadius: designTokens.radius.pill, alignItems: 'center', justifyContent: 'center', backgroundColor: visualStatus === 'completed' ? palette.success : visualStatus === 'available' ? palette.primary : palette.border, ...designTokens.shadow.soft }}>
      <AppText variant="heading" style={{ color: visualStatus === 'locked' ? palette.muted : palette.primaryOn }}>{visualStatus === 'completed' ? '✓' : visualStatus === 'locked' ? '·' : order}</AppText>
    </View>
    <View style={{ flex: 1 }}><AppText variant="label">{title}</AppText><AppText variant="caption" tone="muted">{status === 'in_progress' ? 'In progress' : status === 'mastered' ? 'Mastered · replay available' : status === 'completed' ? 'Completed · replay available' : status === 'available' ? 'Ready to play' : 'Locked'}</AppText></View>
  </Pressable>;
}
