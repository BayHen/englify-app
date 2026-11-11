import { getSupabase } from '@/auth/supabase';
import { currentUserId, dataOrThrow } from '@/lib/supabase-query';

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

export async function getGamification(): Promise<GamificationOverview> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_gamification_overview')) as GamificationOverview;
}
export async function getRewardNotifications(): Promise<RewardNotification[]> {
  const userId = await currentUserId();
  return dataOrThrow(await getSupabase().from('reward_notifications')
    .select('id,kind,title,message,created_at,read_at').eq('user_id', userId)
    .order('created_at', { ascending: false }).order('id', { ascending: false }).limit(50)) as RewardNotification[];
}
export async function claimReward(id: string): Promise<RewardClaimResult> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_claim_reward', { p_reward_id: id })) as RewardClaimResult;
}
export async function markRewardRead(id: string): Promise<{ read: boolean }> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_mark_reward_read', { p_notification_id: id })) as { read: boolean };
}