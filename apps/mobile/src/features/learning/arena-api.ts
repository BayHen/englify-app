import { getSupabase } from '@/auth/supabase';
import { currentUserId, dataOrThrow, errorOrThrow } from '@/lib/supabase-query';

export type ArenaLevel = 'A1' | 'A2' | 'B1' | 'B2' | 'C1';
export type ArenaKind = 'multiple_choice' | 'fill_blank' | 'matching' | 'grammar_correction' | 'sentence_order' | 'reading';
export type ArenaTopic = 'grammar' | 'vocabulary' | 'reading' | 'everyday' | 'business' | 'travel' | 'sentence_structure' | 'phrasal_verbs' | 'idioms';
export type ArenaItem = { id: string; text: string };
export type ArenaAnswer = string | string[] | Record<string, string>;
export type ArenaConfig = { level: ArenaLevel; topic: ArenaTopic | null; kind: ArenaKind | null; count: 5 | 10 | 15 | 20; difficulty: number | null };
export type ArenaGroup = { cefr_level: ArenaLevel; topic: ArenaTopic; kind: ArenaKind; difficulty: number; available: number };
export type ArenaCatalog = { groups: ArenaGroup[]; daily_reward_xp: number; reward_threshold: number };
export type ArenaQuestion = { id: string; kind: ArenaKind; topic: ArenaTopic; cefr_level: ArenaLevel; difficulty: number;
  prompt: string; passage: string | null; options: ArenaItem[]; left_items: ArenaItem[]; right_items: ArenaItem[] };
export type ArenaReview = { question: ArenaQuestion; given_answer: ArenaAnswer; correct_answer: ArenaAnswer; correct: boolean; explanation_vi: string };
export type ArenaReportReason = 'incorrect_answer' | 'unclear' | 'grammar_error' | 'wrong_cefr' | 'duplicate' | 'other';
export type ArenaAttempt = { id: string; cefr_level: ArenaLevel; topic: ArenaTopic | null; kind: ArenaKind | null; difficulty: number | null;
  question_count: number; status: 'active' | 'completed' | 'abandoned'; started_at: string; completed_at: string | null;
  correct_count: number | null; accuracy: number | null; duration_seconds: number | null; earned_xp: number };
export type ArenaSession = ArenaAttempt & { questions: ArenaQuestion[]; result: { review: ArenaReview[]; review_topics: ArenaTopic[] } | null };
export type ArenaHistory = { items: ArenaAttempt[]; page: number; total: number };

export async function getArenaCatalog(): Promise<ArenaCatalog> {
  await currentUserId(); return dataOrThrow(await getSupabase().rpc('englify_arena_catalog')) as ArenaCatalog;
}
export async function startArena(requestId: string, config: ArenaConfig): Promise<ArenaSession> {
  await currentUserId(); return dataOrThrow(await getSupabase().rpc('englify_arena_start', {
    p_request_id: requestId, p_level: config.level, p_topic: config.topic, p_kind: config.kind,
    p_count: config.count, p_difficulty: config.difficulty,
  })) as ArenaSession;
}
export async function getArenaSession(id: string): Promise<ArenaSession> {
  await currentUserId(); return dataOrThrow(await getSupabase().rpc('englify_arena_session', { p_session_id: id })) as ArenaSession;
}
export async function submitArena(id: string, answers: Record<string, ArenaAnswer>): Promise<ArenaSession> {
  await currentUserId(); return dataOrThrow(await getSupabase().rpc('englify_arena_submit', { p_session_id: id, p_answers: answers })) as ArenaSession;
}
export async function endArena(id: string): Promise<void> {
  await currentUserId(); errorOrThrow(await getSupabase().rpc('englify_arena_end', { p_session_id: id }));
}
export async function getArenaHistory(page = 1): Promise<ArenaHistory> {
  await currentUserId(); return dataOrThrow(await getSupabase().rpc('englify_arena_history', { p_page: page })) as ArenaHistory;
}
export async function reportArenaQuestion(sessionId: string, questionId: string, reason: ArenaReportReason, details = ''): Promise<void> {
  await currentUserId(); errorOrThrow(await getSupabase().rpc('englify_report_arena_question', { p_session: sessionId, p_question: questionId, p_reason: reason, p_details: details }));
}
