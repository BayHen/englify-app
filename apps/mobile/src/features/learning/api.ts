import { privateRequest } from '@/auth/api';
import { getSupabase } from '@/auth/supabase';

export type LessonState = 'locked' | 'available' | 'in_progress' | 'completed' | 'mastered';
export type JourneyLesson = { id: string; title: string; objective: string; position: number; state: LessonState };
export type JourneyUnit = { id: string; title: string; position: number; lessons: JourneyLesson[] };
export type JourneyCourse = { id: string; title: string; units: JourneyUnit[] };
export type Question = { id: string; kind: 'multiple_choice' | 'fill_blank' | 'matching' | 'listening' | 'grammar'; prompt: string; payload: Record<string, unknown>; options: { id: string; text: string }[] };
export type LessonDetail = { id: string; title: string; objective: string; state: LessonState; items: { kind: 'reading' | 'tip'; body: { text?: string } }[]; questions: Question[] };
export type GamificationReward = { kind: 'xp' | 'level' | 'badge' | 'quest' | 'reward'; title: string; message: string; amount: number };
export type QuizResult = { attempt_id: string; correct_count: number; question_count: number; passed: boolean; state: LessonState; earned_xp: number; rewards: GamificationReward[]; created_at: string };
export type JourneySummary = { xp_total: number; level: number; xp_into_level: number; xp_for_next_level: number; completed_lessons: number; total_lessons: number };
export type Answer = string | Record<string, string>;

async function token(): Promise<string> {
  const { data, error } = await getSupabase().auth.getSession();
  if (error || !data.session) throw new Error('Session expired. Please sign in again.');
  return data.session.access_token;
}
export async function getJourney(): Promise<JourneyCourse[]> { return privateRequest('/journey', await token()); }
export async function getJourneySummary(): Promise<JourneySummary> { return privateRequest('/journey/summary', await token()); }
export async function getLesson(id: string): Promise<LessonDetail> { return privateRequest(`/lessons/${encodeURIComponent(id)}`, await token()); }
export async function startLesson(id: string): Promise<JourneyLesson> { return privateRequest(`/lessons/${encodeURIComponent(id)}/start`, await token(), 'POST'); }
export async function submitLesson(id: string, requestId: string, answers: Record<string, Answer>): Promise<QuizResult> { return privateRequest(`/lessons/${encodeURIComponent(id)}/submit`, await token(), 'POST', { request_id: requestId, answers }); }
export async function getAttempts(id: string): Promise<QuizResult[]> { return privateRequest(`/lessons/${encodeURIComponent(id)}/attempts`, await token()); }
