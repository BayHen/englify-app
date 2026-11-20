import { useEffect, useState } from 'react';
import { View } from 'react-native';
import * as Speech from 'expo-speech';
import { AppButton, AppCard, AppInput, AppText } from '@/ui';
import { useAppPalette } from '@/constants/app-theme';
import type { LessonBlock } from './api';
export { initialBlockIndex } from './lesson-player-model';

function speak(text: string) {
  if (!text.trim()) return;
  Speech.stop();
  Speech.speak(text, { language: 'en-US', rate: 0.85 });
}

export function LessonPlayer({ blocks, initialIndex, bookmarked, onPosition, onBookmark, onNote }: {
  blocks: LessonBlock[]; initialIndex: number; bookmarked: boolean;
  onPosition: (block: LessonBlock, index: number) => void;
  onBookmark: (block: LessonBlock) => Promise<void>;
  onNote: (block: LessonBlock, note: string) => Promise<void>;
}) {
  const palette = useAppPalette();
  const [index, setIndex] = useState(Math.min(initialIndex, Math.max(0, blocks.length - 1)));
  const [showVietnamese, setShowVietnamese] = useState(true);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const block = blocks[index];
  useEffect(() => () => { void Speech.stop(); }, []);
  useEffect(() => { if (block) onPosition(block, index); }, [block, index, onPosition]);
  if (!block) return null;
  const content = block.content;
  const title = content.title ?? (block.type === 'vocabulary' ? content.word : block.type.replace('_', ' '));
  const english = content.text_en ?? content.example_en ?? '';
  const vietnamese = content.text_vi ?? content.meaning_vi ?? content.example_vi ?? '';
  async function run(action: () => Promise<void>) { if (busy) return; setBusy(true); try { await action(); } finally { setBusy(false); } }
  return <View style={{ gap: 12 }}>
    <View style={{ gap: 6 }}><AppText variant="caption" tone="primary">STEP {index + 1} OF {blocks.length} · {block.type.toUpperCase()}</AppText><View style={{ height: 6, borderRadius: 6, overflow: 'hidden', backgroundColor: palette.border }}><View style={{ height: 6, width: `${Math.round(((index + 1) / blocks.length) * 100)}%`, backgroundColor: palette.primary }} /></View></View>
    <AppCard tone="primary" style={{ gap: 10 }}><AppText variant="heading">{title}</AppText>
      {Boolean(content.pronunciation) ? <AppText tone="muted">{content.pronunciation}</AppText> : null}
      {Boolean(english) ? <AppText>{english}</AppText> : null}
      {showVietnamese && Boolean(vietnamese) ? <AppText tone="muted">{vietnamese}</AppText> : null}
      {content.lines?.map((line, lineIndex) => <View key={`${line.speaker}-${lineIndex}`} style={{ gap: 3 }}><AppText variant="label">{line.speaker}</AppText><AppText>{line.text_en}</AppText>{showVietnamese && Boolean(line.text_vi) ? <AppText tone="muted">{line.text_vi}</AppText> : null}<AppButton size="medium" variant="secondary" label={`Listen to ${line.speaker}`} onPress={() => speak(line.text_en)} /></View>)}
      {Boolean(english || content.word) ? <AppButton label="Listen with device voice" variant="secondary" onPress={() => speak(english || content.word || '')} /> : null}
      <AppButton label={showVietnamese ? 'Use English only' : 'Show Vietnamese'} variant="secondary" onPress={() => setShowVietnamese((value) => !value)} />
      <AppButton label={bookmarked ? 'Remove lesson bookmark' : 'Bookmark lesson'} variant="secondary" loading={busy} onPress={() => { void run(() => onBookmark(block)); }} />
    </AppCard>
    <AppCard style={{ gap: 8 }}><AppInput label="Personal note" value={note} onChangeText={setNote} placeholder="Write a short private note" multiline /><AppButton label="Save note" size="medium" variant="secondary" disabled={!note.trim()} loading={busy} onPress={() => { void run(async () => { await onNote(block, note.trim()); setNote(''); }); }} /></AppCard>
    <View style={{ flexDirection: 'row', gap: 8 }}><View style={{ flex: 1 }}><AppButton label="Previous" variant="secondary" disabled={index === 0} onPress={() => setIndex((value) => Math.max(0, value - 1))} /></View><View style={{ flex: 1 }}><AppButton label={index + 1 === blocks.length ? 'Content reviewed' : 'Next'} disabled={index + 1 === blocks.length} onPress={() => setIndex((value) => Math.min(blocks.length - 1, value + 1))} /></View></View>
    {index + 1 === blocks.length ? <AppText tone="muted">Reviewing every block does not complete the lesson. Submit the exercises below for server validation.</AppText> : null}
  </View>;
}
