import { forwardRef } from 'react';
import { TextInput, View, type TextInputInstance, type TextInputProps } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from './app-text';
import { useI18n } from '@/i18n/context';

export type AppInputProps = TextInputProps & { label: string; error?: string; hint?: string };

export const AppInput = forwardRef<TextInputInstance, AppInputProps>(function AppInput({ label, error, hint, style, ...props }, ref) {
  const palette = useAppPalette();
  const { l } = useI18n();
  const localizedLabel = l(label);
  return <View style={{ gap: designTokens.spacing.xs }}>
    <AppText variant="label">{localizedLabel}</AppText>
    <TextInput
      ref={ref}
      accessibilityLabel={localizedLabel}
      accessibilityHint={error || hint}
      placeholderTextColor={palette.muted}
      {...props}
      placeholder={props.placeholder ? l(props.placeholder) : undefined}
      style={[{ minHeight: 52, borderWidth: 1.5, borderColor: error ? palette.error : palette.border, borderRadius: designTokens.radius.md, backgroundColor: palette.input, color: palette.text, fontSize: designTokens.typography.size.md, paddingHorizontal: designTokens.spacing.lg }, style]}
    />
    {error ? <AppText variant="caption" tone="error" accessibilityRole="alert">{error}</AppText> : hint ? <AppText variant="caption" tone="muted">{hint}</AppText> : null}
  </View>;
});
