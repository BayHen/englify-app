import { getSupabase } from '@/auth/supabase';
import { ApiError } from '@/lib/api';
import { currentUserId } from '@/lib/supabase-query';

export type PlanGoal = 'conversation' | 'travel' | 'work' | 'exams';
export type PlanLevel = 'beginner' | 'intermediate' | 'advanced';
export type PlanPreferences = { learning_goal: PlanGoal; initial_proficiency: PlanLevel; daily_goal_minutes: number; preferred_topics: string[] };
export type PlanTask = { id: string; kind: 'lesson' | 'vocabulary' | 'review' | 'speaking' | 'writing'; title: string; scheduled_on: string; original_date: string; duration_minutes: number; target_count: number | null; topic: string | null; lesson_id: string | null; status: 'pending' | 'completed'; lesson_state: string | null };
export type LearningPlan = { id: string; starts_on: string; algorithm_version: number; preferences: PlanPreferences; tasks: PlanTask[]; completed_count: number; total_count: number; weekly_minutes: number };

async function planAction(action: 'get' | 'regenerate' | 'reschedule' | 'preferences' | 'complete', values: Record<string, unknown> = {}): Promise<LearningPlan> {
  await currentUserId();
  const { data, error } = await getSupabase().functions.invoke<LearningPlan>('study-plan', { body: { action, ...values } });
  if (error) {
    const response = 'context' in error && error.context instanceof Response ? error.context : null;
    const detail = response ? await response.clone().json().catch(() => null) as { error?: string } | null : null;
    throw new ApiError(response?.status ?? 0, detail?.error ?? (response ? 'Learning plan request failed.' : 'Cannot reach the learning plan service.'));
  }
  if (!data || !Array.isArray(data.tasks) || !data.preferences || typeof data.id !== 'string') {
    throw new ApiError(502, 'Learning plan service returned invalid data.');
  }
  return data;
}
export const getPlan = () => planAction('get');
export const regeneratePlan = () => planAction('regenerate');
export const reschedulePlan = () => planAction('reschedule');
export const savePlanPreferences = (preferences: PlanPreferences) => planAction('preferences', { preferences });
export const completePlanTask = (taskId: string) => planAction('complete', { taskId });
