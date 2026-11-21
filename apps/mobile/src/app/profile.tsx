import { Redirect, router } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { usePendingDestination } from '@/auth/access';
import { useAuth } from '@/auth/provider';
import { Page } from '@/components/page';
import { useAppPalette } from '@/constants/app-theme';
import { ProfileScreen } from '@/features/home/profile-screen';
import { AppButton, AppText } from '@/ui';

export default function ProfileRoute() {
  const { phase, profile } = useAuth();
  const palette = useAppPalette();
  const { spacing, radius } = designTokens;

  if (phase === 'authenticated') {
    if (!profile) return <Redirect href="/home" />;
    if (!profile.preferences?.onboarding_completed_at) return <Redirect href="/onboarding" />;
    return <ProfileScreen key={profile.id} />;
  }

  function openAuth(destination: '/login' | '/register') {
    usePendingDestination.getState().set(null);
    router.push(destination);
  }

  return <Page title="Profile" compact headerAccessory={false}>
    <View style={{ alignItems: 'center', gap: spacing.md, padding: spacing.xl, borderRadius: radius.xl,
      borderWidth: 1, borderColor: palette.border, backgroundColor: palette.surface }}>
      <View accessible={false} style={{ width: 72, height: 72, borderRadius: radius.pill,
        alignItems: 'center', justifyContent: 'center', backgroundColor: palette.primarySoft }}>
        <SymbolView name={{ ios: 'person.crop.circle', android: 'account_circle', web: 'account_circle' }}
          size={36} tintColor={palette.primary} />
      </View>
      <AppText variant="heading" accessibilityRole="header" style={{ textAlign: 'center' }}>Welcome to Englify</AppText>
      <AppText tone="muted" style={{ textAlign: 'center' }}>
        Sign in to save vocabulary, follow your learning journey and track your progress.
      </AppText>
    </View>
    <AppButton label="Sign in" onPress={() => openAuth('/login')} />
    <AppButton label="Create account" variant="secondary" onPress={() => openAuth('/register')} />
  </Page>;
}
