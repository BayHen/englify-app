import { TextInput, View, type TextInputProps } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from './app-text';

export type AppInputProps = TextInputProps & { label: string; error?: string; hint?: string };

export function AppInput({ label, error, hint, style, ...props }: AppInputProps) {
  const palette = useAppPalette();
  return <View style={{ gap: designTokens.spacing.xs }}>
    <AppText variant="label">{label}</AppText>
    <TextInput
      accessibilityLabel={label}
      accessibilityHint={error || hint}
      placeholderTextColor={palette.muted}
      {...props}
      style={[{ minHeight: 52, borderWidth: 1.5, borderColor: error ? palette.error : palette.border, borderRadius: designTokens.radius.md, backgroundColor: palette.input, color: palette.text, fontSize: designTokens.typography.size.md, paddingHorizontal: designTokens.spacing.lg }, style]}
    />
    {error ? <AppText variant="caption" tone="error" accessibilityRole="alert">{error}</AppText> : hint ? <AppText variant="caption" tone="muted">{hint}</AppText> : null}
  </View>;
}
