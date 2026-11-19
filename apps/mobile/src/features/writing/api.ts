import { getSupabase } from '@/auth/supabase';
import { currentUserId, dataOrThrow } from '@/lib/supabase-query';

export type CefrLevel = 'A1' | 'A2' | 'B1' | 'B2' | 'C1';
export type ExerciseKind = 'sentence' | 'fill_blank' | 'sentence_order' | 'paragraph' | 'email' | 'opinion' | 'essay';
export type Exercise = { id: string; topic_id: string | null; topic_title: string | null; cefr_level: CefrLevel; kind: ExerciseKind;
  title: string; prompt: string; instructions: string | null; hint: string | null; tokens: string[]; min_words: number | null;
  recommended_words: number | null; estimated_minutes: number | null; difficulty: number };
export type WritingTopic = { id: string; slug: string; title: string; description: string; icon: string | null; sort_order: number; exercise_count: number };
export type WritingCatalog = { items: Exercise[]; total: number; page: number; page_size: number };
export type WritingFilters = { query?: string; level?: CefrLevel | null; topicId?: string | null; kind?: ExerciseKind | null; page?: number; pageSize?: number };
export type GrammarMatch = { message: string; offset: number; length: number; replacements: string[] };
export type Feedback = { rule_result: 'matched' | 'needs_revision' | 'self_review'; suggestions: string[]; grammar_status: 'not_requested' | 'available' | 'unavailable'; grammar_matches: GrammarMatch[] };
export type Submission = { id: string; exercise_id: string | null; prompt: string; body: string; created_at: string; feedback: Feedback | null };
export type WritingAiError = { type: 'grammar' | 'vocabulary' | 'sentence_structure' | 'spelling' | 'clarity' | 'coherence' | 'task_relevance'; original: string; corrected: string; explanation_vi: string };
export type WritingAiFeedback = { id: string; submission_id: string; request_id: string; overall_score: number; grammar_score: number;
  vocabulary_score: number; sentence_structure_score: number; coherence_score: number; task_score: number;
  assessment_vi: string; strengths: string[]; improvements: string[]; errors: WritingAiError[]; next_steps: string[]; created_at: string };
export type RewriteMode = 'grammar' | 'natural' | 'vocabulary' | 'formal' | 'simple';
export type WritingAiRewrite = { id: string; submission_id: string; request_id: string; mode: RewriteMode; original_text: string;
  improved_text: string; key_changes: string[]; explanations_vi: string[];
  vocabulary_suggestions: { original: string; suggestion: string; explanation_vi: string }[]; created_at: string };
export type WritingRevision = { id: string; submission_id: string; request_id: string; revision_number: number; revised_text: string;
  rewrite_id: string | null; ai_feedback_id: string | null; created_at: string };
export type WritingAiBundle = { feedback: WritingAiFeedback[]; rewrites: WritingAiRewrite[]; revisions: WritingRevision[] };
export type DailyWritingChallenge = Exercise & { assignment_id: string; challenge_date: string; timezone: string; topic: string;
  xp_reward: number; completed: boolean; completion: { id: string; submission_id: string; awarded_xp: number; completed_at: string } | null };
export type WritingStreak = { current_streak: number; longest_streak: number; last_completed_date: string | null; total_completed_days: number };
export type WritingCalendarDay = { date: string; status: 'completed' | 'missed' | 'today' | 'future' | 'unavailable' };
export type WritingMilestone = { id: string; title: string; description: string; metric: 'writing_streak' | 'writing_completed_days';
  target: number; progress: number; unlocked: boolean; unlocked_at: string | null };
export type DailyWritingOverview = { timezone: string; local_date: string; selected_cefr_level: CefrLevel; enabled: boolean;
  challenge: DailyWritingChallenge | null; streak: WritingStreak; calendar: WritingCalendarDay[]; milestones: WritingMilestone[] };
export type DailyWritingSubmitResult = { completed: boolean; newly_completed: boolean; earned_xp: number;
  submission: Submission; overview: DailyWritingOverview };
