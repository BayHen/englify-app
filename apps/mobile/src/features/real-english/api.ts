import { getSupabase } from '@/auth/supabase';
import { ApiError } from '@/lib/api';
import { currentUserId, dataOrThrow, errorOrThrow } from '@/lib/supabase-query';
import { normalizeSearchText } from './library-utils';

export type ExpressionKind = 'slang' | 'idiom' | 'phrasal_verb' | 'casual_expression' | 'everyday_conversation' | 'movie_style_dialogue';
export type DialogueLine = { speaker: string; line: string };
export type Expression = { id: string; slug: string; kind: ExpressionKind; expression: string; meaning_vi: string; context_explanation: string; example_en: string; example_vi: string; dialogue: DialogueLine[]; formality: 'informal' | 'neutral' | 'formal'; region_note: string; source_name: string; license_id: string; provenance_note: string; saved: boolean };
export type ContextQuiz = { id: string; expression_id: string; prompt: string; options: { id: string; text: string }[] };
export type QuizResult = { attempt_id: string; question_id: string; is_correct: boolean; correct_option: string; explanation: string; created_at: string };
export type CefrLevel = 'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2';
export type LibraryCategory = ExpressionKind | 'expression' | 'dialogue' | 'scenario';
export type ReadingStatus = 'reading' | 'read' | 'practiced' | 'passed' | 'mastered';
export type LibraryItem = {
  item_type: 'expression' | 'lesson'; id: string; title: string; subtitle: string;
  cefr_level: CefrLevel | null; topic_slug: string | null; category: LibraryCategory;
  formality: 'informal' | 'neutral' | 'formal' | null; saved: boolean; progress_status: ReadingStatus | null;
};
export type LibraryPage = { items: LibraryItem[]; total: number; page: number; page_size: number; page_count: number };
export type LessonPhrase = { id: string; english_text: string; vietnamese_translation: string; formality: string; usage_context: string; ipa: string | null; dictionary_entry_id: string | null };
export type LessonLine = { id: string; speaker: string; english_text: string; vietnamese_translation: string; sort_order: number };
export type LessonDetail = { id: string; title: string; description: string; difficulty: CefrLevel; content_type: 'expression' | 'dialogue' | 'scenario';
  real_english_phrases: LessonPhrase[]; real_english_dialogues: { id: string; title: string; real_english_dialogue_lines: LessonLine[] }[];
  real_english_source_references: { id: string; attribution_text: string; english_license: string; vietnamese_license: string }[] };
export type ReadingProgress = { lesson_id: string; status: ReadingStatus; is_bookmarked: boolean; reading_percent: number };
export type ComprehensionQuestion = { id: string; prompt: string; position: number; options: { id: string; text: string }[] };
export type ComprehensionResult = { attempt_id: string; is_correct: boolean; correct_option: string; explanation: string; progress_status: ReadingStatus };
export type TopicOption = { slug: string; title: string; difficulty: CefrLevel };

const COLUMNS = 'id,slug,kind,expression,meaning_vi,context_explanation,example_en,example_vi,dialogue,formality,region_note,source_name,license_id,provenance_note';
const published = () => getSupabase().from('real_english_expressions').select(COLUMNS).eq('is_published', true).is('archived_at', null);

export async function getExpression(id: string): Promise<Expression> {
  const [row, saved] = await Promise.all([
    published().eq('id', id).maybeSingle(),
    getSupabase().from('saved_expressions').select('id').eq('expression_id', id).maybeSingle(),
  ]);
  errorOrThrow(saved);
  return { ...dataOrThrow(row), saved: !!saved.data } as Expression;
}

