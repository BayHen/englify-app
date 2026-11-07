import { privateRequest } from '@/auth/api';
import { getSupabase } from '@/auth/supabase';

export type QuestProgress = { id: string; title: string; description: string; period: 'daily' | 'weekly'; progress: number; target: number; reward_xp: number; completed: boolean };
export type BadgeState = { id: string; title: string; description: string; unlocked: boolean; unlocked_at: string | null };
export type RewardState = { id: string; title: string; description: string; xp_cost: number; required_level: number; claimed: boolean; eligible: boolean };
export type GamificationOverview = {
  total_xp: number; level: number; xp_into_level: number; xp_for_next_level: number; available_xp: number;
  quests: QuestProgress[]; badges: BadgeState[]; rewards: RewardState[];
  statistics: { completed_lessons: number; mastered_lessons: number; quiz_attempts: number; correct_answers: number };
};
export type RewardNotification = { id: string; kind: 'xp' | 'level' | 'badge' | 'quest' | 'reward'; title: string; message: string; created_at: string; read_at: string | null };
export type RewardClaimResult = { claim_id: string; reward_id: string; claimed_at: string; newly_claimed: boolean; available_xp: number };

async function token(): Promise<string> {
  const { data, error } = await getSupabase().auth.getSession();
  if (error || !data.session) throw new Error('Session expired. Please sign in again.');
  return data.session.access_token;
}

export async function getGamification(): Promise<GamificationOverview> { return privateRequest('/gamification', await token()); }
export async function getRewardNotifications(): Promise<RewardNotification[]> { return privateRequest('/gamification/notifications', await token()); }
export async function claimReward(id: string): Promise<RewardClaimResult> { return privateRequest(`/gamification/rewards/${encodeURIComponent(id)}/claim`, await token(), 'POST'); }
export async function markRewardRead(id: string): Promise<{ read: boolean }> { return privateRequest(`/gamification/notifications/${encodeURIComponent(id)}/read`, await token(), 'POST'); }
