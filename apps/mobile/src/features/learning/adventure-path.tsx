import { router, type Href } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, View } from 'react-native';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from '@/ui';
import type { JourneyLesson, JourneyUnit } from './api';

function PathNode({ lesson, index, last }: { lesson: JourneyLesson; index: number; last: boolean }) {
  const palette = useAppPalette();
  const locked = lesson.state === 'locked';
  const done = lesson.state === 'completed' || lesson.state === 'mastered';
  const current = lesson.state === 'in_progress' || lesson.state === 'available';
  return <View style={{ alignItems: index % 2 === 0 ? 'flex-start' : 'flex-end', minHeight: last ? 126 : 142, position: 'relative' }}>
    {!last ? <View style={{ position: 'absolute', top: 57, left: '50%', width: 4, height: 95, marginLeft: -2, borderRadius: 2, backgroundColor: done ? palette.success : palette.border }} /> : null}
    <Pressable accessibilityRole="button" accessibilityLabel={`${lesson.title}, ${lesson.state.replace('_', ' ')}`} accessibilityState={{ disabled: locked }} disabled={locked} onPress={() => router.push(`/lesson/${lesson.id}` as Href)} style={({ pressed }) => ({ width: '82%', padding: 13, flexDirection: 'row', alignItems: 'center', gap: 11, backgroundColor: current ? palette.primarySoft : palette.surface, borderWidth: current ? 2 : 1, borderColor: current ? palette.primary : palette.border, borderRadius: 23, opacity: locked ? 0.65 : pressed ? 0.75 : 1 })}>
      <View style={{ width: 54, height: 54, borderRadius: 19, alignItems: 'center', justifyContent: 'center', backgroundColor: done ? palette.success : current ? palette.primary : palette.border }}><SymbolView name={{ ios: done ? 'checkmark' : locked ? 'lock.fill' : 'book.fill', android: done ? 'check' : locked ? 'lock' : 'menu_book', web: done ? 'check' : locked ? 'lock' : 'menu_book' }} size={26} tintColor={done || current ? palette.primaryOn : palette.muted} /></View>
      <View style={{ flex: 1, gap: 3 }}><AppText variant="caption" tone={current ? 'primary' : 'muted'}>{done ? lesson.state === 'mastered' ? 'MASTERED' : 'COMPLETED' : locked ? 'LOCKED' : lesson.state === 'in_progress' ? 'IN PROGRESS' : 'UP NEXT'}</AppText><AppText variant="label">{lesson.title}</AppText><AppText variant="caption" tone="muted" numberOfLines={2}>{lesson.objective}</AppText></View>
    </Pressable>
    {last ? <View style={{ alignSelf: 'center', marginTop: 14, borderRadius: 15, paddingHorizontal: 14, paddingVertical: 7, backgroundColor: palette.rewardSoft }}><AppText variant="caption" style={{ color: palette.rewardOn }}>✦ Unit milestone</AppText></View> : null}
  </View>;
}

export function AdventurePath({ unit }: { unit: JourneyUnit }) {
  const palette = useAppPalette();
  const complete = unit.lessons.filter((lesson) => lesson.state === 'completed' || lesson.state === 'mastered').length;
  return <View style={{ gap: 6, paddingVertical: 20, paddingHorizontal: 16, borderRadius: 25, backgroundColor: palette.surface }}>
    <View style={{ gap: 4, marginBottom: 8 }}><AppText variant="caption" tone="primary">WORLD {unit.position}</AppText><AppText variant="heading" accessibilityRole="header">{unit.title}</AppText><AppText variant="caption" tone="muted">{complete} of {unit.lessons.length} lessons completed</AppText></View>
    {unit.lessons.map((lesson, index) => <PathNode key={lesson.id} lesson={lesson} index={index} last={index === unit.lessons.length - 1} />)}
  </View>;
}
