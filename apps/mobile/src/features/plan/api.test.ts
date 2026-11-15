import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { completePlanTask, getPlan, regeneratePlan, reschedulePlan, savePlanPreferences, type PlanPreferences } from './api';

const state = vi.hoisted(() => ({ client: null as unknown }));
vi.mock('@/auth/supabase', () => ({ getSupabase: () => state.client }));
const privateRequest = vi.hoisted(() => vi.fn());
vi.mock('@/auth/api', () => ({ privateRequest }));
const plan: { id: string; tasks: never[]; preferences: PlanPreferences } = { id: 'plan-1', tasks: [], preferences: { learning_goal: 'conversation', initial_proficiency: 'beginner', daily_goal_minutes: 10, preferred_topics: [] } };
beforeEach(() => { state.client = null; privateRequest.mockReset(); vi.stubEnv('EXPO_PUBLIC_SUPABASE_PLAN_ENABLED', 'true'); });
afterEach(() => vi.unstubAllEnvs());

describe('Supabase learning plan client', () => {
  it('routes all actions through the authenticated Edge Function', async () => {
    const invoke = vi.fn().mockResolvedValue({ data: plan, error: null });
    state.client = { auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) }, functions: { invoke } };
    await getPlan(); await regeneratePlan(); await reschedulePlan();
    await savePlanPreferences(plan.preferences); await completePlanTask('task-1');
    expect(invoke.mock.calls.map((call) => call[1].body)).toEqual([
      { action: 'get' }, { action: 'regenerate' }, { action: 'reschedule' },
      { action: 'preferences', preferences: plan.preferences }, { action: 'complete', taskId: 'task-1' },
    ]);
    expect(invoke.mock.calls.every((call) => call[0] === 'study-plan')).toBe(true);
  });
  it('does not call the Edge Function without a session', async () => {
    const invoke = vi.fn();
    state.client = { auth: { getSession: async () => ({ data: { session: null }, error: null }) }, functions: { invoke } };
    await expect(getPlan()).rejects.toMatchObject({ status: 401 });
    expect(invoke).not.toHaveBeenCalled();
  });
  it('reports an actionable onboarding failure without inventing a plan', async () => {
    const invoke = vi.fn().mockResolvedValue({ data: null, error: { context: new Response('{"error":"Complete onboarding first."}', { status: 409 }) } });
    state.client = { auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) }, functions: { invoke } };
    await expect(getPlan()).rejects.toMatchObject({ status: 409, message: 'Complete onboarding first.' });
  });
  it('preserves the existing plan service until the Edge Function is deployed', async () => {
    vi.stubEnv('EXPO_PUBLIC_SUPABASE_PLAN_ENABLED', 'false');
    privateRequest.mockResolvedValue(plan);
    const invoke = vi.fn();
    state.client = { auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' }, access_token: 'session-token' } }, error: null }) }, functions: { invoke } };
    await expect(getPlan()).resolves.toBe(plan);
    expect(privateRequest).toHaveBeenCalledWith('/learning-plan', 'session-token');
    expect(invoke).not.toHaveBeenCalled();
  });
});
