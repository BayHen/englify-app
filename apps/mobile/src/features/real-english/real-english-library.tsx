import { useCallback, useMemo, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import * as Speech from 'expo-speech';
import { Linking, View } from 'react-native';
import { getSupabase } from '@/auth/supabase';
import { currentUserId, dataOrThrow, errorOrThrow } from '@/lib/supabase-query';
import { AppButton, AppCard, AppModal, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import type { Expression, ExpressionKind } from './api';
import { lessonMatchesQuery, paginate } from './library-utils';
import { normalizePublishedLessonRelations } from './lesson-relations';

type Phrase = { id: string; english_text: string; vietnamese_translation: string; formality: string; usage_context: string; ipa: string | null };
type Line = { id: string; speaker: string; english_text: string; vietnamese_translation: string; sort_order: number };
type Dialogue = { id: string; title: string; real_english_dialogue_lines: Line[] };
type Source = { id: string; attribution_text: string; source_url: string; translation_url: string; english_license: string; vietnamese_license: string };
type Lesson = { id: string; title: string; description: string; difficulty: string; content_type: string;
  real_english_phrases: Phrase[]; real_english_dialogues: Dialogue[]; real_english_source_references: Source[] };
type Progress = { lesson_id: string; status: 'in_progress' | 'completed'; is_bookmarked: boolean };
type LibraryItem = { key: string; title: string; type: 'expression'; expression: Expression }
  | { key: string; title: string; type: 'lesson'; lesson: Lesson };

type Props = {
  expressions: Expression[];
  expressionsLoading: boolean;
  expressionError: string;
  query: string;
  kind: ExpressionKind | 'all';
  savedOnly: boolean;
  onOpenExpression: (expression: Expression) => void;
  retryExpressions: () => void;
};

function lessonMatchesKind(lesson: Lesson, kind: ExpressionKind | 'all') {
  if (kind === 'all') return true;
  if (kind === 'movie_style_dialogue' || kind === 'everyday_conversation') return lesson.content_type === 'dialogue';
  return lesson.content_type === 'expression';
}

export function RealEnglishLibrary({ expressions, expressionsLoading, expressionError, query, kind,
  savedOnly, onOpenExpression, retryExpressions }: Props) {
  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [progress, setProgress] = useState<Record<string, Progress>>({});
  const [selectedLesson, setSelectedLesson] = useState<Lesson | null>(null);
  const [loadingLessons, setLoadingLessons] = useState(true);
  const [busy, setBusy] = useState(false);
  const [lessonError, setLessonError] = useState('');
  const [pagination, setPagination] = useState({ key: '', page: 1 });

  const load = useCallback(async () => {
    setLoadingLessons(true);
    try {
      const userId = await currentUserId();
      const [rows, saved] = await Promise.all([
        getSupabase().from('real_english_lessons').select('id,title,description,difficulty,content_type,real_english_phrases(id,english_text,vietnamese_translation,formality,usage_context,ipa),real_english_dialogues(id,title,real_english_dialogue_lines(id,speaker,english_text,vietnamese_translation,sort_order)),real_english_source_references(id,attribution_text,source_url,translation_url,english_license,vietnamese_license)')
          .eq('status', 'published').order('published_at', { ascending: false }),
        getSupabase().from('real_english_user_progress').select('lesson_id,status,is_bookmarked').eq('user_id', userId),
      ]);
      setLessons((dataOrThrow(rows) as Record<string, unknown>[])
        .map(normalizePublishedLessonRelations) as unknown as Lesson[]);
      setProgress(Object.fromEntries((dataOrThrow(saved) as Progress[]).map((item) => [item.lesson_id, item])));
      setLessonError('');
    } catch (cause) { setLessonError(cause instanceof Error ? cause.message : 'Could not load published lessons.'); }
    finally { setLoadingLessons(false); }
  }, []);

  useFocusEffect(useCallback(() => { void load(); return () => Speech.stop(); }, [load]));

  const items = useMemo(() => {
    const lessonItems: LibraryItem[] = lessons
      .filter((lesson) => lessonMatchesQuery(lesson, query))
      .filter((lesson) => lessonMatchesKind(lesson, kind))
      .filter((lesson) => !savedOnly || !!progress[lesson.id]?.is_bookmarked)
      .map((lesson) => ({ key: `lesson-${lesson.id}`, title: lesson.title, type: 'lesson', lesson }));
    const expressionItems: LibraryItem[] = expressions.map((expression) => ({
      key: `expression-${expression.id}`, title: expression.expression, type: 'expression', expression,
    }));
    return [...lessonItems, ...expressionItems].sort((left, right) => left.title.localeCompare(right.title));
  }, [expressions, kind, lessons, progress, query, savedOnly]);

  const pageKey = `${query}|${kind}|${savedOnly}`;
  const requestedPage = pagination.key === pageKey ? pagination.page : 1;
  const result = paginate(items, requestedPage);
  const loading = expressionsLoading || loadingLessons;
  const error = items.length === 0 ? expressionError || lessonError : '';

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
      else errorOrThrow(await getSupabase().from('real_english_user_progress').insert({ user_id: userId, lesson_id: lesson.id, ...update }));
      await load();
    } catch (cause) { setLessonError(cause instanceof Error ? cause.message : 'Could not save learning progress.'); }
    finally { setBusy(false); }
  }

  function closeLesson() { Speech.stop(); setSelectedLesson(null); }

  return <View style={{ gap: 12 }}>
    <View style={{ gap: 4 }}>
      <AppText variant="heading">Reading library</AppText>
      <AppText tone="muted">Expressions and reviewed lessons in one place · {items.length} result{items.length === 1 ? '' : 's'}</AppText>
    </View>
    {loading ? <LoadingSkeleton lines={5} /> : error ? <ErrorState message={error} retry={() => { retryExpressions(); void load(); }} />
      : result.items.length === 0 ? <EmptyState title="No reading found" message="Try another keyword, category, or saved filter." />
        : result.items.map((item) => item.type === 'lesson' ? <AppCard key={item.key}
          onPress={() => setSelectedLesson(item.lesson)} accessibilityLabel={`Open lesson ${item.lesson.title}`} style={{ gap: 5 }}>
          <AppText variant="caption" tone="primary">READING LESSON · {item.lesson.difficulty}</AppText>
          <AppText variant="heading">{item.lesson.title}</AppText>
          <AppText tone="muted">{item.lesson.description}</AppText>
          {progress[item.lesson.id]?.status === 'completed' ? <AppText tone="primary">Completed</AppText> : null}
        </AppCard> : <AppCard key={item.key} onPress={() => onOpenExpression(item.expression)}
          accessibilityLabel={`Open ${item.expression.expression}`} style={{ gap: 5 }}>
          <AppText variant="caption" tone="primary">{item.expression.kind.replaceAll('_', ' ').toUpperCase()} · {item.expression.formality}</AppText>
          <AppText variant="heading">{item.expression.expression}{item.expression.saved ? ' ★' : ''}</AppText>
          <AppText tone="muted">{item.expression.meaning_vi}</AppText>
        </AppCard>)}
    {!loading && !error && items.length > 0 ? <View style={{ gap: 8 }}>
      <AppText variant="caption" tone="muted" style={{ textAlign: 'center' }}>Page {result.page} of {result.pageCount}</AppText>
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <AppButton label="Previous" variant="secondary" disabled={result.page === 1} style={{ flex: 1 }}
          onPress={() => setPagination({ key: pageKey, page: result.page - 1 })} />
        <AppButton label="Next" variant="secondary" disabled={result.page === result.pageCount} style={{ flex: 1 }}
          onPress={() => setPagination({ key: pageKey, page: result.page + 1 })} />
      </View>
    </View> : null}

    <AppModal visible={Boolean(selectedLesson)} title={selectedLesson?.title ?? 'Reading lesson'} onClose={closeLesson}>
      {selectedLesson ? <View style={{ gap: 12 }}>
        <AppText variant="caption" tone="primary">{selectedLesson.difficulty} · {selectedLesson.content_type}</AppText>
        <AppText>{selectedLesson.description}</AppText>
        {selectedLesson.real_english_phrases.map((phrase) => <AppCard key={phrase.id} tone="primary" style={{ gap: 5 }}>
          <AppText variant="heading">{phrase.english_text}</AppText>
          <AppText tone="muted">{phrase.ipa ?? phrase.formality}</AppText>
          <AppText>{phrase.vietnamese_translation}</AppText>
          <AppText tone="muted">{phrase.usage_context}</AppText>
          <AppButton label="Listen with device voice" variant="secondary" onPress={() => {
            Speech.stop(); Speech.speak(phrase.english_text, { language: 'en-US', rate: 0.85 });
          }} />
        </AppCard>)}
        {selectedLesson.real_english_dialogues.map((dialogue) => <View key={dialogue.id} style={{ gap: 7 }}>
          <AppText variant="heading">{dialogue.title}</AppText>
          {[...dialogue.real_english_dialogue_lines].sort((a, b) => a.sort_order - b.sort_order).map((line) =>
            <AppCard key={line.id} style={{ gap: 3 }}><AppText>{line.speaker}: {line.english_text}</AppText>
              <AppText tone="muted">{line.vietnamese_translation}</AppText></AppCard>)}
        </View>)}
        {selectedLesson.real_english_source_references.map((source) => <View key={source.id} style={{ gap: 5 }}>
          <AppText variant="caption" tone="muted">{source.attribution_text}</AppText>
          <AppText variant="caption" tone="muted">English: {source.english_license} · Vietnamese: {source.vietnamese_license}</AppText>
          <AppButton label="View Tatoeba source" variant="secondary" onPress={() => { void Linking.openURL(source.source_url); }} />
          <AppButton label="View Vietnamese translation source" variant="secondary" onPress={() => { void Linking.openURL(source.translation_url); }} />
        </View>)}
        <AppButton label={progress[selectedLesson.id]?.is_bookmarked ? 'Remove bookmark' : 'Bookmark lesson'}
          variant="secondary" disabled={busy} onPress={() => {
            void updateProgress(selectedLesson, false, !progress[selectedLesson.id]?.is_bookmarked);
          }} />
        <AppButton label={progress[selectedLesson.id]?.status === 'completed' ? 'Replay completed lesson' : 'Mark lesson completed'}
          disabled={busy} onPress={() => {
            void updateProgress(selectedLesson, true, !!progress[selectedLesson.id]?.is_bookmarked);
          }} />
      </View> : null}
    </AppModal>
  </View>;
}
