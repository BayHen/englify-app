import { getSupabase } from '@/auth/supabase';
import { ApiError } from '@/lib/api';
import { currentUserId, dataOrThrow } from '@/lib/supabase-query';

export type LessonState = 'locked' | 'available' | 'in_progress' | 'completed' | 'mastered';
export type JourneyPrerequisite = { id: string; title: string; completed: boolean };
export type JourneyLesson = { id: string; title: string; objective: string; position: number; state: LessonState;
  kind?: 'lesson' | 'checkpoint'; is_required?: boolean; estimated_minutes?: number; exercise_count?: number;
  xp_reward?: number; passing_percent?: number; prerequisites?: JourneyPrerequisite[]; locked_reason?: string | null };
export type JourneyUnit = { id: string; title: string; position: number; lessons: JourneyLesson[]; is_required?: boolean;
  required_lessons?: number; completed_required_lessons?: number; progress_percent?: number };
export type JourneyChapter = { id: string; title: string; description: string; position: number;
  compatibility: boolean; units: JourneyUnit[] };
export type JourneyCourse = { id: string; title: string; cefr_level?: string | null; curriculum_version?: number;
  continue_lesson?: JourneyLesson | null; chapters?: JourneyChapter[]; units: JourneyUnit[] };
export type Question = { id: string; kind: 'multiple_choice' | 'fill_blank' | 'matching' | 'listening' | 'grammar'; prompt: string; payload: Record<string, unknown>; options: { id: string; text: string }[]; hint_en?: string | null; hint_vi?: string | null };
export type LessonBlockType = 'introduction' | 'objective' | 'theory' | 'example' | 'vocabulary' | 'grammar' | 'dialogue' | 'audio' | 'practice' | 'summary';
export type LessonBlock = { id: string; type: LessonBlockType; position: number; content: { title?: string; text_en?: string; text_vi?: string; word?: string; part_of_speech?: string; meaning_vi?: string; example_en?: string; example_vi?: string; pronunciation?: string; audio_url?: string; lines?: { speaker: string; text_en: string; text_vi?: string }[]; question_id?: string } };
export type LessonNote = { id: string; block_id: string | null; note: string; updated_at: string };
export type LessonPersonal = { resume: { block_id: string; answers: Record<string, Answer>; updated_at: string } | null; bookmarked: boolean; notes: LessonNote[] };
export type LessonDetail = Omit<JourneyLesson, 'position'> & { position?: number; cefr_level?: string | null; topic?: string; revision_id?: string; content_version?: string; blocks?: LessonBlock[]; personal?: LessonPersonal; items: { kind: 'reading' | 'tip'; body: { text?: string } }[]; questions: Question[] };
export type GamificationReward = { kind: 'xp' | 'level' | 'badge' | 'quest' | 'reward'; title: string; message: string; amount: number };
export type QuestionReview = { question_id: string; is_correct: boolean; learner_answer: unknown; correct_answer: unknown; explanation_en: string | null; explanation_vi: string | null };
export type QuizResult = { attempt_id: string; correct_count: number; question_count: number; passed: boolean; state: LessonState; earned_xp: number; rewards: GamificationReward[]; created_at: string; newly_unlocked?: JourneyLesson[]; revision_id?: string; review?: QuestionReview[] };
export type JourneySummary = { xp_total: number; level: number; xp_into_level: number; xp_for_next_level: number; completed_lessons: number; total_lessons: number };
export type Answer = string | Record<string, string>;
export type OfflinePackage = { lesson: LessonDetail; content_version: string };
export type JourneySkill = { attempts: number; last_practiced_at: string | null; estimated_percent: number | null; data_sufficient: boolean };
export type JourneyRecommendation = { lesson_id: string; title: string; cefr_level: string | null; target_skill: string;
  reason_code: 'continue_in_progress' | 'eligible_next' | 'weakness_review' | 'resume_after_inactivity'; reason_vi: string; destination: string };
