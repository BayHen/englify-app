import { useState } from 'react';
import { router, type Href } from 'expo-router';
import { View } from 'react-native';
import { Page } from '@/components/page';
import { useAuth } from '@/auth/provider';
import type { ProfileChanges } from '@/auth/api';
import { useAppPalette } from '@/constants/app-theme';
import { ProfileAvatar } from '@/features/profile/profile-avatar';
import { AppButton, AppInput, AppText } from '@/ui';

export default function EditProfile() {
  const { profile, session, saveProfile } = useAuth();
  const palette = useAppPalette();
  const [name, setName] = useState(profile?.display_name ?? '');
  const [username, setUsername] = useState(profile?.username ?? '');
  const [bio, setBio] = useState(profile?.bio ?? '');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  async function save() {
    if (busy || !profile) return;
    const display = name.trim();
    const handle = username.trim().toLowerCase();
    const about = bio.trim();
    if (!display || display.length > 50) { setError('Display name must be 1–50 characters.'); return; }
    if (handle && !/^[a-z0-9_]{3,30}$/.test(handle)) { setError('Username needs 3–30 letters, numbers or underscores.'); return; }
    if (about.length > 160) { setError('Bio must be 160 characters or fewer.'); return; }
    const changes: ProfileChanges = {};
    if (display !== profile.display_name) changes.display_name = display;
    if (handle !== (profile.username ?? '')) changes.username = handle || null;
    if (about !== (profile.bio ?? '')) changes.bio = about || null;
    if (!Object.keys(changes).length) { setSuccess('No changes to save.'); return; }
    setBusy(true); setError(''); setSuccess('');
    try { await saveProfile(changes); setSuccess('Profile updated.'); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save profile.'); }
    finally { setBusy(false); }
  }
  return <Page eyebrow="YOUR ACCOUNT" title="Edit profile" description="A few details to make this space yours." compact>
    <View style={{ alignItems: 'center', gap: 10 }}><ProfileAvatar name={name || 'Learner'} path={profile?.avatar_url} size={84} /><AppButton label="Change photo" variant="ghost" onPress={() => router.push('/change-avatar' as Href)} /></View>
    <AppInput label="Display name" value={name} onChangeText={setName} maxLength={60} autoCapitalize="words" />
    <AppInput label="Username" value={username} onChangeText={setUsername} maxLength={30} autoCapitalize="none" autoCorrect={false} hint="Optional · 3–30 lowercase letters, numbers or underscores" />
    <AppInput label="Bio" value={bio} onChangeText={setBio} maxLength={161} multiline numberOfLines={4} style={{ minHeight: 108, textAlignVertical: 'top', paddingVertical: 12 }} hint="Optional · up to 160 characters" />
    <View style={{ backgroundColor: palette.surface, padding: 14, borderRadius: 14 }}><AppText variant="caption" tone="muted">EMAIL ADDRESS · READ ONLY</AppText><AppText>{session?.user.email ?? 'Unavailable'}</AppText></View>
    {error ? <AppText tone="error" accessibilityRole="alert">{error}</AppText> : null}
    {success ? <AppText tone="success" accessibilityRole="alert">{success}</AppText> : null}
    <AppButton label="Save changes" loading={busy} onPress={() => { void save(); }} />
  </Page>;
}
