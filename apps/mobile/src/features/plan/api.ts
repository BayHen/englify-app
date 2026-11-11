import { getSupabase } from '@/auth/supabase';
import { privateRequest } from '@/auth/api';
import { ApiError } from '@/lib/api';
import { currentUserId } from '@/lib/supabase-query';

export type PlanGoal = 'conversation' | 'travel' | 'work' | 'exams';
export type PlanLevel = 'beginner' | 'intermediate' | 'advanced';
export type PlanPreferences = { learning_goal: PlanGoal; initial_proficiency: PlanLevel; daily_goal_minutes: number; preferred_topics: string[] };
export type PlanTask = { id: string; kind: 'lesson' | 'vocabulary' | 'review' | 'speaking' | 'writing'; title: string; scheduled_on: string; original_date: string; duration_minutes: number; target_count: number | null; topic: string | null; lesson_id: string | null; status: 'pending' | 'completed'; lesson_state: string | null };
export type LearningPlan = { id: string; starts_on: string; algorithm_version: number; preferences: PlanPreferences; tasks: PlanTask[]; completed_count: number; total_count: number; weekly_minutes: number };

async function planAction(action: 'get' | 'regenerate' | 'reschedule' | 'preferences' | 'complete', values: Record<string, unknown> = {}): Promise<LearningPlan> {
  await currentUserId();
  // Keep the existing plan service active until this function is deployed to the configured project.
  if (process.env.EXPO_PUBLIC_SUPABASE_PLAN_ENABLED !== 'true') {
    const { data } = await getSupabase().auth.getSession();
    const token = data.session?.access_token;
    if (!token) throw new ApiError(401, 'Session expired. Please sign in again.');
    if (action === 'get') return privateRequest('/learning-plan', token);
    if (action === 'regenerate') return privateRequest('/learning-plan/regenerate', token, 'POST');
    if (action === 'reschedule') return privateRequest('/learning-plan/reschedule', token, 'POST');
    if (action === 'preferences') return privateRequest('/learning-plan/preferences', token, 'PUT', values.preferences);
    return privateRequest(`/learning-plan/tasks/${encodeURIComponent(String(values.taskId))}/complete`, token, 'POST');
  }
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