export async function searchExpressions(query = '', kind?: ExpressionKind, savedOnly = false): Promise<Expression[]> {
  const userId = await currentUserId();
  const term = query.trim();
  if (term.length > 80) throw new ApiError(422, 'Search term is too long.');
  const saves = dataOrThrow(await getSupabase().from('saved_expressions').select('expression_id').eq('user_id', userId));
  const savedIds = new Set(saves.map((row) => row.expression_id));
  if (savedOnly && !savedIds.size) return [];
  let rows: Record<string, unknown>[];
  if (term) {
    let request = published();
    if (kind) request = request.eq('kind', kind);
    if (savedOnly) request = request.in('id', [...savedIds]);
    const normalizedTerm = normalizeSearchText(term);
    rows = dataOrThrow(await request.order('expression').limit(1000)).filter((row) => normalizeSearchText([
      row.expression, row.meaning_vi, row.context_explanation, row.example_en, row.example_vi,
      row.region_note, JSON.stringify(row.dialogue ?? []),
    ].map((value) => String(value ?? '')).join(' ')).includes(normalizedTerm));
  } else {
    let request = published();
    if (kind) request = request.eq('kind', kind);
    if (savedOnly) request = request.in('id', [...savedIds]);
    rows = dataOrThrow(await request.order('expression').limit(50));
  }
  const unique = new Map(rows.map((row) => [String(row.id), row]));
  return [...unique.values()].sort((a, b) => String(a.expression).localeCompare(String(b.expression)))
    .slice(0, 30).map((row) => ({ ...row, saved: savedIds.has(String(row.id)) })) as Expression[];
}
export async function saveExpression(id: string): Promise<Expression> {
  const userId = await currentUserId();
  await getExpression(id);
  errorOrThrow(await getSupabase().from('saved_expressions')
    .upsert({ user_id: userId, expression_id: id }, { onConflict: 'user_id,expression_id', ignoreDuplicates: true }));
  return getExpression(id);
}
export async function unsaveExpression(id: string): Promise<Expression> {
  const userId = await currentUserId();
  await getExpression(id);
  errorOrThrow(await getSupabase().from('saved_expressions').delete().eq('user_id', userId).eq('expression_id', id));
  return getExpression(id);
}

export async function listRealEnglishTopics(): Promise<TopicOption[]> {
  await currentUserId();
  return dataOrThrow(await getSupabase().from('real_english_topics').select('slug,title,difficulty')
    .eq('is_active', true).order('difficulty').order('title')) as TopicOption[];
}

function isMissingLibrarySearchRpc(error: { code?: string; message?: string } | null) {
  if (!error) return false;
  return error.code === 'PGRST202'
    || (error.message?.includes('englify_search_real_english')
      && error.message.includes('schema cache'));
}

function matchesLibraryCategory(item: LibraryItem, category?: LibraryCategory) {
  if (!category) return true;
  if (category === 'expression') return item.item_type === 'expression' || item.category === 'expression';
  if (category === 'dialogue') {
    return item.category === 'dialogue'
      || item.category === 'everyday_conversation'
      || item.category === 'movie_style_dialogue';
  }
  return item.category === category;
}

async function searchRealEnglishLibraryFallback(input: {
  query?: string; cefr?: CefrLevel; topic?: string; category?: LibraryCategory; savedOnly?: boolean; page?: number;
}, userId: string): Promise<LibraryPage> {
  const [expressionsResult, lessonsResult, topicsResult, savesResult, progressResult] = await Promise.all([
    published().order('expression').limit(500),
    getSupabase().from('real_english_lessons')
      .select('id,title,description,difficulty,content_type,topic_id,real_english_phrases(english_text,vietnamese_translation,usage_context),real_english_dialogues(title,real_english_dialogue_lines(speaker,english_text,vietnamese_translation))')
      .eq('status', 'published').order('published_at', { ascending: false }).limit(500),
    getSupabase().from('real_english_topics').select('id,slug').eq('is_active', true),
    getSupabase().from('saved_expressions').select('expression_id').eq('user_id', userId),
    getSupabase().from('real_english_user_progress')
      .select('lesson_id,status,is_bookmarked').eq('user_id', userId),
  ]);
  const expressionRows = dataOrThrow(expressionsResult) as Record<string, unknown>[];
  const lessonRows = dataOrThrow(lessonsResult) as Record<string, unknown>[];
  const topicRows = dataOrThrow(topicsResult) as { id: string; slug: string }[];
  const savedExpressionIds = new Set((dataOrThrow(savesResult) as { expression_id: string }[])
    .map((row) => row.expression_id));
  const progressRows = dataOrThrow(progressResult) as {
    lesson_id: string; status: ReadingStatus; is_bookmarked: boolean;
  }[];
  const topicById = new Map(topicRows.map((row) => [row.id, row.slug]));
  const progressByLesson = new Map(progressRows.map((row) => [row.lesson_id, row]));

  const expressions: LibraryItem[] = expressionRows.map((row) => ({
    item_type: 'expression',
    id: String(row.id),
    title: String(row.expression ?? ''),
    subtitle: String(row.meaning_vi ?? ''),
    // Legacy projects may not have the optional Phase 2 metadata columns yet.
    cefr_level: null,
    topic_slug: null,
    category: row.kind as LibraryCategory,
    formality: row.formality as LibraryItem['formality'],
    saved: savedExpressionIds.has(String(row.id)),
    progress_status: null,
  }));
  const lessons: LibraryItem[] = lessonRows.map((row) => {
    const progress = progressByLesson.get(String(row.id));
    return {
      item_type: 'lesson',
      id: String(row.id),
      title: String(row.title ?? ''),
      subtitle: String(row.description ?? ''),
      cefr_level: row.difficulty as CefrLevel,
      topic_slug: topicById.get(String(row.topic_id)) ?? null,
      category: row.content_type as LibraryCategory,
      formality: null,
      saved: Boolean(progress?.is_bookmarked),
      progress_status: progress?.status ?? null,
    };
  });
  const rawRows = [...expressionRows, ...lessonRows];
  const searchableById = new Map(rawRows.map((row) => [String(row.id), normalizeSearchText(JSON.stringify(row))]));
  const term = normalizeSearchText(input.query?.trim() ?? '');
  const filtered = [...expressions, ...lessons]
    .filter((item) => !term || searchableById.get(item.id)?.includes(term))
    .filter((item) => !input.cefr || item.cefr_level === input.cefr)
    .filter((item) => !input.topic || item.topic_slug === input.topic)
    .filter((item) => matchesLibraryCategory(item, input.category))
    .filter((item) => !input.savedOnly || item.saved)
    .sort((left, right) => left.title.localeCompare(right.title));
  const pageSize = 5;
  const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize));
  const page = Math.min(Math.max(1, input.page ?? 1), pageCount);
  return {
    items: filtered.slice((page - 1) * pageSize, page * pageSize),
    total: filtered.length,
    page,
    page_size: pageSize,
    page_count: pageCount,
  };
}

