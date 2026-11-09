import { useState } from 'react';
import { Page } from '@/components/page';
import { getSupabase } from '@/auth/supabase';
import { AppButton, AppInput, AppText } from '@/ui';

export default function ChangePassword() {
  const [current, setCurrent] = useState('');
  const [next, setNext] = useState('');
  const [confirm, setConfirm] = useState('');
  const [visible, setVisible] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  async function submit() {
    if (busy) return;
    if (!current) { setError('Enter your current password.'); return; }
    if (next.length < 8) { setError('Use a new password with at least 8 characters.'); return; }
    if (next !== confirm) { setError('New passwords do not match.'); return; }
    if (current === next) { setError('Choose a different new password.'); return; }
    setBusy(true); setError(''); setSuccess('');
    try {
      const { data: sessionData } = await getSupabase().auth.getSession();
      if (!sessionData.session) throw new Error('Session expired. Sign in again.');
      const { error: authError } = await getSupabase().auth.updateUser({ password: next, current_password: current });
      if (authError) throw authError;
      setCurrent(''); setNext(''); setConfirm(''); setSuccess('Password changed.');
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not change password.'); }
    finally { setBusy(false); }
  }
  return <Page eyebrow="ACCOUNT SECURITY" title="Change password" description="Confirm your current password to protect your account." compact>
    <AppInput label="Current password" value={current} onChangeText={setCurrent} secureTextEntry={!visible} autoCapitalize="none" />
    <AppInput label="New password" value={next} onChangeText={setNext} secureTextEntry={!visible} autoCapitalize="none" />
    <AppInput label="Confirm new password" value={confirm} onChangeText={setConfirm} secureTextEntry={!visible} autoCapitalize="none" />
    <AppButton label={visible ? 'Hide passwords' : 'Show passwords'} variant="ghost" onPress={() => setVisible(!visible)} />
    {error ? <AppText tone="error" accessibilityRole="alert">{error}</AppText> : null}
    {success ? <AppText tone="success" accessibilityRole="alert">{success}</AppText> : null}
    <AppButton label="Update password" loading={busy} onPress={() => { void submit(); }} />
  </Page>;
}
