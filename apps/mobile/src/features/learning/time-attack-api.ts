import { getSupabase } from '@/auth/supabase';
import { currentUserId, dataOrThrow } from '@/lib/supabase-query';
import type { ArenaAnswer, ArenaLevel, ArenaQuestion, ArenaReview } from './arena-api';
import { captureServerClock, type ServerClock } from './time-attack-clock';
export type TimeAttackDifficulty = 'easy' | 'normal' | 'hard';
export type TimeAttackRule = { difficulty: TimeAttackDifficulty; version: number; question_count: number; time_limit_seconds: number; initial_lives: number; base_points: number };
export type TimeAttackReceipt = { request_id: string; question_id: string; correct: boolean; combo: number; multiplier_bps: number; speed_bonus: number; points: number };
export type TimeAttackSession = { id: string; difficulty: TimeAttackDifficulty; rules_version: number; cefr_level: ArenaLevel;
  status: 'active' | 'completed' | 'expired' | 'abandoned'; completion_reason: 'all_questions' | 'time_expired' | 'no_lives' | 'abandoned' | null;
  question_count: number; time_limit_seconds: number; initial_lives: number; remaining_lives: number; answered_count: number; correct_count: number;
  combo: number; max_combo: number; score: number; started_at: string; expires_at: string; server_now: string; question_started_at: string | null;
  completed_at: string | null; duration_ms: number | null; accuracy: number; earned_xp: number; is_personal_best: boolean;
  current_question: ArenaQuestion | null; last_answer: TimeAttackReceipt | null;
  review: (ArenaReview & { points: number; speed_bonus: number; elapsed_ms: number })[] | null };
export type TimeAttackSnapshot = { session: TimeAttackSession; clock: ServerClock };
export type TimeAttackHistoryItem = Pick<TimeAttackSession, 'id'|'difficulty'|'rules_version'|'cefr_level'|'status'|'completion_reason'|'score'|'max_combo'|'correct_count'|'answered_count'|'question_count'|'started_at'|'completed_at'|'duration_ms'>;
export type TimeAttackHistory = { items: TimeAttackHistoryItem[]; page: number; total: number };
export type TimeAttackRecords = { rules: TimeAttackRule[] | null; total_sessions: number; completed_sessions: number; highest_combo: number;
  records: { difficulty: TimeAttackDifficulty; rules_version: number; sessions: number; highest_score: number; best_accuracy: number;
    highest_combo: number; fastest_completion_ms: number | null; best_session_id: string | null }[] };
async function sessionRpc(name: string, args: Record<string, unknown>): Promise<TimeAttackSnapshot> {
  await currentUserId(); const sentAt = performance.now();
  const session = dataOrThrow(await getSupabase().rpc(name, args)) as TimeAttackSession;
  return { session, clock: captureServerClock(session.expires_at, session.server_now, sentAt, performance.now()) };
}
export function startTimeAttack(requestId: string, level: ArenaLevel, difficulty: TimeAttackDifficulty) {
  return sessionRpc('englify_time_attack_start', { p_request_id: requestId, p_level: level, p_difficulty: difficulty });
}
export function getTimeAttack(id: string) { return sessionRpc('englify_time_attack_session', { p_session_id: id }); }
export function answerTimeAttack(id: string, questionId: string, requestId: string, answer: ArenaAnswer) {
  return sessionRpc('englify_time_attack_answer', { p_session_id: id, p_question_id: questionId, p_request_id: requestId, p_answer: answer });
}
export function finishTimeAttack(id: string, abandon = false) { return sessionRpc('englify_time_attack_finish', { p_session_id: id, p_abandon: abandon }); }
export async function getTimeAttackHistory(page = 1): Promise<TimeAttackHistory> {
  await currentUserId(); return dataOrThrow(await getSupabase().rpc('englify_time_attack_history', { p_page: page })) as TimeAttackHistory;
}
export async function getTimeAttackRecords(): Promise<TimeAttackRecords> {
  await currentUserId(); return dataOrThrow(await getSupabase().rpc('englify_time_attack_records')) as TimeAttackRecords;
}