export type JourneyLearningProfile = { selected_cefr: string | null; recommended_cefr: string | null; goal: string | null;
  daily_minutes: number; skills: Record<string, JourneySkill>; recommendations: JourneyRecommendation[]; insight: string };
export type PlacementQuestion = { id: string; skill: 'grammar' | 'vocabulary' | 'reading'; cefr_level: string; prompt: string; options: string[] };
export type PlacementSession = { session_id: string; questions: PlacementQuestion[] };
export type PlacementResult = { recommended_cefr: string; confidence: 'low' | 'medium' | 'high'; evidence: Record<string, unknown>; disclaimer: string };
export type DailyPlanItem = { id: string; kind: string; lesson_id: string | null; title: string; estimated_minutes: number; reason_code: string; completed_at: string | null };
export type DailyPlan = { id: string; local_date: string; items: DailyPlanItem[] };
export type JourneyGamification = { total_xp: number; level: number; xp_into_level: number; xp_for_next_level: number; learning_streak: { current_streak: number; longest_streak: number; last_activity_date: string | null; total_active_days: number }; quests: { id: string; title: string; description: string; period: 'daily' | 'weekly'; progress: number; target: number; reward_xp: number; completed: boolean }[]; badges: { id: string; title: string; description: string; unlocked: boolean; unlocked_at: string | null }[]; recent_milestones: { milestone_type: string; milestone_id: string; reward_xp: number; completed_at: string }[] };

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
export async function getJourneyLearningProfile(): Promise<JourneyLearningProfile> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_journey_learning_profile')) as JourneyLearningProfile;
}
export async function getJourneyDailyPlan(refresh = false): Promise<DailyPlan> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_journey_daily_plan', { p_timezone: 'Asia/Ho_Chi_Minh', p_refresh: refresh })) as DailyPlan;
}
export async function getJourneyGamification(): Promise<JourneyGamification> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_journey_gamification')) as JourneyGamification;
}
export async function startPlacementTest(): Promise<PlacementSession> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_start_journey_placement_test')) as PlacementSession;
}
export async function submitPlacementAnswer(sessionId: string, questionId: string, selectedIndex: number): Promise<void> {
  await requireSession();
  dataOrThrow(await getSupabase().rpc('englify_submit_journey_placement_answer', {
    p_session: sessionId, p_question: questionId, p_selected_index: selectedIndex,
  }));
}
export async function finalizePlacementTest(sessionId: string): Promise<PlacementResult> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_finalize_journey_placement_test', { p_session: sessionId })) as PlacementResult;
}
export async function getLesson(id: string): Promise<LessonDetail> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_lesson_detail', { p_lesson_id: id })) as LessonDetail;
}
export async function saveLessonResume(lessonId: string, revisionId: string, blockId: string, answers: Record<string, Answer>): Promise<void> {
  await requireSession();
  dataOrThrow(await getSupabase().rpc('englify_save_lesson_resume', { p_lesson: lessonId, p_revision: revisionId, p_block: blockId, p_answers: answers }));
}
export async function toggleLessonBookmark(lessonId: string, blockId: string | null = null): Promise<{ bookmarked: boolean }> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_toggle_lesson_bookmark', { p_lesson: lessonId, p_block: blockId })) as { bookmarked: boolean };
}
export async function saveLessonNote(lessonId: string, blockId: string, note: string): Promise<LessonNote> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_save_lesson_note', { p_lesson: lessonId, p_block: blockId, p_note: note })) as LessonNote;
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
export async function submitCheckpoint(id: string, requestId: string, answers: Record<string, Answer>): Promise<QuizResult> {
  await requireSession();
  return dataOrThrow(await getSupabase().rpc('englify_submit_checkpoint', { p_checkpoint: id, p_request_id: requestId, p_answers: answers, p_content_version: null })) as QuizResult;
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
