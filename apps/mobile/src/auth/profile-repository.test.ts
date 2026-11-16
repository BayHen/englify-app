import { beforeEach, describe, expect, it, vi } from 'vitest';
import { completeOnboarding, readProfile, updateOwnPreferences, updateOwnProfile } from './profile-repository';

const state = vi.hoisted(() => ({ client: null as unknown }));
vi.mock('./supabase', () => ({ getSupabase: () => state.client }));

function row(data: unknown) {
  const builder = { select: vi.fn(), eq: vi.fn(), maybeSingle: vi.fn() };
  builder.select.mockReturnValue(builder);
  builder.eq.mockReturnValue(builder);
  builder.maybeSingle.mockResolvedValue({ data, error: null, status: 200 });
  return builder;
}

function updatedRow(data: unknown, error: { message: string } | null = null, status = 200) {
  const builder = { update: vi.fn(), eq: vi.fn(), select: vi.fn(), maybeSingle: vi.fn() };
  builder.update.mockReturnValue(builder);
  builder.eq.mockReturnValue(builder);
  builder.select.mockReturnValue(builder);
  builder.maybeSingle.mockResolvedValue({ data, error, status });
  return builder;
}

beforeEach(() => { state.client = null; });

describe('Supabase profile repository', () => {
  it('returns an explicit missing onboarding preference for a new account', async () => {
    const profile = row({ id: 'user-1', display_name: 'Learner', avatar_url: null });
    const preferences = row(null);
    const from = vi.fn().mockReturnValueOnce(profile).mockReturnValueOnce(preferences);
    state.client = { auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) }, from };
    await expect(readProfile('user-1')).resolves.toMatchObject({ id: 'user-1', preferences: null });
    expect(from).toHaveBeenCalledWith('profiles');
    expect(from).toHaveBeenCalledWith('user_preferences');
  });

  it('rejects a stale account identity before reading private rows', async () => {
    const from = vi.fn();
    state.client = { auth: { getSession: async () => ({ data: { session: { user: { id: 'user-2' } } }, error: null }) }, from };
    await expect(readProfile('user-1')).rejects.toMatchObject({ status: 401 });
    expect(from).not.toHaveBeenCalled();
  });

  it('uses the server-owned onboarding RPC and re-reads the profile', async () => {
    const from = vi.fn().mockReturnValueOnce(row({ id: 'user-1', display_name: 'Learner' }))
      .mockReturnValueOnce(row({ learning_goal: 'travel', daily_goal_minutes: 15 }));
    const rpc = vi.fn().mockResolvedValue({ data: null, error: null, status: 204 });
    state.client = { auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) }, from, rpc };
    await completeOnboarding({ learning_goal: 'travel', initial_proficiency: 'beginner', daily_goal_minutes: 15 });
    expect(rpc).toHaveBeenCalledWith('englify_save_onboarding', {
      p_learning_goal: 'travel', p_initial_proficiency: 'beginner', p_daily_goal_minutes: 15,
    });
  });

  it('rejects another account avatar path before any write', async () => {
    const from = vi.fn();
    state.client = { auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) }, from };
    await expect(updateOwnProfile({ avatar_url: 'user-2/foreign.jpg' })).rejects.toMatchObject({ status: 422 });
    expect(from).not.toHaveBeenCalled();
  });

  it('updates owned preferences and restores the saved values', async () => {
    const mutation = updatedRow({ user_id: 'user-1' });
    const from = vi.fn().mockReturnValueOnce(mutation)
      .mockReturnValueOnce(row({ id: 'user-1', display_name: 'Learner' }))
      .mockReturnValueOnce(row({ learning_goal: 'work', current_cefr: 'B2', initial_proficiency: 'intermediate', daily_goal_minutes: 20, preferred_accent: 'en-GB', interface_language: 'vi' }));
    state.client = { auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) }, from };
    await expect(updateOwnPreferences({ learning_goal: 'work', current_cefr: 'B2', daily_goal_minutes: 20, preferred_accent: 'en-GB', interface_language: 'vi' }))
      .resolves.toMatchObject({ preferences: { learning_goal: 'work', current_cefr: 'B2', interface_language: 'vi' } });
    expect(mutation.update).toHaveBeenCalledWith(expect.objectContaining({ initial_proficiency: 'intermediate', interface_language: 'vi' }));
  });

  it('reports a missing preference row as a conflict instead of a generic API failure', async () => {
    const mutation = updatedRow(null);
    state.client = { auth: { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) }, from: vi.fn().mockReturnValue(mutation) };
    await expect(updateOwnPreferences({ interface_language: 'vi' })).rejects.toMatchObject({ status: 409 });
  });
});
