import { useState } from 'react';
import { router } from 'expo-router';
import { NavLink, Page } from '@/components/page';
import { AppButton, AppCard, AppInput, AppText } from '@/ui';
import { useAppStore } from '@/state/app-store';

export function AuthScreen({ register }: { register: boolean }) {
  const completeDemoAuth = useAppStore((state) => state.completeDemoAuth);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  function continueDemo() {
    if (!email.includes('@') || password.length < 4 || (register && !name.trim())) {
      setError('Enter a name, valid email, and a password of at least 4 characters.');
      return;
    }
    setError('');
    completeDemoAuth(register ? name : email.split('@')[0]);
    router.replace(register ? '/onboarding' : '/home');
  }

  return (
    <Page eyebrow="START YOUR QUEST" title={register ? 'Create your space' : 'Welcome back'} description="Explore the learning experience with a local demo account. Real authentication arrives in a later task.">
      <AppCard tone="primary"><AppText variant="label" tone="primary">LOCAL DEMO</AppText><AppText tone="muted">Use sample values only. No account is created and no credentials are sent or stored.</AppText></AppCard>
      {register && <AppInput label="Display name" placeholder="Your name" value={name} onChangeText={setName} />}
      <AppInput label="Email" placeholder="name@example.com" value={email} onChangeText={setEmail} autoCapitalize="none" keyboardType="email-address" />
      <AppInput label="Password" placeholder="At least 4 characters" value={password} onChangeText={setPassword} secureTextEntry />
      {error ? <AppText accessibilityRole="alert" tone="error">{error}</AppText> : null}
      <AppButton label={register ? 'Continue to onboarding' : 'Enter demo'} onPress={continueDemo} size="large" />
      <NavLink href={register ? '/login' : '/register'} label={register ? 'Already have an account?' : 'Create a demo account'} />
    </Page>
  );
}