export async function searchRealEnglishLibrary(input: {
  query?: string; cefr?: CefrLevel; topic?: string; category?: LibraryCategory; savedOnly?: boolean; page?: number;
}): Promise<LibraryPage> {
  const userId = await currentUserId();
  const query = input.query?.trim() ?? '';
  if (query.length > 80) throw new ApiError(422, 'Search term is too long.');
  const result = await getSupabase().rpc('englify_search_real_english', {
    p_query: query, p_cefr: input.cefr ?? null, p_topic: input.topic ?? null,
    p_category: input.category ?? null, p_saved_only: input.savedOnly ?? false,
    p_page: input.page ?? 1, p_page_size: 5,
  });
  if (isMissingLibrarySearchRpc(result.error)) {
    return searchRealEnglishLibraryFallback({ ...input, query }, userId);
  }
  return dataOrThrow(result) as LibraryPage;
}

export async function getPublishedLesson(id: string): Promise<{ lesson: LessonDetail; progress: ReadingProgress | null }> {
  const userId = await currentUserId();
  const [lesson, progress] = await Promise.all([
    getSupabase().from('real_english_lessons')
      .select('id,title,description,difficulty,content_type,real_english_phrases(id,english_text,vietnamese_translation,formality,usage_context,ipa,dictionary_entry_id),real_english_dialogues(id,title,real_english_dialogue_lines(id,speaker,english_text,vietnamese_translation,sort_order)),real_english_source_references(id,attribution_text,english_license,vietnamese_license)')
      .eq('id', id).eq('status', 'published').single(),
    getSupabase().from('real_english_user_progress').select('lesson_id,status,is_bookmarked,reading_percent')
      .eq('user_id', userId).eq('lesson_id', id).maybeSingle(),
  ]);
  errorOrThrow(progress);
  return { lesson: dataOrThrow(lesson) as unknown as LessonDetail, progress: progress.data as ReadingProgress | null };
}

export async function recordReading(id: string, action: 'open' | 'read' | 'bookmark', input?: {
  readingPercent?: number; bookmarked?: boolean;
}): Promise<ReadingProgress> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_record_real_english_reading', {
    p_lesson_id: id, p_action: action, p_reading_percent: input?.readingPercent ?? null,
    p_bookmarked: input?.bookmarked ?? null,
  })) as ReadingProgress;
}

export async function getReadingQuestions(id: string): Promise<ComprehensionQuestion[]> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_real_english_questions', { p_lesson_id: id })) as ComprehensionQuestion[];
}

export async function submitReadingAnswer(lessonId: string, questionId: string, requestId: string, option: string) {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_submit_real_english_comprehension', {
    p_lesson_id: lessonId, p_question_id: questionId, p_request_id: requestId, p_selected_option: option,
  })) as ComprehensionResult;
}

export async function saveLessonPhrase(phraseId: string): Promise<void> {
  await currentUserId();
  errorOrThrow(await getSupabase().rpc('englify_save_real_english_phrase', { p_phrase_id: phraseId }));
}
export async function getContextQuiz(id: string): Promise<ContextQuiz> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_context_quiz', { p_expression_id: id })) as ContextQuiz;
}
export async function submitContextQuiz(id: string, requestId: string, option: string): Promise<QuizResult> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_submit_context_quiz', {
    p_expression_id: id, p_request_id: requestId, p_selected_option: option,
  })) as QuizResult;
}
