import { designTokens } from '@englify/shared';
import { router } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, View } from 'react-native';
import { useAppPalette } from '@/constants/app-theme';
import { AppText, XPProgressBar } from '@/ui';
import type { JourneyLesson, JourneyUnit } from './api';

const { spacing, radius } = designTokens;

function PathNode({ lesson, last, featured, onLocked }: {
  lesson: JourneyLesson;
  last: boolean;
  featured: boolean;
  onLocked: (lesson: JourneyLesson) => void;
}) {
  const palette = useAppPalette();
  const locked = lesson.state === 'locked';
  const completed = lesson.state === 'completed' || lesson.state === 'mastered';
  const current = lesson.state === 'in_progress' || (featured && lesson.state === 'available');
  const status = {
    locked: 'Locked', available: 'Ready to start', in_progress: 'In progress',
    completed: 'Completed', mastered: 'Mastered',
  }[lesson.state];
  const icon = completed
    ? { ios: 'checkmark', android: 'check', web: 'check' } as const
    : locked
      ? { ios: 'lock.fill', android: 'lock', web: 'lock' } as const
      : { ios: 'play.fill', android: 'play_arrow', web: 'play_arrow' } as const;

  return <View style={{ position: 'relative', paddingBottom: last ? 0 : spacing.sm }}>
    {!last ? <View pointerEvents="none" style={{
      position: 'absolute', left: 24, top: 24, bottom: -24, width: 2,
      backgroundColor: completed ? palette.success : palette.border,
    }} /> : null}
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${lesson.title}, ${status}`}
      accessibilityHint={locked ? 'Shows prerequisites' : 'Opens the lesson'}
      onPress={() => {
        if (locked) onLocked(lesson);
        else router.push({ pathname: '/lesson/[id]', params: { id: lesson.id } });
      }}
      style={({ pressed }) => ({
        flexDirection: 'row', alignItems: 'center', gap: spacing.sm, minHeight: 64,
        padding: spacing.xs, borderRadius: radius.md, borderCurve: 'continuous',
        backgroundColor: current || pressed ? palette.primarySoft : 'transparent',
        borderWidth: 1, borderColor: current ? palette.primary : 'transparent',
      })}
    >
      <View style={{
        width: 40, height: 40, alignItems: 'center', justifyContent: 'center',
        borderRadius: radius.pill, borderWidth: 1, borderColor: palette.border,
        backgroundColor: current ? palette.primary : palette.surface,
      }}>
        <SymbolView name={icon} size={18} tintColor={current ? palette.primaryOn : completed ? palette.success : locked ? palette.muted : palette.primary} fallback={<AppText>{completed ? '✓' : locked ? '–' : '›'}</AppText>} />
      </View>
      <View style={{ flex: 1, gap: spacing.xs }}>
        <AppText variant="label" tone={locked ? 'muted' : 'default'}>{lesson.title}</AppText>
        <AppText variant="caption" tone={completed ? 'success' : current ? 'primary' : 'muted'}>
          {lesson.kind === 'checkpoint' ? `Checkpoint · ${status}` : status}
        </AppText>
        {current && Boolean(lesson.objective) ? <AppText variant="caption" tone="muted">{lesson.objective}</AppText> : null}
      </View>
    </Pressable>
  </View>;
}

export function AdventurePath({ unit, expanded, currentLessonId, onToggle, onLocked = () => {} }: {
  unit: JourneyUnit;
  expanded: boolean;
  currentLessonId?: string;
  onToggle?: () => void;
  onLocked?: (lesson: JourneyLesson) => void;
}) {
  const palette = useAppPalette();
  const complete = unit.lessons.filter((lesson) => lesson.state === 'completed' || lesson.state === 'mastered').length;
  const required = unit.required_lessons ?? unit.lessons.length;
  const done = unit.completed_required_lessons ?? complete;
  const progress = unit.progress_percent ?? Math.round(complete * 100 / Math.max(1, unit.lessons.length));
  return <View style={{
    paddingVertical: spacing.lg, gap: spacing.sm,
    borderTopWidth: 1, borderColor: palette.border,
  }}>
    {onToggle ? <Pressable
      accessibilityRole="button"
      accessibilityLabel={`Unit ${unit.position}, ${unit.title}, ${done} of ${required} required lessons complete`}
      accessibilityState={{ expanded }}
      onPress={onToggle}
      style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: spacing.sm, minHeight: 48, opacity: pressed ? 0.75 : 1 })}
    >
      <View style={{ flex: 1, gap: spacing.xs }}>
        <AppText variant="caption" tone="primary">Unit {unit.position}</AppText>
        <AppText variant="heading">{unit.title}</AppText>
        <AppText variant="caption" tone="muted">{done} / {required} required lessons</AppText>
      </View>
      <SymbolView name={{ ios: expanded ? 'chevron.up' : 'chevron.down', android: expanded ? 'keyboard_arrow_up' : 'keyboard_arrow_down', web: expanded ? 'keyboard_arrow_up' : 'keyboard_arrow_down' }} size={22} tintColor={palette.primary} fallback={<AppText>{expanded ? '−' : '+'}</AppText>} />
    </Pressable> : <View style={{ gap: spacing.xs }}>
      <AppText variant="caption" tone="primary">Unit {unit.position}</AppText>
      <AppText variant="heading" accessibilityRole="header">{unit.title}</AppText>
      <AppText variant="caption" tone="muted">{done} / {required} required lessons</AppText>
    </View>}
    <XPProgressBar value={progress} max={100} label={`Unit ${unit.position} progress`} showValue={false} />
    {expanded ? <View style={{ paddingTop: spacing.sm }}>
      {unit.lessons.map((lesson, index) => <PathNode key={lesson.id} lesson={lesson} last={index === unit.lessons.length - 1} featured={lesson.id === currentLessonId} onLocked={onLocked} />)}
    </View> : null}
  </View>;
}
