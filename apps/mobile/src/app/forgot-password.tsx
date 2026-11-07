import { useState } from 'react';
import { NavLink, Page } from '@/components/page';
import { useAuth } from '@/auth/provider';
import { AppButton, AppCard, AppInput, AppText } from '@/ui';

export default function ForgotPassword() {
  const { configured, requestPasswordReset } = useAuth();
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');
  async function submit() {
    setBusy(true); setError('');
    try { await requestPasswordReset(email.trim()); setSent(true); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not request reset'); }
    finally { setBusy(false); }
  }
  return <Page eyebrow="ACCOUNT HELP" title="Reset your password" description="Enter your email and we will send a reset link if an account exists.">
    <AppInput label="Email" value={email} onChangeText={setEmail} autoCapitalize="none" keyboardType="email-address" placeholder="name@example.com" />
    {!!error && <AppText tone="error" accessibilityRole="alert">{error}</AppText>}
    {sent && <AppCard tone="primary"><AppText>Check your inbox for a password reset link. The message may take a moment to arrive.</AppText></AppCard>}
    <AppButton label="Send reset link" onPress={() => { void submit(); }} disabled={!configured || !email.includes('@')} loading={busy} />
    <NavLink href="/login" label="Back to sign in" />
  </Page>;
}
