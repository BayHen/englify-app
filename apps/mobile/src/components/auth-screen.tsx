import { useRef, useState } from 'react';
import { KeyboardAvoidingView, Platform } from 'react-native';
import { router, type Href } from 'expo-router';
import { NavLink, Page } from '@/components/page';
import { AppButton, AppCard, AppInput, AppText } from '@/ui';
import { useAuth } from '@/auth/provider';
import { supabaseConfigStatus } from '@/auth/config';
import { validateAuthInput } from '@/auth/validation';

export function AuthScreen({ register }: { register: boolean }) {
  const { configured, signIn, signUp, callbackError } = useAuth();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const submitting = useRef(false);
  const [showPassword, setShowPassword] = useState(false);

  async function continueAuth() {
    if (submitting.current) return;
    if (!configured) {
      setError(__DEV__ ? `Cấu hình Supabase chưa hợp lệ (${supabaseConfigStatus}). Kiểm tra apps/mobile/.env rồi khởi động lại Expo.` : 'Đăng nhập hiện chưa khả dụng. Vui lòng thử lại sau.');
      return;
    }
    const validationError = validateAuthInput(email, password, register ? name : undefined);
    if (validationError) {
      setError(validationError);
      return;
    }
    submitting.current = true;
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
    finally { submitting.current = false; setBusy(false); }
  }

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
    <Page eyebrow="START YOUR QUEST" title={register ? 'Create your account' : 'Welcome back'} description="Sign in with your email to keep your profile and learning choices across sessions.">
      {!configured && __DEV__ && <AppCard tone="primary" style={{ gap: 8 }}>
        <AppText variant="label" tone="error">CẦN CẤU HÌNH SUPABASE</AppText>
        <AppText tone="muted">Tạo apps/mobile/.env từ .env.example. Điền Project URL và publishable key của dự án Supabase, sau đó khởi động lại Expo.</AppText>
        <AppText variant="caption" tone="muted">Nút đăng nhập sẽ báo hướng dẫn này cho đến khi cấu hình hoàn tất. Không dùng service role key.</AppText>
      </AppCard>}
      {__DEV__ && <NavLink href={'/dev/auth-diagnostic' as Href} label="Run Supabase diagnostic" />}
      {register && <AppInput label="Display name" placeholder="Your name" value={name} onChangeText={setName} />}
      <AppInput label="Email" placeholder="name@example.com" value={email} onChangeText={setEmail} autoCapitalize="none" keyboardType="email-address" />
      <AppInput label="Password" placeholder="At least 8 characters" value={password} onChangeText={setPassword} secureTextEntry={!showPassword} autoComplete={register ? 'new-password' : 'current-password'} />
      <AppButton label={showPassword ? 'Hide password' : 'Show password'} variant="ghost" onPress={() => setShowPassword(!showPassword)} />
      {(error || callbackError) ? <AppText accessibilityRole="alert" tone="error">{error || callbackError}</AppText> : null}
      {message ? <AppCard tone="reward"><AppText>{message}</AppText></AppCard> : null}
      <AppButton label={register ? 'Register with email' : 'Sign in'} onPress={() => { void continueAuth(); }} size="large" loading={busy} accessibilityHint={!configured ? 'Supabase configuration is required before authentication' : undefined} />
      <NavLink href={register ? '/login' : '/register'} label={register ? 'Already have an account?' : 'Create an account'} />
      {!register && <NavLink href={'/forgot-password' as Href} label="Forgot password?" />}
    </Page>
    </KeyboardAvoidingView>
  );
}
