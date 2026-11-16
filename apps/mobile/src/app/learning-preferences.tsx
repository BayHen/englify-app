import { useState } from 'react';
import { View, Pressable } from 'react-native';
import { Page } from '@/components/page';
import { LanguageSelector } from '@/components/language-selector';
import { useAuth } from '@/auth/provider';
import type { CefrLevel, PreferenceChanges, Profile } from '@/auth/api';
import { regeneratePlan } from '@/features/plan/api';
import { useAppPalette } from '@/constants/app-theme';
import { AppButton, AppModal, AppText } from '@/ui';
import { useI18n } from '@/i18n';
import { preferenceErrorKey } from '@/i18n/errors';

const levels: CefrLevel[] = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
const durations = [5, 10, 15, 20, 30];

function Choice<T extends string | number>({ title, value, options, onChange }: { title: string; value: T; options: readonly (readonly [T, string])[]; onChange: (value: T) => void }) {
  const palette = useAppPalette();
  return <View style={{ gap: 9 }}><AppText variant="label">{title}</AppText><View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{options.map(([id, label]) => <Pressable key={String(id)} accessibilityRole="button" accessibilityLabel={label} accessibilityState={{ selected: value === id }} onPress={() => onChange(id)} style={({ pressed }) => ({ borderWidth: 1, borderColor: value === id ? palette.primary : palette.border, borderRadius: 16, paddingHorizontal: 13, paddingVertical: 10, backgroundColor: value === id ? palette.primarySoft : palette.surface, opacity: pressed ? 0.7 : 1 })}><AppText variant="label" tone={value === id ? 'primary' : 'default'}>{label}</AppText></Pressable>)}</View></View>;
}

export default function LearningPreferences() {
  const { profile, savePreferences } = useAuth();
  const { language, setLanguage, t } = useI18n();
  const prefs = profile?.preferences;
  const [goal, setGoal] = useState<NonNullable<NonNullable<Profile['preferences']>['learning_goal']>>(prefs?.learning_goal ?? 'conversation');
  const [level, setLevel] = useState<CefrLevel>(prefs?.current_cefr ?? (prefs?.initial_proficiency === 'advanced' ? 'C1' : prefs?.initial_proficiency === 'intermediate' ? 'B1' : 'A1'));
  const [minutes, setMinutes] = useState(prefs?.daily_goal_minutes ?? 10);
  const [accent, setAccent] = useState<NonNullable<Profile['preferences']>['preferred_accent']>(prefs?.preferred_accent ?? 'en-US');
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const goals = [['conversation', t('preferences.goal.conversation')], ['work', t('preferences.goal.work')], ['travel', t('preferences.goal.travel')], ['exams', t('preferences.goal.exams')], ['real_english', t('preferences.goal.realEnglish')]] as const;
  const accents = [['en-US', t('preferences.accent.american')], ['en-GB', t('preferences.accent.british')], ['en-AU', t('preferences.accent.australian')]] as const;
  async function save() {
    if (busy || !prefs) return;
    const changes: PreferenceChanges = {};
    if (goal !== prefs.learning_goal) changes.learning_goal = goal;
    if (level !== prefs.current_cefr) changes.current_cefr = level;
    if (minutes !== prefs.daily_goal_minutes) changes.daily_goal_minutes = minutes;
    if (accent !== prefs.preferred_accent) changes.preferred_accent = accent;
    if (language !== prefs.interface_language) changes.interface_language = language;
    if (!Object.keys(changes).length) { setSuccess(t('preferences.noChanges')); return; }
    setBusy(true); setError(''); setSuccess('');
    try {
      await savePreferences(changes);
      setSuccess(t('preferences.saved'));
      if ('learning_goal' in changes || 'current_cefr' in changes || 'daily_goal_minutes' in changes) setConfirm(true);
    } catch (cause) { setError(t(preferenceErrorKey(cause, 'preferences.error.save'))); }
    finally { setBusy(false); }
  }
  async function regenerate() {
    if (busy) return;
    setBusy(true); setError('');
    try { await regeneratePlan(); setSuccess(t('preferences.planRefreshed')); setConfirm(false); }
    catch (cause) { setError(t(preferenceErrorKey(cause, 'preferences.error.plan'))); setConfirm(false); }
    finally { setBusy(false); }
  }
  return <Page eyebrow={t('preferences.eyebrow')} title={t('preferences.title')} description={t('preferences.description')} compact>
    <Choice title={t('preferences.learningGoal')} value={goal} options={goals} onChange={setGoal} />
    <Choice title={t('preferences.englishLevel')} value={level} options={levels.map((item) => [item, item] as const)} onChange={setLevel} />
    <Choice title={t('preferences.minutes')} value={minutes} options={durations.map((item) => [item, `${item} ${t('preferences.minuteSuffix')}`] as const)} onChange={setMinutes} />
    <Choice title={t('preferences.accent')} value={accent} options={accents} onChange={setAccent} />
    <LanguageSelector value={language} onChange={setLanguage} />
    {!prefs ? <AppText tone="muted">{t('preferences.missing')}</AppText> : null}
    {error ? <AppText tone="error" accessibilityRole="alert">{error}</AppText> : null}
    {success ? <AppText tone="success" accessibilityRole="alert">{success}</AppText> : null}
    <AppButton label={busy ? t('preferences.saving') : t('preferences.save')} loading={busy} disabled={!prefs} onPress={() => { void save(); }} />
    <AppModal visible={confirm} title={t('preferences.refreshTitle')} onClose={() => setConfirm(false)}><AppText tone="muted">{t('preferences.refreshDescription')}</AppText><AppButton label={t('preferences.refreshAction')} loading={busy} onPress={() => { void regenerate(); }} /></AppModal>
  </Page>;
}
