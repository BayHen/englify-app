import { useCallback, useRef, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import { randomUUID } from 'expo-crypto';
import * as Speech from 'expo-speech';
import { View } from 'react-native';
import { AppButton, AppCard, AppModal, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import {
  getPublishedLesson, getReadingQuestions, recordReading, saveLessonPhrase, searchRealEnglishLibrary,
  submitReadingAnswer, type CefrLevel, type ComprehensionQuestion, type ComprehensionResult,
  type LessonDetail, type LibraryCategory, type LibraryItem, type LibraryPage, type ReadingProgress,
} from './api';
import { normalizePublishedLessonRelations } from './lesson-relations';
import { useI18n } from '@/i18n/context';

type Props = { query: string; cefr: CefrLevel | 'all'; topic: string; category: LibraryCategory | 'all'; savedOnly: boolean; onOpenExpression: (id: string) => void };
const emptyPage: LibraryPage = { items: [], total: 0, page: 1, page_size: 5, page_count: 1 };
const progressLabels: Record<string, string> = { reading: 'Reading', read: 'Read', practiced: 'Practiced', passed: 'Passed', mastered: 'Mastered' };

export function RealEnglishLibraryV2({ query, cefr, topic, category, savedOnly, onOpenExpression }: Props) {
  const { language, l } = useI18n();
  const [result, setResult] = useState<LibraryPage>(emptyPage);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [detail, setDetail] = useState<LessonDetail | null>(null);
  const [progress, setProgress] = useState<ReadingProgress | null>(null);
  const [questions, setQuestions] = useState<ComprehensionQuestion[]>([]);
  const [answers, setAnswers] = useState<Record<string, ComprehensionResult>>({});
  const [showVietnamese, setShowVietnamese] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailError, setDetailError] = useState('');
  const [busy, setBusy] = useState(false);
  const requests = useRef<Record<string, string>>({});

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setResult(await searchRealEnglishLibrary({ query, cefr: cefr === 'all' ? undefined : cefr,
        topic: topic || undefined, category: category === 'all' ? undefined : category, savedOnly, page }));
      setError('');
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load the reading library.'); }
    finally { setLoading(false); }
  }, [category, cefr, page, query, savedOnly, topic]);

  useFocusEffect(useCallback(() => { void load(); return () => Speech.stop(); }, [load]));

  async function openLesson(item: LibraryItem) {
    setDetailLoading(true); setDetailError(''); setQuestions([]); setAnswers({}); setShowVietnamese(true);
    try {
      const [{ lesson, progress: current }, readingQuestions] = await Promise.all([getPublishedLesson(item.id), getReadingQuestions(item.id)]);
      setDetail(normalizePublishedLessonRelations(lesson as unknown as Record<string, unknown>) as unknown as LessonDetail);
      setQuestions(readingQuestions);
      setProgress(await recordReading(item.id, 'open', { readingPercent: Math.max(1, current?.reading_percent ?? 0) }));
    } catch (cause) { setDetailError(cause instanceof Error ? cause.message : 'Could not open this reading.'); }
    finally { setDetailLoading(false); }
  }

  async function updateProgress(action: 'read' | 'bookmark', bookmarked?: boolean) {
    if (!detail || busy) return;
    setBusy(true);
    try {
      setProgress(await recordReading(detail.id, action, { readingPercent: action === 'read' ? 100 : undefined, bookmarked }));
      setDetailError(''); await load();
    } catch (cause) { setDetailError(cause instanceof Error ? cause.message : 'Could not save reading progress.'); }
    finally { setBusy(false); }
  }

  async function answer(question: ComprehensionQuestion, option: string) {
    if (!detail || busy || answers[question.id]) return;
    setBusy(true);
    try {
      requests.current[question.id] ??= randomUUID();
      const next = await submitReadingAnswer(detail.id, question.id, requests.current[question.id], option);
      setAnswers((current) => ({ ...current, [question.id]: next }));
      setProgress((current) => current ? { ...current, status: next.progress_status } : current); setDetailError('');
    } catch (cause) { setDetailError(cause instanceof Error ? cause.message : 'Could not submit this answer.'); }
    finally { setBusy(false); }
  }

  async function savePhrase(id: string) {
    if (busy) return;
    setBusy(true);
    try { await saveLessonPhrase(id); setDetailError(''); }
    catch (cause) { setDetailError(cause instanceof Error ? cause.message : 'Could not save this vocabulary.'); }
    finally { setBusy(false); }
  }

  function speak(text: string) { Speech.stop(); Speech.speak(text, { language: 'en-US', rate: 0.85 }); }
  function closeLesson() { Speech.stop(); setDetail(null); setDetailError(''); setQuestions([]); }

  return <View style={{ gap: 12 }}>
    <View style={{ gap: 4 }}><AppText variant="heading">Reading library</AppText>
      <AppText tone="muted">{language === 'vi' ? `${result.total} mẫu câu và bài học đã xuất bản` : `Published expressions and lessons · ${result.total} result${result.total === 1 ? '' : 's'}`}</AppText></View>
    {loading ? <LoadingSkeleton lines={5} /> : error ? <ErrorState message={error} retry={() => { void load(); }} />
      : result.items.length === 0 ? <EmptyState title="No reading found" message="Try another keyword, level, topic, or category." />
        : result.items.map((item) => <AppCard key={`${item.item_type}-${item.id}`}
          onPress={() => item.item_type === 'lesson' ? void openLesson(item) : onOpenExpression(item.id)}
          accessibilityLabel={`Open ${item.title}`} style={{ gap: 5 }}>
          <AppText variant="caption" tone="primary">{item.item_type === 'lesson' ? 'READING LESSON' : item.category.replaceAll('_', ' ').toUpperCase()}{item.cefr_level ? ` · ${item.cefr_level}` : ''}</AppText>
          <AppText variant="heading">{item.title}{item.saved ? ' ★' : ''}</AppText><AppText tone="muted">{item.subtitle}</AppText>
          {item.progress_status ? <AppText variant="caption" tone="success">{progressLabels[item.progress_status]}</AppText> : null}
        </AppCard>)}
    {!loading && !error && result.total > 0 ? <View style={{ gap: 8 }}><AppText variant="caption" tone="muted" style={{ textAlign: 'center' }}>{l(`Page ${result.page} of ${result.page_count}`)}</AppText>
      <View style={{ flexDirection: 'row', gap: 8 }}><AppButton label="Previous" variant="secondary" disabled={result.page <= 1} style={{ flex: 1 }} onPress={() => setPage(Math.max(1, result.page - 1))} />
        <AppButton label="Next" variant="secondary" disabled={result.page >= result.page_count} style={{ flex: 1 }} onPress={() => setPage(result.page + 1)} /></View></View> : null}

    <AppModal visible={Boolean(detail) || detailLoading || Boolean(detailError)} title={detail?.title ?? 'Reading lesson'} onClose={closeLesson}>
      {detailLoading ? <LoadingSkeleton lines={5} /> : detailError && !detail ? <ErrorState message={detailError} retry={closeLesson} />
        : detail ? <View style={{ gap: 12 }}>
          <AppText variant="caption" tone="primary">{detail.difficulty} · {detail.content_type.toUpperCase()} · {progress ? progressLabels[progress.status] : 'Not started'}</AppText>
          <AppText>{detail.description}</AppText><AppButton label={showVietnamese ? 'Hide Vietnamese' : 'Show Vietnamese'} variant="secondary" onPress={() => setShowVietnamese((value) => !value)} />
          {detail.real_english_phrases.map((phrase) => <AppCard key={phrase.id} tone="primary" style={{ gap: 6 }}><AppText variant="heading">{phrase.english_text}</AppText>
            <AppText tone="muted">{phrase.ipa ?? phrase.formality}</AppText>{showVietnamese ? <AppText>{phrase.vietnamese_translation}</AppText> : null}<AppText tone="muted">{phrase.usage_context}</AppText>
            <AppButton label="Listen" variant="secondary" onPress={() => speak(phrase.english_text)} />
            {phrase.dictionary_entry_id ? <AppButton label="Save vocabulary" variant="secondary" disabled={busy} onPress={() => { void savePhrase(phrase.id); }} /> : null}</AppCard>)}
          {detail.real_english_dialogues.map((dialogue) => <View key={dialogue.id} style={{ gap: 7 }}><AppText variant="heading">{dialogue.title}</AppText>
            {[...dialogue.real_english_dialogue_lines].sort((a, b) => a.sort_order - b.sort_order).map((line) => <AppCard key={line.id} style={{ gap: 5 }}><AppText>{line.speaker}: {line.english_text}</AppText>
              {showVietnamese ? <AppText tone="muted">{line.vietnamese_translation}</AppText> : null}<AppButton label={`Listen to ${line.speaker}`} variant="secondary" onPress={() => speak(line.english_text)} /></AppCard>)}</View>)}
          {questions.length > 0 ? <View style={{ gap: 8 }}><AppText variant="heading">Check your understanding</AppText>{questions.map((question) => <AppCard key={question.id} style={{ gap: 7 }}><AppText variant="label">{question.prompt}</AppText>
            {question.options.map((option) => <AppButton key={option.id} label={option.text} variant="secondary" disabled={busy || Boolean(answers[question.id])} onPress={() => { void answer(question, option.id); }} />)}
            {answers[question.id] ? <AppText tone={answers[question.id].is_correct ? 'success' : 'error'}>{answers[question.id].is_correct ? 'Correct. ' : 'Review this answer. '}{answers[question.id].explanation}</AppText> : null}</AppCard>)}</View> : null}
          {detailError ? <ErrorState message={detailError} retry={() => setDetailError('')} /> : null}
          <AppButton label={progress?.is_bookmarked ? 'Remove bookmark' : 'Bookmark lesson'} variant="secondary" disabled={busy} onPress={() => { void updateProgress('bookmark', !progress?.is_bookmarked); }} />
          <AppButton label={progress?.status === 'read' ? 'Read again' : 'Mark as read'} disabled={busy} onPress={() => { void updateProgress('read'); }} />
          {detail.real_english_source_references.map((source) => <View key={source.id} style={{ gap: 4 }}><AppText variant="caption" tone="muted">{source.attribution_text}</AppText>
            <AppText variant="caption" tone="muted">English: {source.english_license} · Vietnamese: {source.vietnamese_license}</AppText></View>)}
        </View> : <EmptyState title="Lesson unavailable" message="Close this window and try again." />}
    </AppModal>
  </View>;
}