export type WritingTimezoneResult = { timezone: string; pending_timezone: string | null; effective_at: string | null };
export type AnalyticsRange = '7d' | '30d' | '90d' | 'all';
export type WritingProgressSummary = { total_exercises: number; total_submissions: number; total_words: number; practice_days: number;
  current_streak: number; longest_streak: number; total_challenge_days: number; average_ai_score: number | null;
  ai_score_samples: number; ai_trend_reliable: boolean; writing_cefr_level: CefrLevel; timezone: string; local_date: string };
export type WritingActivityDay = { date: string; submissions: number; words: number; daily_challenges: number };
export type WritingActivity = { range: AnalyticsRange; start_date: string | null; end_date: string; items: WritingActivityDay[] };
export type WritingScorePoint = { submission_id: string; date: string; cefr_level: CefrLevel | null; kind: ExerciseKind | null;
  group: string; overall_score: number; grammar_score: number; vocabulary_score: number; coherence_score: number; task_score: number };
export type WritingScoreGroup = { cefr_level: CefrLevel | null; kind: ExerciseKind | null; sample_size: number; reliable_trend: boolean;
  overall_score: number; grammar_score: number; vocabulary_score: number; coherence_score: number; task_score: number };
export type WritingScoreAnalytics = { range: AnalyticsRange; scoring_basis: string; trends: WritingScorePoint[]; groups: WritingScoreGroup[];
  recent: { submission_id: string; exercise_title: string; cefr_level: CefrLevel | null; kind: ExerciseKind | null; submitted_at: string; overall_score: number }[] };
export type WritingMistake = { category: string; issue_count: number; examples: { submission_id: string; original: string; corrected: string; explanation_vi: string }[] };
export type WritingCefrProgress = { cefr_level: CefrLevel; available_exercises: number; distinct_exercises: number; submissions: number;
  average_ai_score: number | null; ai_score_samples: number; daily_challenges: number; last_practiced_at: string | null };
export type WritingTopicProgress = { topic_id: string; slug: string; title: string; available_exercises: number; distinct_exercises: number;
  submissions: number; average_ai_score: number | null; ai_score_samples: number; last_practiced_at: string | null };
export type WritingRecommendation = { rule: string; title: string; explanation_vi: string; exercise: Pick<Exercise,'id'|'title'|'cefr_level'|'kind'|'topic_id'|'difficulty'> & { topic_title: string | null } };
export type WritingHistoryItem = { id: string; exercise_id: string | null; exercise_title: string; created_at: string; cefr_level: CefrLevel | null;
  topic_id: string | null; topic_title: string | null; kind: ExerciseKind | null; word_count: number; analytics_metadata_source: string;
  rule_result: Feedback['rule_result'] | null; overall_score: number | null; revision_count: number; is_daily: boolean; qualifies: boolean };
export type WritingAnalyticsHistory = { items: WritingHistoryItem[]; total: number; page: number; page_size: number };
export type WritingAnalyticsDetail = { id: string; exercise_id: string | null; exercise_title: string; prompt: string; body: string; created_at: string;
  word_count: number; cefr_level: CefrLevel | null; topic_id: string | null; topic_title: string | null; kind: ExerciseKind | null;
  metadata_source: string; rule_feedback: Feedback | null; is_daily: boolean };
export type WritingReport = { period: 'weekly' | 'monthly'; start_date: string; end_date: string;
  activity: { practice_days: number; completed_exercises: number; submissions: number; total_words: number };
  ai_feedback: { sample_size: number; average_score: number | null; grammar_score: number | null; vocabulary_score: number | null;
    coherence_score: number | null; task_score: number | null; reliable_trend: boolean };
  common_issue: WritingMistake | null; daily_challenges: { completed: number; xp_earned: number; current_streak: number };
  recommendations: WritingRecommendation[] };

