import { DarkTheme, DefaultTheme, Stack, ThemeProvider, router, useSegments, type Href } from 'expo-router';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { useColorScheme } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { AppErrorBoundary } from '@/components/app-error-boundary';
import { AuthProvider, useAuth } from '@/auth/provider';
import { Page } from '@/components/page';
import { useAppStore } from '@/state/app-store';
import { AppButton, ErrorState, LoadingSkeleton } from '@/ui';

function AppNavigator() {
  const { loading, session, profile, profileError, refreshProfile, signOut, callbackTarget, clearCallbackTarget } = useAuth();
  const segments = useSegments();
  useEffect(() => {
    if (!loading && callbackTarget && (callbackTarget === '/login' || (session && (profile || callbackTarget === '/reset-password')))) {
      router.replace(callbackTarget as Href);
      clearCallbackTarget();
    }
  }, [loading, callbackTarget, session, profile, clearCallbackTarget]);
  if (loading || (session && !profile && !profileError)) return <Page eyebrow="RESTORING SESSION" title="Welcome back" description="Checking your account securely."><LoadingSkeleton /></Page>;
  if (session && profileError && callbackTarget !== '/reset-password' && String(segments[0]) !== 'reset-password') return <Page eyebrow="ACCOUNT UNAVAILABLE" title="Could not load your profile" description="Check your connection and try again."><ErrorState message={profileError} retry={() => { void refreshProfile(); }} /><AppButton label="Sign out" variant="secondary" onPress={() => { void signOut(); }} /></Page>;
  const signedIn = Boolean(session);
  const onboarded = Boolean(profile?.preferences?.onboarding_completed_at);
  return <Stack screenOptions={{ headerShown: false }}>
    <Stack.Screen name="index" />
    <Stack.Screen name="auth-callback" />
    <Stack.Protected guard={!signedIn} redirectTo="/login">
      <Stack.Screen name="login" />
      <Stack.Screen name="register" />
      <Stack.Screen name="forgot-password" />
    </Stack.Protected>
    <Stack.Protected guard={signedIn} redirectTo="/login"><Stack.Screen name="reset-password" /></Stack.Protected>
    <Stack.Protected guard={signedIn && !onboarded} redirectTo="/home"><Stack.Screen name="onboarding" /></Stack.Protected>
    <Stack.Protected guard={signedIn && onboarded} redirectTo={signedIn ? '/onboarding' : '/login'}>
      <Stack.Screen name="home" /><Stack.Screen name="journey" /><Stack.Screen name="explore" />
      <Stack.Screen name="coach" /><Stack.Screen name="dictionary" /><Stack.Screen name="translation" />
      <Stack.Screen name="real-english" /><Stack.Screen name="speaking" /><Stack.Screen name="writing" />
      <Stack.Screen name="quiz-arena" /><Stack.Screen name="rewards" /><Stack.Screen name="profile" />
      <Stack.Screen name="dev/showcase" />
    </Stack.Protected>
  </Stack>;
}

export default function RootLayout() {
  const systemScheme = useColorScheme();
  const themeMode = useAppStore((state) => state.themeMode);
  const dark = themeMode === 'system' ? systemScheme === 'dark' : themeMode === 'dark';
  const [queryClient] = useState(() => new QueryClient({ defaultOptions: { queries: { retry: 1 } } }));
  return (
    <AppErrorBoundary>
      <SafeAreaProvider>
        <QueryClientProvider client={queryClient}>
          <ThemeProvider value={dark ? DarkTheme : DefaultTheme}>
            <AuthProvider><AppNavigator /></AuthProvider>
          </ThemeProvider>
        </QueryClientProvider>
      </SafeAreaProvider>
    </AppErrorBoundary>
  );
}
