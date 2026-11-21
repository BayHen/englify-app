import { DarkTheme, DefaultTheme, Stack, ThemeProvider, router, usePathname, type Href } from 'expo-router';
import * as Linking from 'expo-linking';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useEffect, useState, useSyncExternalStore } from 'react';
import { Platform, useColorScheme } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { useFonts } from 'expo-font';

import { AppErrorBoundary } from '@/components/app-error-boundary';
import { AuthProvider, useAuth } from '@/auth/provider';
import { accountDestination, authenticationRedirects, usePendingDestination } from '@/auth/access';
import { Page } from '@/components/page';
import { useAppStore } from '@/state/app-store';
import { AppText } from '@/ui';
import { SyncEngine } from '@/features/offline/sync-engine';
import { I18nProvider, useI18n } from '@/i18n';

const noSubscription = () => () => {};
const clientReady = () => true;
const serverReady = () => false;

function AppNavigator() {
  const { phase, session, profile, callbackTarget, clearCallbackTarget } = useAuth();
  const pathname = usePathname();
  const destination = usePendingDestination((state) => state.destination);
  useEffect(() => {
    if (phase !== 'guest') return;
    let live = true;
    const remember = (url: string) => {
      const path = Linking.parse(url).path;
      const target = path ? accountDestination(`/${path.replace(/^\/+/, '')}`) : null;
      if (live && target) usePendingDestination.getState().set(target);
    };
    const subscription = Linking.addEventListener('url', ({ url }) => remember(url));
    if (pathname === '/login-required' && !usePendingDestination.getState().destination) {
      void Linking.getInitialURL().then((url) => { if (url) remember(url); }).catch(() => undefined);
    }
    return () => { live = false; subscription.remove(); };
  }, [phase, pathname]);
  useEffect(() => {
    if (phase !== 'initializing' && callbackTarget && (callbackTarget === '/login' || (session && (profile || callbackTarget === '/reset-password')))) {
      router.replace(callbackTarget as Href);
      clearCallbackTarget();
    } else if (phase === 'authenticated' && !callbackTarget && destination && pathname === destination) {
      usePendingDestination.getState().set(null);
    } else if (phase === 'authenticated' && !callbackTarget && destination && pathname === '/home' && profile?.preferences?.onboarding_completed_at) {
      usePendingDestination.getState().set(null);
      router.replace(destination);
    }
  }, [phase, callbackTarget, session, profile, clearCallbackTarget, destination, pathname]);
  if (phase === 'initializing') return <Page title="Englify" compact><AppText tone="muted">Restoring your session…</AppText></Page>;
  const signedIn = Boolean(session);
  const onboarded = Boolean(profile?.preferences?.onboarding_completed_at);
  const redirects = authenticationRedirects(phase, signedIn, Boolean(profile), onboarded, destination);
  return <Stack screenOptions={{ headerShown: false }}>
    <Stack.Screen name="index" />
    <Stack.Screen name="auth-callback" />
    <Stack.Screen name="home" />
    <Stack.Protected guard={phase !== 'signingOut'} redirectTo="/home">
      <Stack.Screen name="profile" />
    </Stack.Protected>
    <Stack.Screen name="dictionary" /><Stack.Screen name="translation" />
    {__DEV__ && <Stack.Screen name="dev/auth-diagnostic" />}
    {__DEV__ && <Stack.Screen name="dev/ui-v2-preview" />}
    <Stack.Protected guard={!signedIn && phase !== 'signingOut'} redirectTo={redirects.publicAuth}>
      <Stack.Screen name="login-required" />
      <Stack.Screen name="login" />
      <Stack.Screen name="register" />
      <Stack.Screen name="forgot-password" />
    </Stack.Protected>
    <Stack.Protected guard={signedIn} redirectTo="/login"><Stack.Screen name="reset-password" /></Stack.Protected>
    <Stack.Protected guard={signedIn && Boolean(profile) && !onboarded} redirectTo={onboarded ? destination ?? '/home' : '/home'}><Stack.Screen name="onboarding" /></Stack.Protected>
    <Stack.Protected guard={signedIn && onboarded} redirectTo={redirects.privateRoute}>
      <Stack.Screen name="journey" /><Stack.Screen name="journey-placement" /><Stack.Screen name="learning-plan" /><Stack.Screen name="lesson/[id]" /><Stack.Screen name="practice" />
      <Stack.Screen name="coach" /><Stack.Screen name="explore" />
      <Stack.Screen name="vocabulary-review" />
      <Stack.Screen name="real-english" /><Stack.Screen name="speaking" /><Stack.Screen name="writing" />
      <Stack.Screen name="writing-progress" /><Stack.Screen name="writing-progress/[id]" />
      <Stack.Screen name="quiz-arena" /><Stack.Screen name="quiz-practice/[id]" /><Stack.Screen name="time-attack/[id]" /><Stack.Screen name="ranked-arena/[id]" /><Stack.Screen name="mistakes" /><Stack.Screen name="mistake-review/[id]" /><Stack.Screen name="rewards" />
      <Stack.Screen name="account-settings" /><Stack.Screen name="edit-profile" />
      <Stack.Screen name="change-avatar" /><Stack.Screen name="change-password" />
      <Stack.Screen name="learning-preferences" />
      <Stack.Screen name="dev/showcase" />
    </Stack.Protected>
  </Stack>;
}

function LocalizedApplication({ dark, queryClient }: { dark: boolean; queryClient: QueryClient }) {
  const { ready } = useI18n();
  if (!ready) return null;
  return <QueryClientProvider client={queryClient}>
    <ThemeProvider value={dark ? DarkTheme : DefaultTheme}>
      <AuthProvider><SyncEngine /><AppNavigator /></AuthProvider>
    </ThemeProvider>
  </QueryClientProvider>;
}

export default function RootLayout() {
  // The web theme and stored settings are client state; keep SSR and the hydration pass identical.
  const hydrated = useSyncExternalStore(noSubscription, clientReady, serverReady);
  const [fontsReady, fontError] = useFonts({
    Nunito_400Regular: require('@expo-google-fonts/nunito/400Regular/Nunito_400Regular.ttf'),
    Nunito_600SemiBold: require('@expo-google-fonts/nunito/600SemiBold/Nunito_600SemiBold.ttf'),
    Nunito_700Bold: require('@expo-google-fonts/nunito/700Bold/Nunito_700Bold.ttf'),
    Nunito_800ExtraBold: require('@expo-google-fonts/nunito/800ExtraBold/Nunito_800ExtraBold.ttf'),
    Baloo2_700Bold: require('@expo-google-fonts/baloo-2/700Bold/Baloo2_700Bold.ttf'),
  });
  const systemScheme = useColorScheme();
  const themeMode = useAppStore((state) => state.themeMode);
  const dark = themeMode === 'system' ? systemScheme === 'dark' : themeMode === 'dark';
  const [queryClient] = useState(() => new QueryClient({ defaultOptions: { queries: { retry: 1 } } }));
  if ((Platform.OS === 'web' && !hydrated) || (!fontsReady && !fontError)) return null;
  return (
    <SafeAreaProvider>
      <I18nProvider>
        <AppErrorBoundary><LocalizedApplication dark={dark} queryClient={queryClient} /></AppErrorBoundary>
      </I18nProvider>
    </SafeAreaProvider>
  );
}
