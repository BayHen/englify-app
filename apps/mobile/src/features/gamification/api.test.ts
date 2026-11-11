import { beforeEach, describe, expect, it, vi } from 'vitest';
import { claimReward, getGamification, getRewardNotifications, markRewardRead } from './api';

const state = vi.hoisted(() => ({ client: null as unknown }));
vi.mock('@/auth/supabase', () => ({ getSupabase: () => state.client }));
const auth = { getSession: async () => ({ data: { session: { user: { id: 'user-1' } } }, error: null }) };
beforeEach(() => { state.client = null; });

describe('Supabase gamification client', () => {
  it('reads trusted server-owned totals and calls protected reward RPCs', async () => {
    const overview = { total_xp: 120, level: 2, quests: [], badges: [], rewards: [], statistics: {} };
    const rpc = vi.fn().mockResolvedValueOnce({ data: overview, error: null, status: 200 })
      .mockResolvedValueOnce({ data: { claim_id: 'claim-1', newly_claimed: true }, error: null, status: 200 })
      .mockResolvedValueOnce({ data: { read: true }, error: null, status: 200 });
    state.client = { auth, rpc };
    await expect(getGamification()).resolves.toBe(overview);
    await expect(claimReward('reward-1')).resolves.toMatchObject({ claim_id: 'claim-1' });
    await expect(markRewardRead('notice-1')).resolves.toEqual({ read: true });
    expect(rpc.mock.calls).toEqual([
      ['englify_gamification_overview'], ['englify_claim_reward', { p_reward_id: 'reward-1' }],
      ['englify_mark_reward_read', { p_notification_id: 'notice-1' }],
    ]);
  });
  it('queries only own notifications through RLS', async () => {
    const builder = { select: vi.fn(), eq: vi.fn(), order: vi.fn(), limit: vi.fn(),
      then: (resolve: (result: unknown) => unknown) => Promise.resolve({ data: [{ id: 'notice-1' }], error: null, status: 200 }).then(resolve) };
    for (const key of ['select', 'eq', 'order', 'limit'] as const) builder[key].mockReturnValue(builder);
    const from = vi.fn().mockReturnValue(builder);
    state.client = { auth, from };
    await expect(getRewardNotifications()).resolves.toEqual([{ id: 'notice-1' }]);
    expect(from).toHaveBeenCalledWith('reward_notifications');
    expect(builder.eq).toHaveBeenCalledWith('user_id', 'user-1');
    expect(builder.limit).toHaveBeenCalledWith(50);
  });
  it('rejects expired sessions before contacting RPC', async () => {
    const rpc = vi.fn();
    state.client = { auth: { getSession: async () => ({ data: { session: null }, error: null }) }, rpc };
    await expect(getGamification()).rejects.toMatchObject({ status: 401 });
    expect(rpc).not.toHaveBeenCalled();
  });
});