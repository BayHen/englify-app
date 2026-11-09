import { useState } from 'react';
import { Page } from '@/components/page';
import { useAuth } from '@/auth/provider';
import { ProfileAvatar } from '@/features/profile/profile-avatar';
import { chooseAvatar, removeAvatarObject, uploadAvatar } from '@/features/profile/avatar';
import { AppButton, AppText } from '@/ui';

export default function ChangeAvatar() {
  const { profile, saveProfile } = useAuth();
  const [preview, setPreview] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  async function choose() {
    if (busy) return;
    setError(''); setSuccess('');
    try { const uri = await chooseAvatar(); if (uri) setPreview(uri); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not open your photos.'); }
  }
  async function save() {
    if (busy || !preview || !profile) return;
    setBusy(true); setError(''); setSuccess('');
    let uploaded: string | null = null;
    try {
      uploaded = await uploadAvatar(preview, profile.id);
      await saveProfile({ avatar_url: uploaded });
      setPreview(null); setSuccess('Avatar updated.');
      if (profile.avatar_url) await removeAvatarObject(profile.avatar_url).catch(() => undefined);
    } catch (cause) {
      if (uploaded) await removeAvatarObject(uploaded).catch(() => undefined);
      setError(cause instanceof Error ? cause.message : 'Could not save avatar.');
    } finally { setBusy(false); }
  }
  async function remove() {
    if (busy || !profile) return;
    if (preview) { setPreview(null); return; }
    if (!profile.avatar_url) return;
    setBusy(true); setError(''); setSuccess('');
    try {
      await saveProfile({ avatar_url: null });
      await removeAvatarObject(profile.avatar_url).catch(() => undefined);
      setSuccess('Avatar removed.');
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not remove avatar.'); }
    finally { setBusy(false); }
  }
  return <Page eyebrow="YOUR ACCOUNT" title="Your photo" description="A square photo helps make your profile feel familiar." compact>
    <ProfileAvatar name={profile?.display_name ?? 'Learner'} path={profile?.avatar_url} preview={preview} size={112} />
    <AppButton label="Choose photo" variant="secondary" disabled={busy} onPress={() => { void choose(); }} />
    {preview ? <AppButton label="Save photo" loading={busy} onPress={() => { void save(); }} /> : null}
    {preview || profile?.avatar_url ? <AppButton label={preview ? 'Discard selection' : 'Remove photo'} variant="ghost" disabled={busy} onPress={() => { void remove(); }} /> : null}
    <AppText variant="caption" tone="muted">Photos are cropped to a square, compressed to JPEG, and stored privately. Maximum 2 MB after processing.</AppText>
    {error ? <AppText tone="error" accessibilityRole="alert">{error}</AppText> : null}
    {success ? <AppText tone="success" accessibilityRole="alert">{success}</AppText> : null}
  </Page>;
}
