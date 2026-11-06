import { useState } from 'react';
import { router } from 'expo-router';
import { Page } from '@/components/page';
import { useAuth } from '@/auth/provider';
import { AppButton, AppInput, AppText } from '@/ui';

export default function ResetPassword() {
  const { updatePassword, profile } = useAuth();
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  async function submit() {
    if (password.length < 8 || password !== confirm) { setError('Use at least 8 characters and matching passwords.'); return; }
    setBusy(true); setError('');
    try { await updatePassword(password); setPassword(''); setConfirm(''); router.replace(profile?.preferences?.onboarding_completed_at ? '/home' : '/onboarding'); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Password update failed'); }
    finally { setBusy(false); }
  }
  return <Page eyebrow="ACCOUNT RECOVERY" title="Choose a new password" description="Your recovery link has opened a secure session. Save a new password to continue.">
    <AppInput label="New password" value={password} onChangeText={setPassword} secureTextEntry />
    <AppInput label="Confirm password" value={confirm} onChangeText={setConfirm} secureTextEntry />
    {error && <AppText tone="error" accessibilityRole="alert">{error}</AppText>}
    <AppButton label="Save new password" onPress={() => { void submit(); }} loading={busy} />
  </Page>;
}
