import { useState } from 'react';
import { router, type Href } from 'expo-router';
import { NavLink, Page } from '@/components/page';
import { AppButton, AppCard, AppInput, AppText } from '@/ui';
import { useAuth } from '@/auth/provider';

export function AuthScreen({ register }: { register: boolean }) {
  const { configured, signIn, signUp, callbackError } = useAuth();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);

  async function continueAuth() {
    if (!email.includes('@') || password.length < 8 || (register && !name.trim())) {
      setError('Enter a valid email, an 8-character password, and a display name when registering.');
      return;
    }
    setError(''); setMessage(''); setBusy(true);
    try {
      if (register) {
        const hasSession = await signUp(email.trim(), password, name.trim());
        setPassword('');
        if (hasSession) router.replace('/onboarding');
        else setMessage('Check your email to confirm your account, then return to the app.');
      } else {
        const profile = await signIn(email.trim(), password);
        setPassword('');
        if (profile) router.replace(profile.preferences?.onboarding_completed_at ? '/home' : '/onboarding');
      }
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Authentication failed'); }
    finally { setBusy(false); }
  }

  return (
    <Page eyebrow="START YOUR QUEST" title={register ? 'Create your account' : 'Welcome back'} description="Sign in with your email to keep your profile and learning choices across sessions.">
      {!configured && <AppCard tone="primary"><AppText variant="label" tone="error">SETUP REQUIRED</AppText><AppText tone="muted">Add the public Supabase URL and publishable key to apps/mobile/.env before signing in.</AppText></AppCard>}
      {register && <AppInput label="Display name" placeholder="Your name" value={name} onChangeText={setName} />}
      <AppInput label="Email" placeholder="name@example.com" value={email} onChangeText={setEmail} autoCapitalize="none" keyboardType="email-address" />
      <AppInput label="Password" placeholder="At least 8 characters" value={password} onChangeText={setPassword} secureTextEntry />
      {(error || callbackError) ? <AppText accessibilityRole="alert" tone="error">{error || callbackError}</AppText> : null}
      {message ? <AppCard tone="reward"><AppText>{message}</AppText></AppCard> : null}
      <AppButton label={register ? 'Register with email' : 'Sign in'} onPress={() => { void continueAuth(); }} size="large" loading={busy} disabled={!configured} />
      <NavLink href={register ? '/login' : '/register'} label={register ? 'Already have an account?' : 'Create an account'} />
      {!register && <NavLink href={'/forgot-password' as Href} label="Forgot password?" />}
    </Page>
  );
}
