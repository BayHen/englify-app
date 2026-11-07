import { useCallback, useEffect, useState } from 'react';
import { View } from 'react-native';
import { Page, NavLink } from '@/components/page';
import { AchievementBadge, AppButton, AppCard, AppText, EmptyState, ErrorState, LevelBadge, LoadingSkeleton } from '@/ui';
import { AnimatedXPProgress } from './animated-xp-progress';
import { claimReward, getGamification, getRewardNotifications, markRewardRead, type GamificationOverview, type RewardNotification } from './api';

export function RewardsScreen() {
  const [overview, setOverview] = useState<GamificationOverview | null>(null);
  const [notifications, setNotifications] = useState<RewardNotification[]>([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [feedback, setFeedback] = useState('');
  const refresh = useCallback(async () => {
    setError('');
    try {
      const [state, news] = await Promise.all([getGamification(), getRewardNotifications()]);
      setOverview(state); setNotifications(news);
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load rewards.'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { const start = setTimeout(() => { void refresh(); }, 0); return () => clearTimeout(start); }, [refresh]);
  async function claim(id: string) {
    if (busy) return;
    setBusy(id); setError(''); setFeedback('');
    try {
      const result = await claimReward(id);
      setFeedback(result.newly_claimed ? 'Reward unlocked!' : 'You already claimed this reward.');
      await refresh();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not claim reward.'); }
    finally { setBusy(null); }
  }
  async function markRead(id: string) {
    if (busy) return;
    setBusy(id);
    try {
      await markRewardRead(id);
      setNotifications((old) => old.map((item) => item.id === id ? { ...item, read_at: new Date().toISOString() } : item));
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not mark notification read.'); }
    finally { setBusy(null); }
  }
  return <Page eyebrow="YOUR ACHIEVEMENTS" title="Rewards" description="Your earned progress, quests and badges from completed lessons.">
    {loading ? <LoadingSkeleton lines={6} /> : overview ? <>
      <AppCard tone="primary" style={{ gap: 12 }}><LevelBadge level={overview.level} /><AppText variant="heading">{overview.total_xp} lifetime XP</AppText><AnimatedXPProgress value={overview.xp_into_level} max={overview.xp_for_next_level} /><AppText tone="muted">{overview.available_xp} XP available for rewards</AppText></AppCard>
      <AppText variant="heading">Quests</AppText>
      {overview.quests.length ? overview.quests.map((quest) => <AppCard key={quest.id} tone={quest.completed ? 'reward' : 'surface'} style={{ gap: 8 }}><AppText variant="caption" tone="primary">{quest.period.toUpperCase()} · +{quest.reward_xp} XP</AppText><AppText variant="heading">{quest.title}</AppText><AppText tone="muted">{quest.description}</AppText><AppText accessibilityLabel={`${quest.progress} of ${quest.target} lessons, ${quest.completed ? 'completed' : 'in progress'}`}>{quest.progress} / {quest.target} lessons {quest.completed ? '· Complete!' : ''}</AppText></AppCard>) : <EmptyState title="No quests yet" message="New quests will appear when available." />}
      <AppText variant="heading">Badges</AppText>
      {overview.badges.length ? <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 12 }}>{overview.badges.map((badge) => <AchievementBadge key={badge.id} title={badge.title} description={badge.description} unlocked={badge.unlocked} />)}</View> : <EmptyState title="No badges yet" message="Keep learning to unlock badges." />}
      <AppText variant="heading">Reward shop</AppText>
      {overview.rewards.length ? overview.rewards.map((reward) => <AppCard key={reward.id} tone="reward" style={{ gap: 10 }}><AppText variant="heading">{reward.title}</AppText><AppText tone="muted">{reward.description}</AppText><AppText>{reward.xp_cost} XP · Level {reward.required_level}</AppText><AppButton label={reward.claimed ? 'Claimed' : reward.eligible ? 'Claim reward' : 'Not yet eligible'} variant="secondary" disabled={reward.claimed || !reward.eligible} loading={busy === reward.id} onPress={() => { void claim(reward.id); }} /></AppCard>) : <EmptyState title="No rewards available" message="Check again after more rewards are added." />}
      <AppText variant="heading">Learning statistics</AppText>
      <AppCard><AppText>{overview.statistics.completed_lessons} lessons completed · {overview.statistics.mastered_lessons} mastered</AppText><AppText>{overview.statistics.quiz_attempts} quiz attempts · {overview.statistics.correct_answers} correct answers</AppText></AppCard>
      <AppText variant="heading">Notifications</AppText>
      {notifications.length ? notifications.map((item) => <AppCard key={item.id} style={{ gap: 6 }}><AppText variant="label">{item.title}{item.read_at ? '' : ' · New'}</AppText><AppText tone="muted">{item.message}</AppText>{!item.read_at && <AppButton label="Mark as read" variant="ghost" disabled={busy !== null} onPress={() => { void markRead(item.id); }} />}</AppCard>) : <EmptyState title="No notifications" message="Lesson rewards will appear here." />}
    </> : <ErrorState message={error || 'Could not load rewards.'} retry={() => { setLoading(true); void refresh(); }} />}
    {!!feedback && <AppCard tone="reward" accessibilityLabel={feedback}><AppText variant="label">{feedback}</AppText></AppCard>}
    {!!error && overview && <ErrorState message={error} retry={() => { void refresh(); }} />}
    <NavLink href="/journey" label="Go to journey" />
  </Page>;
}
