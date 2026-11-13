import { useCallback, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import * as Speech from 'expo-speech';
import { Linking, View } from 'react-native';
import { getSupabase } from '@/auth/supabase';
import { currentUserId, dataOrThrow, errorOrThrow } from '@/lib/supabase-query';
import { AppButton, AppCard, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { normalizePublishedLessonRelations } from './lesson-relations';

type Phrase = { id: string; english_text: string; vietnamese_translation: string; formality: string; usage_context: string; ipa: string | null };
type Line = { id: string; speaker: string; english_text: string; vietnamese_translation: string; sort_order: number };
type Dialogue = { id: string; title: string; real_english_dialogue_lines: Line[] };
type Source = { id: string; attribution_text: string; source_url: string; translation_url: string; english_license: string; vietnamese_license: string };
type Lesson = { id: string; title: string; description: string; difficulty: string; content_type: string;
  real_english_phrases: Phrase[]; real_english_dialogues: Dialogue[]; real_english_source_references: Source[] };
type Progress = { lesson_id: string; status: 'in_progress' | 'completed'; is_bookmarked: boolean };

export function PublishedLessonFeed() {
  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [progress, setProgress] = useState<Record<string, Progress>>({});
  const [selected, setSelected] = useState<Lesson | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const load = useCallback(async () => {
    setLoading(true);
    try {
      const userId = await currentUserId();
      const [rows, saved] = await Promise.all([
        getSupabase().from('real_english_lessons').select('id,title,description,difficulty,content_type,real_english_phrases(id,english_text,vietnamese_translation,formality,usage_context,ipa),real_english_dialogues(id,title,real_english_dialogue_lines(id,speaker,english_text,vietnamese_translation,sort_order)),real_english_source_references(id,attribution_text,source_url,translation_url,english_license,vietnamese_license)')
          .eq('status', 'published').order('published_at', { ascending: false }).limit(30),
        getSupabase().from('real_english_user_progress').select('lesson_id,status,is_bookmarked').eq('user_id', userId),
      ]);
      setLessons((dataOrThrow(rows) as Record<string, unknown>[])
        .map(normalizePublishedLessonRelations) as unknown as Lesson[]);
      setProgress(Object.fromEntries((dataOrThrow(saved) as Progress[]).map((item) => [item.lesson_id, item])));
      setError('');
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load published lessons.'); }
    finally { setLoading(false); }
  }, []);
  useFocusEffect(useCallback(() => { void load(); return () => Speech.stop(); }, [load]));

  async function updateProgress(lesson: Lesson, completed: boolean, bookmarked: boolean) {
    if (busy) return;
    setBusy(true);
    try {
      const userId = await currentUserId();
      const existing = progress[lesson.id];
      const update = { status: completed || existing?.status === 'completed' ? 'completed' : 'in_progress',
        is_bookmarked: bookmarked, last_accessed_at: new Date().toISOString() };
      if (existing) errorOrThrow(await getSupabase().from('real_english_user_progress').update(update)
        .eq('user_id', userId).eq('lesson_id', lesson.id));
      else errorOrThrow(await getSupabase().from('real_english_user_progress').insert({
        user_id: userId, lesson_id: lesson.id, ...update,
      }));
      await load();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save learning progress.'); }
    finally { setBusy(false); }
  }

  return <View style={{ gap: 12 }}>
    <AppText variant="heading">New lessons</AppText>
    <AppText tone="muted">Published lessons reviewed by the content team.</AppText>
    {loading ? <LoadingSkeleton lines={3} /> : error ? <ErrorState message={error} retry={() => { void load(); }} />
      : lessons.length === 0 ? <EmptyState title="No new lessons yet" message="Reviewed lessons will appear here when published." />
        : lessons.map((lesson) => <AppCard key={lesson.id} onPress={() => setSelected(lesson)}
          accessibilityLabel={`Open lesson ${lesson.title}`} style={{ gap: 5 }}>
          <AppText variant="caption" tone="primary">{lesson.difficulty} · {lesson.content_type}</AppText>
          <AppText variant="heading">{lesson.title}</AppText>
          <AppText tone="muted">{lesson.description}</AppText>
          {progress[lesson.id]?.status === 'completed' ? <AppText tone="primary">Completed</AppText> : null}
        </AppCard>)}
    {selected ? <AppCard tone="primary" style={{ gap: 12 }}>
      <AppText variant="title">{selected.title}</AppText><AppText>{selected.description}</AppText>
      {selected.real_english_phrases.map((phrase) => <View key={phrase.id} style={{ gap: 5 }}>
        <AppText variant="heading">{phrase.english_text}</AppText>
        <AppText tone="muted">{phrase.ipa ?? phrase.formality}</AppText>
        <AppText>{phrase.vietnamese_translation}</AppText>
        <AppText tone="muted">{phrase.usage_context}</AppText>
        <AppButton label="Listen with device voice" variant="secondary" onPress={() => {
          Speech.stop(); Speech.speak(phrase.english_text, { language: 'en-US', rate: 0.85 });
        }} />
      </View>)}
      {selected.real_english_dialogues.map((dialogue) => <View key={dialogue.id} style={{ gap: 5 }}>
        <AppText variant="label">{dialogue.title}</AppText>
        {[...dialogue.real_english_dialogue_lines].sort((a, b) => a.sort_order - b.sort_order).map((line) =>
          <View key={line.id}><AppText>{line.speaker}: {line.english_text}</AppText>
            <AppText tone="muted">{line.vietnamese_translation}</AppText></View>)}
      </View>)}
      {selected.real_english_source_references.map((source) => <View key={source.id} style={{ gap: 5 }}>
        <AppText variant="caption" tone="muted">{source.attribution_text}</AppText>
        <AppText variant="caption" tone="muted">English: {source.english_license} · Vietnamese: {source.vietnamese_license}</AppText>
        <AppButton label="View Tatoeba source" variant="secondary" onPress={() => { void Linking.openURL(source.source_url); }} />
        <AppButton label="View Vietnamese translation source" variant="secondary" onPress={() => { void Linking.openURL(source.translation_url); }} />
      </View>)}
      <AppButton label={progress[selected.id]?.is_bookmarked ? 'Remove bookmark' : 'Bookmark lesson'} variant="secondary" disabled={busy}
        onPress={() => { void updateProgress(selected, false, !progress[selected.id]?.is_bookmarked); }} />
      <AppButton label={progress[selected.id]?.status === 'completed' ? 'Replay completed lesson' : 'Mark lesson completed'} disabled={busy}
        onPress={() => { void updateProgress(selected, true, !!progress[selected.id]?.is_bookmarked); }} />
      <AppButton label="Close lesson" variant="secondary" onPress={() => { Speech.stop(); setSelected(null); }} />
    </AppCard> : null}
  </View>;
}
