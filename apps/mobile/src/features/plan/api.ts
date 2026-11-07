import { privateRequest } from '@/auth/api';
import { getSupabase } from '@/auth/supabase';

export type PlanGoal = 'conversation' | 'travel' | 'work' | 'exams';
export type PlanLevel = 'beginner' | 'intermediate' | 'advanced';
export type PlanPreferences = { learning_goal: PlanGoal; initial_proficiency: PlanLevel; daily_goal_minutes: number; preferred_topics: string[] };
export type PlanTask = { id: string; kind: 'lesson' | 'vocabulary' | 'review' | 'speaking' | 'writing'; title: string; scheduled_on: string; original_date: string; duration_minutes: number; target_count: number | null; topic: string | null; lesson_id: string | null; status: 'pending' | 'completed'; lesson_state: string | null };
export type LearningPlan = { id: string; starts_on: string; algorithm_version: number; preferences: PlanPreferences; tasks: PlanTask[]; completed_count: number; total_count: number; weekly_minutes: number };

async function token(): Promise<string> {
  const { data, error } = await getSupabase().auth.getSession();
  if (error || !data.session) throw new Error('Session expired. Please sign in again.');
  return data.session.access_token;
}
export async function getPlan(): Promise<LearningPlan> { return privateRequest('/learning-plan', await token()); }
export async function regeneratePlan(): Promise<LearningPlan> { return privateRequest('/learning-plan/regenerate', await token(), 'POST'); }
export async function reschedulePlan(): Promise<LearningPlan> { return privateRequest('/learning-plan/reschedule', await token(), 'POST'); }
export async function savePlanPreferences(value: PlanPreferences): Promise<LearningPlan> { return privateRequest('/learning-plan/preferences', await token(), 'PUT', value); }
export async function completePlanTask(id: string): Promise<LearningPlan> { return privateRequest(`/learning-plan/tasks/${encodeURIComponent(id)}/complete`, await token(), 'POST'); }
