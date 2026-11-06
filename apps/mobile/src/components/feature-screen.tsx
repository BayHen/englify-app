import { useQuery } from '@tanstack/react-query';
import { router } from 'expo-router';
import { useAuth } from '@/auth/provider';
import { Text } from 'react-native';
import { ActionButton, NavLink, Page } from '@/components/page';
import { EmptyState, ErrorState, LoadingState } from '@/components/states';
import { useAppPalette } from '@/constants/app-theme';
import { getMockContent, type FeatureKey } from '@/lib/mock-content';
import { useAppStore, type ThemeMode } from '@/state/app-store';
import { AppCard, AppText } from '@/ui';

const links = [
  { href: '/home' as const, label: 'Home' },
  { href: '/journey' as const, label: 'Journey' },
  { href: '/explore' as const, label: 'Explore' },
  { href: '/coach' as const, label: 'AI Coach' },
  { href: '/profile' as const, label: 'Profile' },
];

export function FeatureScreen({ feature }: { feature: FeatureKey }) {
  const palette = useAppPalette();
  const { data, isPending, isError, refetch } = useQuery({ queryKey: ['mock-content', feature], queryFn: () => getMockContent(feature) });
  const displayName = useAppStore((state) => state.displayName);
  const themeMode = useAppStore((state) => state.themeMode);
  const setThemeMode = useAppStore((state) => state.setThemeMode);
  const { signOut } = useAuth();
  const content = data ?? { eyebrow: 'YOUR QUEST', title: 'Getting ready', description: 'Preparing your learning space.', items: [] };

  return (
    <Page eyebrow={content.eyebrow} title={feature === 'home' && displayName ? `Welcome, ${displayName}` : content.title} description={content.description}>
      {isPending ? <LoadingState /> : isError ? <ErrorState retry={() => { void refetch(); }} /> : content.items.length === 0 ? <EmptyState /> : content.items.map((item) => (
        <AppCard key={item.title} style={{ gap: 5 }}>
          <AppText variant="heading">{item.title}</AppText>
          <AppText tone="muted">{item.detail}</AppText>
        </AppCard>
      ))}
      {feature === 'coach' && <Text style={{ color: palette.muted }}>AI conversation and pronunciation scoring are not connected yet.</Text>}
      {feature === 'profile' && <>
        <Text style={{ color: palette.text, fontWeight: '700', marginTop: 14 }}>Appearance · {themeMode}</Text>
        {(['system', 'light', 'dark'] as ThemeMode[]).map((mode) => <ActionButton key={mode} label={mode === 'system' ? 'Use device setting' : `Use ${mode} theme`} onPress={() => setThemeMode(mode)} secondary={themeMode !== mode} />)}
        <ActionButton label="Sign out" onPress={() => { void signOut().finally(() => router.replace('/login')); }} secondary />
        {__DEV__ && <NavLink href="/dev/showcase" label="Open design system showcase" />}
      </>}
      <Text style={{ color: palette.muted, fontSize: 12, marginTop: 20 }}>Demo content · no progress is saved yet</Text>
      {links.filter((link) => link.href !== `/${feature}`).map((link) => <NavLink key={link.href} href={link.href} label={link.label} />)}
    </Page>
  );
}