export async function getWritingAnalytics(range: AnalyticsRange = '30d') {
  await currentUserId(); const client=getSupabase();
  const [summary,activity,scores,mistakes,cefr,topics,recommendations,weekly,monthly]=await Promise.all([
    client.rpc('englify_writing_progress_summary'), client.rpc('englify_writing_activity_stats',{p_range:range}),
    client.rpc('englify_writing_score_analytics',{p_range:range,p_level:null,p_kind:null}),
    client.rpc('englify_writing_mistake_summary',{p_range:range}), client.rpc('englify_writing_cefr_progress'),
    client.rpc('englify_writing_topic_progress'), client.rpc('englify_writing_recommendations'),
    client.rpc('englify_writing_report',{p_period:'weekly'}), client.rpc('englify_writing_report',{p_period:'monthly'}),
  ]);
  return { summary:dataOrThrow(summary) as WritingProgressSummary, activity:dataOrThrow(activity) as WritingActivity,
    scores:dataOrThrow(scores) as WritingScoreAnalytics, mistakes:dataOrThrow(mistakes) as WritingMistake[],
    cefr:dataOrThrow(cefr) as WritingCefrProgress[], topics:dataOrThrow(topics) as WritingTopicProgress[],
    recommendations:dataOrThrow(recommendations) as WritingRecommendation[], weekly:dataOrThrow(weekly) as WritingReport,
    monthly:dataOrThrow(monthly) as WritingReport };
}
export async function getWritingAnalyticsHistory(filters:{range?:AnalyticsRange;level?:CefrLevel|null;topicId?:string|null;
  kind?:ExerciseKind|null;aiStatus?:'all'|'scored'|'unscored';page?:number;pageSize?:number}={}):Promise<WritingAnalyticsHistory>{
  await currentUserId(); return dataOrThrow(await getSupabase().rpc('englify_writing_analytics_history',{p_range:filters.range??'all',
    p_level:filters.level??null,p_topic_id:filters.topicId??null,p_kind:filters.kind??null,p_ai_status:filters.aiStatus??'all',
    p_page:filters.page??1,p_page_size:filters.pageSize??5})) as WritingAnalyticsHistory;
}
export async function getWritingAnalyticsDetail(submissionId:string):Promise<WritingAnalyticsDetail>{
  await currentUserId(); return dataOrThrow(await getSupabase().rpc('englify_writing_analytics_detail',{p_submission_id:submissionId})) as WritingAnalyticsDetail;
}

export async function getExercises(): Promise<Exercise[]> {
  return (await getWritingCatalog({ pageSize: 50 })).items;
}
export async function getWritingCatalog(filters: WritingFilters = {}): Promise<WritingCatalog> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_writing_library', { p_query: filters.query ?? '', p_level: filters.level ?? null,
    p_topic_id: filters.topicId ?? null, p_kind: filters.kind ?? null, p_page: filters.page ?? 1, p_page_size: filters.pageSize ?? 20 })) as WritingCatalog;
}
export async function getWritingTopics(level: CefrLevel | null): Promise<WritingTopic[]> {
  await currentUserId(); return dataOrThrow(await getSupabase().rpc('englify_writing_topics', { p_level: level })) as WritingTopic[];
}
export async function getWritingLevel(): Promise<CefrLevel> {
  const userId = await currentUserId();
  const row = dataOrThrow(await getSupabase().from('user_preferences').select('writing_cefr_level').eq('user_id', userId).single()) as { writing_cefr_level: CefrLevel };
  return row.writing_cefr_level;
}
export async function setWritingLevel(level: CefrLevel): Promise<CefrLevel> {
  await currentUserId(); return dataOrThrow(await getSupabase().rpc('englify_set_writing_level', { p_level: level })) as CefrLevel;
}
export function recommendExercises(exercises: Exercise[], history: Submission[], limit = 3): Exercise[] {
  const completed = new Set(history.map((item) => item.exercise_id).filter(Boolean));
  const unique = new Map(exercises.map((item) => [item.id, item]));
  return [...unique.values()].sort((left, right) => Number(completed.has(left.id)) - Number(completed.has(right.id))
    || left.difficulty - right.difficulty || left.id.localeCompare(right.id)).slice(0, limit);
}
export async function getWritingHistory(): Promise<Submission[]> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_writing_history', { p_limit: 30 })) as Submission[];
}
export async function getWritingSubmission(submissionId: string): Promise<Submission> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_writing_submission', { p_submission_id: submissionId })) as Submission;
}
export async function getDailyWritingOverview(): Promise<DailyWritingOverview> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_writing_daily_overview')) as DailyWritingOverview;
}
export async function setWritingTimezone(timezone: string): Promise<WritingTimezoneResult> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_set_writing_timezone', { p_timezone: timezone })) as WritingTimezoneResult;
}
export async function submitDailyWriting(assignmentId: string, requestId: string, body: string,
  grammarCheck: boolean): Promise<DailyWritingSubmitResult> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_submit_daily_writing', { p_assignment_id: assignmentId,
    p_request_id: requestId, p_body: body, p_grammar_check: grammarCheck })) as DailyWritingSubmitResult;
}
export async function submitWriting(requestId: string, exerciseId: string, body: string, grammarCheck: boolean): Promise<Submission> {
  await currentUserId();
  const saved = dataOrThrow(await getSupabase().rpc('englify_submit_writing', {
    p_request_id: requestId, p_exercise_id: exerciseId, p_body: body, p_grammar_check: grammarCheck,
  })) as Submission;
  if (!grammarCheck) return saved;
  try {
    const { data, error } = await getSupabase().functions.invoke<{ status: 'available' | 'unavailable' }>(
      'writing-grammar', { body: { submissionId: saved.id } });
    if (error || data?.status !== 'available') return saved;
    return dataOrThrow(await getSupabase().rpc('englify_writing_submission', { p_submission_id: saved.id })) as Submission;
  } catch { return saved; } // Rule feedback and original text already persist.
}

