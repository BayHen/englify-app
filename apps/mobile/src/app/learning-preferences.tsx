import { useState } from 'react';
import { View, Pressable } from 'react-native';
import { Page } from '@/components/page';
import { useAuth } from '@/auth/provider';
import type { CefrLevel, PreferenceChanges, Profile } from '@/auth/api';
import { regeneratePlan } from '@/features/plan/api';
import { useAppPalette } from '@/constants/app-theme';
import { AppButton, AppModal, AppText } from '@/ui';

const goals = [
  ['conversation', 'Daily conversation'], ['work', 'Work English'], ['travel', 'Travel English'],
  ['exams', 'TOEIC preparation'], ['real_english', 'Real English & slang'],
] as const;
const levels: CefrLevel[] = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
const durations = [5, 10, 15, 20, 30];
const accents = [['en-US', 'American English'], ['en-GB', 'British English'], ['en-AU', 'Australian English']] as const;
const languages = [['en', 'English'], ['vi', 'Tiếng Việt']] as const;

function Choice<T extends string | number>({ title, value, options, onChange }: { title: string; value: T; options: readonly (readonly [T, string])[]; onChange: (value: T) => void }) {
  const palette = useAppPalette();
  return <View style={{ gap: 9 }}><AppText variant="label">{title}</AppText><View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>{options.map(([id, label]) => <Pressable key={String(id)} accessibilityRole="button" accessibilityLabel={label} accessibilityState={{ selected: value === id }} onPress={() => onChange(id)} style={({ pressed }) => ({ borderWidth: 1, borderColor: value === id ? palette.primary : palette.border, borderRadius: 16, paddingHorizontal: 13, paddingVertical: 10, backgroundColor: value === id ? palette.primarySoft : palette.surface, opacity: pressed ? 0.7 : 1 })}><AppText variant="label" tone={value === id ? 'primary' : 'default'}>{label}</AppText></Pressable>)}</View></View>;
}

export default function LearningPreferences() {
  const { profile, savePreferences } = useAuth();
  const prefs = profile?.preferences;
  const [goal, setGoal] = useState<NonNullable<NonNullable<Profile['preferences']>['learning_goal']>>(prefs?.learning_goal ?? 'conversation');
  const [level, setLevel] = useState<CefrLevel>(prefs?.current_cefr ?? (prefs?.initial_proficiency === 'advanced' ? 'C1' : prefs?.initial_proficiency === 'intermediate' ? 'B1' : 'A1'));
  const [minutes, setMinutes] = useState(prefs?.daily_goal_minutes ?? 10);
  const [accent, setAccent] = useState<NonNullable<Profile['preferences']>['preferred_accent']>(prefs?.preferred_accent ?? 'en-US');
  const [language, setLanguage] = useState<NonNullable<Profile['preferences']>['interface_language']>(prefs?.interface_language ?? 'en');
  const [busy, setBusy] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  async function save() {
    if (busy || !prefs) return;
    const changes: PreferenceChanges = {};
    if (goal !== prefs.learning_goal) changes.learning_goal = goal;
    if (level !== prefs.current_cefr) changes.current_cefr = level;
    if (minutes !== prefs.daily_goal_minutes) changes.daily_goal_minutes = minutes;
    if (accent !== prefs.preferred_accent) changes.preferred_accent = accent;
    if (language !== prefs.interface_language) changes.interface_language = language;
    if (!Object.keys(changes).length) { setSuccess('No changes to save.'); return; }
    setBusy(true); setError(''); setSuccess('');
    try {
      await savePreferences(changes);
      setSuccess('Learning preferences saved. Your completed lessons remain intact.');
      if ('learning_goal' in changes || 'current_cefr' in changes || 'daily_goal_minutes' in changes) setConfirm(true);
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save preferences.'); }
    finally { setBusy(false); }
  }
  async function regenerate() {
    if (busy) return;
    setBusy(true); setError('');
    try { await regeneratePlan(); setSuccess('Future plan refreshed. Completed work was preserved.'); setConfirm(false); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not refresh the learning plan.'); setConfirm(false); }
    finally { setBusy(false); }
  }
  return <Page eyebrow="LEARNING SETUP" title="Your preferences" description="Choose a pace and goal that work for you." compact>
    <Choice title="Learning goal" value={goal} options={goals} onChange={setGoal} />
    <Choice title="Current English level" value={level} options={levels.map((item) => [item, item] as const)} onChange={setLevel} />
    <Choice title="Minutes each day" value={minutes} options={durations.map((item) => [item, `${item} min`] as const)} onChange={setMinutes} />
    <Choice title="Preferred accent" value={accent} options={accents} onChange={setAccent} />
    <Choice title="Interface language" value={language} options={languages} onChange={setLanguage} />
    {error ? <AppText tone="error" accessibilityRole="alert">{error}</AppText> : null}
    {success ? <AppText tone="success" accessibilityRole="alert">{success}</AppText> : null}
    <AppButton label="Save preferences" loading={busy} disabled={!prefs} onPress={() => { void save(); }} />
    <AppModal visible={confirm} title="Refresh your plan?" onClose={() => setConfirm(false)}><AppText tone="muted">A new plan will replace future scheduled tasks. Completed lessons and history stay saved.</AppText><AppButton label="Refresh future plan" loading={busy} onPress={() => { void regenerate(); }} /></AppModal>
  </Page>;
}
