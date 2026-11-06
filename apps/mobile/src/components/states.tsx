import { ActivityIndicator, Text, View } from 'react-native';
import { ActionButton } from '@/components/page';
import { useAppPalette } from '@/constants/app-theme';

export function LoadingState() {
  const palette = useAppPalette();
  return <View accessibilityLabel="Loading content" style={{ padding: 24, alignItems: 'center' }}><ActivityIndicator color={palette.primary} /><Text style={{ color: palette.muted, marginTop: 10 }}>Loading your quest…</Text></View>;
}

export function EmptyState() {
  const palette = useAppPalette();
  return <Text style={{ color: palette.muted, paddingVertical: 20 }}>Nothing here yet. Check back soon.</Text>;
}

export function ErrorState({ retry }: { retry: () => void }) {
  const palette = useAppPalette();
  return <View style={{ gap: 12 }}><Text style={{ color: palette.error }}>We couldn’t load this content.</Text><ActionButton label="Try again" onPress={retry} /></View>;
}
