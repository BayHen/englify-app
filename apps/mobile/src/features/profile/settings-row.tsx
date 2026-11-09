import { Pressable, View } from 'react-native';
import { AppText } from '@/ui';
import { useAppPalette } from '@/constants/app-theme';

export function SettingsRow({ label, detail, onPress }: { label: string; detail?: string; onPress: () => void }) {
  const palette = useAppPalette();
  return <Pressable accessibilityRole="button" accessibilityLabel={label} onPress={onPress} style={({ pressed }) => ({ minHeight: 62, paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: palette.border, flexDirection: 'row', alignItems: 'center', gap: 10, opacity: pressed ? 0.7 : 1 })}>
    <View style={{ flex: 1, gap: 2 }}><AppText variant="label">{label}</AppText>{detail ? <AppText variant="caption" tone="muted">{detail}</AppText> : null}</View><AppText tone="muted">›</AppText>
  </Pressable>;
}
