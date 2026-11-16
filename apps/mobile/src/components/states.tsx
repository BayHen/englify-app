import { ActivityIndicator, View } from 'react-native';
import { ActionButton } from '@/components/page';
import { useAppPalette } from '@/constants/app-theme';
import { useI18n } from '@/i18n';
import { AppText } from '@/ui';

export function LoadingState() {
  const palette = useAppPalette();
  const { l } = useI18n();
  return <View accessibilityLabel={l('Loading content')} style={{ padding: 24, alignItems: 'center' }}><ActivityIndicator color={palette.primary} /><AppText tone="muted" style={{ marginTop: 10 }}>Loading your quest…</AppText></View>;
}

export function EmptyState() {
  return <AppText tone="muted" style={{ paddingVertical: 20 }}>Nothing here yet. Check back soon.</AppText>;
}

export function ErrorState({ retry }: { retry: () => void }) {
  return <View style={{ gap: 12 }}><AppText tone="error">We couldn’t load this content.</AppText><ActionButton label="Try again" onPress={retry} /></View>;
}
