import { useEffect, useRef, useState } from 'react';
import { useAuth } from '@/auth/provider';
import { AuthFeedbackMessage, AuthInlineLink, AuthPrimaryButton, AuthScreenLayout, AuthTextInput } from './auth-ui';

export function ForgotPasswordScreen() {
  const { configured, requestPasswordReset } = useAuth();
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');
  const [emailError, setEmailError] = useState('');
  const [cooldown, setCooldown] = useState(0);
  const submitting = useRef(false);

  useEffect(() => {
    if (cooldown <= 0) return;
    const timer = setTimeout(() => setCooldown((value) => Math.max(0, value - 1)), 1000);
    return () => clearTimeout(timer);
  }, [cooldown]);

  async function submit() {
    if (submitting.current || cooldown > 0) return;
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) { setEmailError('Enter a valid email address.'); return; }
    if (!configured) { setError(__DEV__ ? 'Supabase setup is incomplete. Check apps/mobile/.env and restart Expo.' : 'Password recovery is unavailable. Please try again later.'); return; }
    submitting.current = true;
    setBusy(true); setError(''); setEmailError('');
    try { await requestPasswordReset(email.trim()); setSent(true); setCooldown(60); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not send a reset link. Please try again.'); }
    finally { submitting.current = false; setBusy(false); }
  }

  if (sent) return <AuthScreenLayout title="Check your email" subtitle="If an account exists for this email, you'll receive a password reset link." footer={<AuthInlineLink href="/login" label="Back to sign in" />}>
    {error ? <AuthFeedbackMessage message={error} /> : null}
    <AuthPrimaryButton label={cooldown > 0 ? `Resend in ${cooldown}s` : 'Resend reset link'} onPress={() => { void submit(); }} busy={busy} disabled={cooldown > 0} />
  </AuthScreenLayout>;

  return <AuthScreenLayout title="Forgot your password?" subtitle="Enter your email and we'll send you a link to reset it." footer={<AuthInlineLink href="/login" label="Back to sign in" />}>
    <AuthTextInput label="Email" placeholder="name@example.com" value={email} onChangeText={(value) => { setEmail(value); setEmailError(''); }} error={emailError} autoCapitalize="none" autoCorrect={false} keyboardType="email-address" autoComplete="email" textContentType="emailAddress" returnKeyType="done" onSubmitEditing={() => { void submit(); }} />
    {error ? <AuthFeedbackMessage message={error} /> : null}
    <AuthPrimaryButton label="Send reset link" onPress={() => { void submit(); }} busy={busy} />
  </AuthScreenLayout>;
}
