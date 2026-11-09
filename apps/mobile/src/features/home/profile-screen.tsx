import { useCallback, useState } from 'react';
import { router, useFocusEffect, type Href } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, View } from 'react-native';
import { Page } from '@/components/page';
import { useAuth } from '@/auth/provider';
import { useAppPalette } from '@/constants/app-theme';
import { useAppStore, type ThemeMode } from '@/state/app-store';
import { AppButton, AppText, ErrorState, LoadingSkeleton } from '@/ui';
import { getGamification, type GamificationOverview } from '@/features/gamification/api';
import { ProfileAvatar } from '@/features/profile/profile-avatar';

const modes: { value: ThemeMode; label: string }[] = [{ value: 'system', label: 'System' }, { value: 'light', label: 'Light' }, { value: 'dark', label: 'Dark' }];

export function ProfileScreen({ preview }: { preview?: GamificationOverview }) {
  const { profile, signOut } = useAuth();
  const palette = useAppPalette();
  const mode = useAppStore((state) => state.themeMode);
  const setMode = useAppStore((state) => state.setThemeMode);
  const [overview, setOverview] = useState<GamificationOverview | null>(preview ?? null);
  const [loading, setLoading] = useState(!preview);
  const [error, setError] = useState('');
  const load = useCallback(async () => {
    if (preview) return;
    setLoading(true); setError('');
    try { setOverview(await getGamification()); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load learning statistics.'); }
    finally { setLoading(false); }
  }, [preview]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  const name = profile?.display_name || 'Explorer';
  const preferences = profile?.preferences;
  return <Page eyebrow="YOUR BASE CAMP" title="Your profile" description="Your goals and achievements, all in one place." compact>
    {preview ? <AppText variant="caption" tone="muted">DESIGN PREVIEW · SAMPLE DATA · No progress is saved</AppText> : null}
    <View style={{ backgroundColor: palette.primarySoft, borderRadius: 26, padding: 20, flexDirection: 'row', alignItems: 'center', gap: 15 }}><ProfileAvatar name={name} path={profile?.avatar_url} /><View style={{ flex: 1, gap: 3 }}><AppText variant="heading">{name}</AppText><AppText tone="muted">{profile?.username ? `@${profile.username}` : preferences?.learning_goal ? `Learning for ${preferences.learning_goal}` : 'Choose a learning goal'}</AppText></View></View>
    {profile?.bio ? <AppText tone="muted">{profile.bio}</AppText> : null}
    <AppButton label="Account settings" variant="secondary" onPress={() => router.push('/account-settings' as Href)} />
    {loading ? <LoadingSkeleton lines={3} /> : overview ? <View style={{ flexDirection: 'row', gap: 10 }}><View style={{ flex: 1, backgroundColor: palette.surface, borderRadius: 20, padding: 14 }}><AppText variant="heading" tone="primary">{overview.level}</AppText><AppText variant="caption" tone="muted">Level</AppText></View><View style={{ flex: 1, backgroundColor: palette.surface, borderRadius: 20, padding: 14 }}><AppText variant="heading" tone="primary">{overview.total_xp}</AppText><AppText variant="caption" tone="muted">Total XP</AppText></View><View style={{ flex: 1, backgroundColor: palette.surface, borderRadius: 20, padding: 14 }}><AppText variant="heading" tone="primary">{overview.statistics.completed_lessons}</AppText><AppText variant="caption" tone="muted">Lessons</AppText></View></View> : <ErrorState message={error} retry={() => { void load(); }} />}
    <View style={{ gap: 10 }}><AppText variant="heading">Your learning setup</AppText><View style={{ backgroundColor: palette.surface, borderRadius: 20, padding: 16, gap: 8 }}><AppText>Goal · {preferences?.learning_goal ?? 'Not selected'}</AppText><AppText>Starting level · {preferences?.current_cefr ?? preferences?.initial_proficiency ?? 'Not selected'}</AppText><AppText>Daily time · {preferences?.daily_goal_minutes ?? '—'} minutes</AppText></View><AppButton label="View learning plan" variant="secondary" onPress={() => router.push('/learning-plan')} /></View>
    <Pressable accessibilityRole="button" accessibilityLabel="View badges and rewards" onPress={() => router.push('/rewards')} style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 17, backgroundColor: palette.rewardSoft, borderRadius: 20, opacity: pressed ? 0.76 : 1 })}><SymbolView name={{ ios: 'star.fill', android: 'star', web: 'star' }} size={25} tintColor={palette.rewardOn} /><View style={{ flex: 1 }}><AppText variant="label">Badges and rewards</AppText><AppText variant="caption" tone="muted">See what you have earned</AppText></View><AppText>→</AppText></Pressable>
    <View style={{ gap: 11 }}><AppText variant="heading">Appearance</AppText><View style={{ flexDirection: 'row', gap: 8 }}>{modes.map((item) => <Pressable key={item.value} accessibilityRole="button" accessibilityLabel={`${item.label} theme`} accessibilityState={{ selected: mode === item.value }} onPress={() => setMode(item.value)} style={({ pressed }) => ({ flex: 1, alignItems: 'center', paddingVertical: 12, backgroundColor: mode === item.value ? palette.primarySoft : palette.surface, borderRadius: 15, borderWidth: mode === item.value ? 2 : 0, borderColor: palette.primary, opacity: pressed ? 0.75 : 1 })}><AppText variant="label" tone={mode === item.value ? 'primary' : 'default'}>{item.label}</AppText></Pressable>)}</View></View>
    <AppButton label="Sign out" variant="secondary" onPress={() => { void signOut().finally(() => router.replace('/login')); }} />
  </Page>;
}