async function functionError(error: unknown, fallback: string): Promise<Error> {
  const context = error && typeof error === 'object' && 'context' in error ? (error as { context?: unknown }).context : null;
  if (context instanceof Response) {
    const payload = await context.clone().json().catch(() => null) as { error?: unknown } | null;
    if (typeof payload?.error === 'string' && payload.error) return new Error(payload.error);
  }
  return new Error(error instanceof Error && error.message ? error.message : fallback);
}

export async function requestWritingCoach(submissionId: string, requestId: string): Promise<WritingAiFeedback> {
  await currentUserId();
  const { data, error } = await getSupabase().functions.invoke<{ feedback?: WritingAiFeedback }>('writing-ai-coach', {
    body: { submissionId, requestId },
  });
  if (error) throw await functionError(error, 'AI writing coach is unavailable.');
  if (!data?.feedback) throw new Error('AI writing coach returned an invalid response.');
  return data.feedback;
}

export async function requestWritingRewrite(submissionId: string, requestId: string, mode: RewriteMode): Promise<WritingAiRewrite> {
  await currentUserId();
  const { data, error } = await getSupabase().functions.invoke<{ rewrite?: WritingAiRewrite }>('writing-ai-rewrite', {
    body: { submissionId, requestId, mode },
  });
  if (error) throw await functionError(error, 'AI rewrite is unavailable.');
  if (!data?.rewrite) throw new Error('AI rewrite returned an invalid response.');
  return data.rewrite;
}

export async function getWritingAiBundle(submissionId: string): Promise<WritingAiBundle> {
  await currentUserId();
  const client = getSupabase();
  const [feedback, rewrites, revisions] = await Promise.all([
    client.from('writing_ai_feedback').select('*').eq('submission_id', submissionId).order('created_at', { ascending: false }),
    client.from('writing_ai_rewrites').select('*').eq('submission_id', submissionId).order('created_at', { ascending: false }),
    client.from('writing_revisions').select('*').eq('submission_id', submissionId).order('revision_number', { ascending: false }),
  ]);
  return { feedback: dataOrThrow(feedback) as WritingAiFeedback[], rewrites: dataOrThrow(rewrites) as WritingAiRewrite[],
    revisions: dataOrThrow(revisions) as WritingRevision[] };
}

export async function createWritingRevision(requestId: string, submissionId: string, revisedText: string,
  rewriteId?: string, aiFeedbackId?: string): Promise<WritingRevision> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_create_writing_revision', { p_request_id: requestId,
    p_submission_id: submissionId, p_revised_text: revisedText, p_rewrite_id: rewriteId ?? null,
    p_ai_feedback_id: aiFeedbackId ?? null })) as WritingRevision;
}
