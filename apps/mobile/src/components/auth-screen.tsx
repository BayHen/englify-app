import { useState } from 'react';
import { router } from 'expo-router';
import { Text, TextInput, View } from 'react-native';
import { ActionButton, NavLink, Page } from '@/components/page';
import { useAppPalette } from '@/constants/app-theme';
import { useAppStore } from '@/state/app-store';

export function AuthScreen({ register }: { register: boolean }) {
  const palette = useAppPalette();
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

  const inputStyle = { backgroundColor: palette.surface, color: palette.text, borderColor: palette.border, borderWidth: 1, borderRadius: 14, paddingHorizontal: 16, minHeight: 52, fontSize: 16 } as const;
  return (
    <Page eyebrow="START YOUR QUEST" title={register ? 'Create your space' : 'Welcome back'} description="Explore the learning experience with a local demo account. Real authentication arrives in a later task.">
      {register && <TextInput accessibilityLabel="Display name" placeholder="Your name" placeholderTextColor={palette.muted} value={name} onChangeText={setName} style={inputStyle} />}
      <TextInput accessibilityLabel="Email" placeholder="Email" placeholderTextColor={palette.muted} value={email} onChangeText={setEmail} autoCapitalize="none" keyboardType="email-address" style={inputStyle} />
      <TextInput accessibilityLabel="Password" placeholder="Password" placeholderTextColor={palette.muted} value={password} onChangeText={setPassword} secureTextEntry style={inputStyle} />
      {error ? <Text accessibilityRole="alert" style={{ color: palette.error }}>{error}</Text> : null}
      <ActionButton label={register ? 'Continue to onboarding' : 'Enter demo'} onPress={continueDemo} />
      <NavLink href={register ? '/login' : '/register'} label={register ? 'Already have an account?' : 'Create a demo account'} />
      <View style={{ height: 12 }} />
      <Text style={{ color: palette.muted, fontSize: 13 }}>Demo credentials are not sent or saved. Use non-sensitive sample values.</Text>
    </Page>
  );
}
