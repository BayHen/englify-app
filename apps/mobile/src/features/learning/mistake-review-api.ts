import { getSupabase } from '@/auth/supabase';
import { currentUserId, dataOrThrow } from '@/lib/supabase-query';
import type { ArenaAnswer, ArenaKind, ArenaLevel, ArenaQuestion } from './arena-api';

export type MasteryStatus = 'needs_review' | 'learning' | 'improving' | 'mastered';
export type MistakeSummary = { total: number; due: number; needs_review: number; learning: number; improving: number; mastered: number; reviewed: number };
export type MistakeItem = {
  id: string; question: ArenaQuestion; question_source: 'arena' | 'journey'; cefr_level: ArenaLevel; topic: string;
  question_kind: ArenaKind; explanation_vi: string; incorrect_attempts: number; successful_reviews: number;
  incorrect_reviews: number; review_stage: number; mastery_status: MasteryStatus; latest_incorrect_at: string; next_review_at: string;
};
export type MistakeFilters = { page?: number; cefr?: ArenaLevel | null; topic?: string | null; kind?: ArenaKind | null; status?: MasteryStatus | null };
export type MistakePage = { page: number; page_size: number; total: number; items: MistakeItem[] };
export type ReviewResult = { progress_id: string; question: ArenaQuestion; given_answer: ArenaAnswer; correct_answer: ArenaAnswer; correct: boolean; explanation_vi: string; stage_after: number; next_review_at: string };
export type ReviewSession = {
  id: string; status: 'active' | 'completed' | 'abandoned'; requested_count: number; answered_count: number; correct_count: number;
  current_item: MistakeItem | null; review: ReviewResult[] | null; earned_xp: 0;
};
export type WeaknessGroup = { attempts: number; incorrect: number; error_rate: number; reliable: boolean };
export type WeaknessAnalytics = { minimum_sample: number; topics: (WeaknessGroup & { topic: string })[]; levels: (WeaknessGroup & { cefr_level: string })[]; kinds: (WeaknessGroup & { question_kind: string })[] };
export type QuizRecommendation = { kind: 'due_review' | 'weak_topic'; title: string; reason: string; action: 'review' | 'practice'; count?: number; topic?: string; cefr_level?: ArenaLevel };

async function rpc<T>(name: string, params?: Record<string, unknown>): Promise<T> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc(name, params)) as T;
}
export const getMistakeSummary = () => rpc<MistakeSummary>('englify_quiz_mistake_summary');
export const getMistakes = (filters: MistakeFilters = {}) => rpc<MistakePage>('englify_quiz_mistakes', {
  p_page: filters.page ?? 1, p_cefr: filters.cefr ?? null, p_topic: filters.topic ?? null,
  p_kind: filters.kind ?? null, p_status: filters.status ?? null,
});
export const startMistakeReview = (requestId: string, count: 0 | 5 | 10) => rpc<ReviewSession>('englify_quiz_start_review', { p_request_id: requestId, p_count: count });
export const getMistakeReview = (id: string) => rpc<ReviewSession>('englify_quiz_review_session', { p_session: id });
export const submitMistakeReview = (id: string, progressId: string, requestId: string, answer: ArenaAnswer) => rpc<ReviewSession>('englify_quiz_submit_review', { p_session: id, p_progress: progressId, p_request_id: requestId, p_answer: answer });
export const getWeaknessAnalytics = () => rpc<WeaknessAnalytics>('englify_quiz_weakness_analytics');
export const getQuizRecommendations = () => rpc<QuizRecommendation[]>('englify_quiz_recommendations');
