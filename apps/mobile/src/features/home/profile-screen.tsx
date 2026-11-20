import { designTokens } from '@englify/shared';
import { useCallback, useState } from 'react';
import { router, useFocusEffect, type Href } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, View } from 'react-native';
import { Page } from '@/components/page';
import { useAuth } from '@/auth/provider';
import { useAppPalette } from '@/constants/app-theme';
import { useAppStore, type ThemeMode } from '@/state/app-store';
import { AppButton, AppCard, AppText, ErrorState, LoadingSkeleton, XPProgressBar } from '@/ui';
import { getGamification, type GamificationOverview } from '@/features/gamification/api';
import { ProfileAvatar } from '@/features/profile/profile-avatar';
import { useI18n, type TranslationKey } from '@/i18n';

const goalKeys = {
  conversation: 'preferences.goal.conversation', travel: 'preferences.goal.travel', work: 'preferences.goal.work',
  exams: 'preferences.goal.exams', real_english: 'preferences.goal.realEnglish',
} as const satisfies Record<string, TranslationKey>;

export function ProfileScreen({ preview }: { preview?: GamificationOverview }) {
  const { profile, signOut } = useAuth();
  const { t } = useI18n();
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
    catch { setError(t('profile.error.statistics')); }
    finally { setLoading(false); }
  }, [preview, t]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  const name = profile?.display_name || t('profile.explorer');
  const preferences = profile?.preferences;
  const goalLabel = preferences?.learning_goal ? t(goalKeys[preferences.learning_goal]) : t('profile.notSelected');
  const modes: { value: ThemeMode; label: string }[] = [{ value: 'system', label: t('profile.theme.system') }, { value: 'light', label: t('profile.theme.light') }, { value: 'dark', label: t('profile.theme.dark') }];
  return <Page eyebrow={t('profile.eyebrow')} title={t('profile.title')} description={t('profile.description')} compact>
    {preview ? <AppText variant="caption" tone="muted">{t('profile.preview')}</AppText> : null}
    <View style={{ backgroundColor: palette.primarySoft, borderRadius: 26, padding: 20, flexDirection: 'row', alignItems: 'center', gap: 15 }}><ProfileAvatar name={name} path={profile?.avatar_url} /><View style={{ flex: 1, gap: 3 }}><AppText variant="heading">{name}</AppText><AppText tone="muted">{profile?.username ? `@${profile.username}` : preferences?.learning_goal ? `${t('profile.learningFor')} · ${goalLabel}` : t('profile.chooseGoal')}</AppText></View></View>
    {profile?.bio ? <AppText tone="muted">{profile.bio}</AppText> : null}
    <AppButton label={t('profile.accountSettings')} variant="secondary" onPress={() => router.push('/account-settings' as Href)} />
    {loading ? <LoadingSkeleton lines={3} /> : overview ? <AppCard style={{ gap: designTokens.spacing.sm }}>
      <XPProgressBar value={overview.xp_into_level} max={overview.xp_for_next_level} label="XP toward next level" />
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: designTokens.spacing.md }}>
        {[
          { label: t('profile.level'), value: overview.level },
          { label: t('profile.totalXp'), value: overview.total_xp },
          { label: t('profile.lessons'), value: overview.statistics.completed_lessons },
        ].map(({ label, value }) => <View key={label} style={{ flexGrow: 1, minWidth: '24%', gap: designTokens.spacing.xs }}>
          <AppText variant="heading" tone="primary">{value}</AppText>
          <AppText variant="caption" tone="muted">{label}</AppText>
        </View>)}
      </View>
    </AppCard> : <ErrorState message={error} retry={() => { void load(); }} />}
    <View style={{ gap: 10 }}><AppText variant="heading">{t('profile.learningSetup')}</AppText><View style={{ backgroundColor: palette.surface, borderRadius: 20, padding: 16, gap: 8 }}><AppText>{t('profile.goal')} · {goalLabel}</AppText><AppText>{t('profile.startingLevel')} · {preferences?.current_cefr ?? preferences?.initial_proficiency ?? t('profile.notSelected')}</AppText><AppText>{t('profile.dailyTime')} · {preferences?.daily_goal_minutes ?? '—'} {t('profile.minutes')}</AppText></View><AppButton label={t('profile.viewPlan')} variant="secondary" onPress={() => router.push('/learning-plan')} /></View>
    <Pressable accessibilityRole="button" accessibilityLabel={t('profile.badges')} onPress={() => router.push('/rewards')} style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 17, backgroundColor: palette.rewardSoft, borderRadius: 20, opacity: pressed ? 0.76 : 1 })}><SymbolView name={{ ios: 'star.fill', android: 'star', web: 'star' }} size={25} tintColor={palette.rewardOn} /><View style={{ flex: 1 }}><AppText variant="label">{t('profile.badges')}</AppText><AppText variant="caption" tone="muted">{t('profile.badgesDetail')}</AppText></View><AppText>→</AppText></Pressable>
    <View style={{ gap: 11 }}><AppText variant="heading">{t('profile.appearance')}</AppText><View style={{ flexDirection: 'row', gap: 8 }}>{modes.map((item) => <Pressable key={item.value} accessibilityRole="button" accessibilityLabel={`${item.label} ${t('profile.themeSuffix')}`} accessibilityState={{ selected: mode === item.value }} onPress={() => setMode(item.value)} style={({ pressed }) => ({ flex: 1, alignItems: 'center', paddingVertical: 12, backgroundColor: mode === item.value ? palette.primarySoft : palette.surface, borderRadius: 15, borderWidth: mode === item.value ? 2 : 0, borderColor: palette.primary, opacity: pressed ? 0.75 : 1 })}><AppText variant="label" tone={mode === item.value ? 'primary' : 'default'}>{item.label}</AppText></Pressable>)}</View></View>
    <AppButton label={t('profile.signOut')} variant="secondary" onPress={() => { void signOut().finally(() => router.replace('/login')); }} />
  </Page>;
}
