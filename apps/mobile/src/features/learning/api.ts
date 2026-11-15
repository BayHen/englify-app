import { getSupabase } from '@/auth/supabase';
import { ApiError } from '@/lib/api';
import { currentUserId, dataOrThrow } from '@/lib/supabase-query';

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
export type OfflinePackage = { lesson: LessonDetail; content_version: string };

async function requireSession(accessToken?: string): Promise<void> {
  await currentUserId();
  if (!accessToken) return;
  const { data, error } = await getSupabase().auth.getSession();
  if (error || !data.session || data.session.access_token !== accessToken) {
    throw new ApiError(401, 'Session changed. Sign in again before syncing this lesson.');
  }
}
export async function getJourney(): Promise<JourneyCourse[]> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_journey')) as JourneyCourse[];
}
export async function getJourneySummary(): Promise<JourneySummary> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_journey_summary')) as JourneySummary;
}
export async function getLesson(id: string): Promise<LessonDetail> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_lesson_detail', { p_lesson_id: id })) as LessonDetail;
}
export async function downloadLesson(id: string): Promise<OfflinePackage> {
  await requireSession();
  const [lesson, version] = await Promise.all([
    getSupabase().rpc('englify_lesson_detail', { p_lesson_id: id }),
    getSupabase().rpc('englify_lesson_content_version', { p_lesson_id: id }),
  ]);
  return { lesson: dataOrThrow(lesson) as LessonDetail, content_version: dataOrThrow(version) as string };
}
async function grade(id: string, requestId: string, answers: Record<string, Answer>, contentVersion: string | null): Promise<QuizResult> {
  return dataOrThrow(await getSupabase().rpc('englify_submit_lesson', {
    p_lesson_id: id, p_request_id: requestId, p_answers: answers, p_content_version: contentVersion,
  })) as QuizResult;
}
export async function syncLesson(id: string, requestId: string, contentVersion: string, answers: Record<string, Answer>, accessToken?: string): Promise<QuizResult> {
  await requireSession(accessToken);
  return grade(id, requestId, answers, contentVersion);
}
export async function startLesson(id: string): Promise<JourneyLesson> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_start_lesson', { p_lesson_id: id })) as JourneyLesson;
}
export async function submitLesson(id: string, requestId: string, answers: Record<string, Answer>): Promise<QuizResult> {
  await requireSession();
  return grade(id, requestId, answers, null);
}
export async function getAttempts(id: string): Promise<QuizResult[]> {
  await requireSession();
  const result = await getSupabase().from('lesson_attempts')
    .select('id,correct_count,question_count,passed,result_state,earned_xp,reward_payload,created_at')
    .eq('lesson_id', id).order('created_at', { ascending: false }).limit(50);
  return (dataOrThrow(result) as {
    id: string; correct_count: number; question_count: number; passed: boolean;
    result_state: LessonState; earned_xp: number; reward_payload: GamificationReward[]; created_at: string;
  }[]).map((row) => ({ attempt_id: row.id, correct_count: row.correct_count,
    question_count: row.question_count, passed: row.passed, state: row.result_state,
    earned_xp: row.earned_xp, rewards: row.reward_payload, created_at: row.created_at }));
}
