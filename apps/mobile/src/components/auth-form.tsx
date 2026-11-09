import { useRef, useState } from 'react';
import { router } from 'expo-router';
import { Pressable, View } from 'react-native';
import { useAuth } from '@/auth/provider';
import { supabaseConfigStatus } from '@/auth/config';
import { validateAuthFields } from '@/auth/validation';
import { AuthFeedbackMessage, AuthInlineLink, AuthPasswordInput, AuthPrimaryButton, AuthScreenLayout, AuthTextInput } from './auth-ui';
import { AppText } from '@/ui';

type FieldErrors = ReturnType<typeof validateAuthFields>;

export function AuthForm({ register }: { register: boolean }) {
  const { configured, signIn, signUp, callbackError } = useAuth();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const submitting = useRef(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);

  async function continueAuth() {
    if (submitting.current) return;
    const errors = validateAuthFields({ email, password, ...(register ? { name, confirm } : {}) });
    setFieldErrors(errors);
    if (Object.keys(errors).length) return;
    if (!configured) {
      setError(__DEV__ ? `Supabase setup is incomplete (${supabaseConfigStatus}). Check apps/mobile/.env and restart Expo.` : 'Sign in is unavailable. Please try again later.');
      return;
    }
    submitting.current = true;
    setError(''); setMessage(''); setBusy(true);
    try {
      if (register) {
        const hasSession = await signUp(email.trim(), password, name.trim());
        setPassword(''); setConfirm('');
        if (hasSession) router.replace('/onboarding');
        else setMessage('Check your email to confirm your account, then sign in.');
      } else {
        const profile = await signIn(email.trim(), password);
        setPassword('');
        if (profile) router.replace(profile.preferences?.onboarding_completed_at ? '/home' : '/onboarding');
      }
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Authentication failed. Please try again.'); }
    finally { submitting.current = false; setBusy(false); }
  }

  return <AuthScreenLayout title={register ? 'Create your account' : 'Welcome back'} subtitle={register ? 'Start learning English at your own pace.' : 'Sign in to continue your English journey.'} footer={<AuthInlineLink href={register ? '/login' : '/register'} prefix={register ? 'Already have an account?' : 'New to Englify?'} label={register ? 'Sign in' : 'Create an account'} />}>
    <View style={{ gap: 20 }}>
      {register ? <AuthTextInput label="Display name" placeholder="Your name" value={name} onChangeText={(value) => { setName(value); setFieldErrors((current) => ({ ...current, name: undefined })); }} error={fieldErrors.name} autoComplete="name" textContentType="name" returnKeyType="next" /> : null}
      <AuthTextInput label="Email" placeholder="name@example.com" value={email} onChangeText={(value) => { setEmail(value); setFieldErrors((current) => ({ ...current, email: undefined })); }} error={fieldErrors.email} autoCapitalize="none" autoCorrect={false} keyboardType="email-address" autoComplete="email" textContentType="emailAddress" returnKeyType="next" />
      <View style={{ gap: 4 }}><AuthPasswordInput label="Password" placeholder={register ? 'At least 8 characters' : 'Your password'} value={password} onChangeText={(value) => { setPassword(value); setFieldErrors((current) => ({ ...current, password: undefined })); }} error={fieldErrors.password} hint={register ? 'Use at least 8 characters.' : undefined} visible={showPassword} onToggle={() => setShowPassword((value) => !value)} autoComplete={register ? 'new-password' : 'current-password'} textContentType={register ? 'newPassword' : 'password'} returnKeyType={register ? 'next' : 'done'} />
        {!register ? <Pressable accessibilityRole="link" onPress={() => router.push('/forgot-password')} style={({ pressed }) => ({ alignSelf: 'flex-end', minHeight: 44, justifyContent: 'center', opacity: pressed ? 0.65 : 1 })}><AppText variant="label" tone="primary">Forgot password?</AppText></Pressable> : null}</View>
      {register ? <AuthPasswordInput label="Confirm password" placeholder="Repeat your password" value={confirm} onChangeText={(value) => { setConfirm(value); setFieldErrors((current) => ({ ...current, confirm: undefined })); }} error={fieldErrors.confirm} visible={showConfirm} onToggle={() => setShowConfirm((value) => !value)} autoComplete="new-password" textContentType="newPassword" returnKeyType="done" /> : null}
    </View>
    {error || callbackError ? <AuthFeedbackMessage message={error || callbackError || ''} /> : null}
    {message ? <AuthFeedbackMessage message={message} tone="success" /> : null}
    <AuthPrimaryButton label={register ? 'Create account' : 'Sign in'} onPress={() => { void continueAuth(); }} busy={busy} />
  </AuthScreenLayout>;
}
