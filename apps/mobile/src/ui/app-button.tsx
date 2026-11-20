import { ActivityIndicator, Pressable, type StyleProp, type ViewStyle } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from './app-text';
import { useI18n } from '@/i18n/context';

export type AppButtonProps = {
  label: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary' | 'reward' | 'ghost' | 'incorrect';
  size?: 'medium' | 'large';
  disabled?: boolean;
  loading?: boolean;
  accessibilityHint?: string;
  style?: StyleProp<ViewStyle>;
};

export function AppButton({ label, onPress, variant = 'primary', size = 'medium', disabled = false, loading = false, accessibilityHint, style }: AppButtonProps) {
  const palette = useAppPalette();
  const { l } = useI18n();
  const localizedLabel = l(label);
  const inactive = disabled || loading;
  const outlined = variant === 'secondary' || variant === 'incorrect';
  const backgroundColor = variant === 'primary' ? palette.primary : variant === 'reward' ? palette.reward : outlined ? palette.surface : 'transparent';
  const foreground = variant === 'primary' ? palette.primaryOn : variant === 'reward' ? palette.rewardOn : variant === 'incorrect' ? palette.error : palette.text;
  return <Pressable
    accessibilityRole="button"
    accessibilityLabel={localizedLabel}
    accessibilityHint={accessibilityHint}
    accessibilityState={{ disabled: inactive, busy: loading }}
    disabled={inactive}
    onPress={onPress}
    style={({ pressed }) => [{ minHeight: size === 'large' ? 56 : 48, paddingHorizontal: designTokens.spacing.xl, borderRadius: designTokens.radius.pill, backgroundColor, borderColor: variant === 'incorrect' ? palette.error : palette.border, borderWidth: outlined ? 1 : 0, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', opacity: inactive ? 0.5 : pressed ? 0.82 : 1 }, style]}>
    {loading && <ActivityIndicator color={foreground} style={{ marginRight: designTokens.spacing.sm }} />}
    <AppText variant="label" style={{ color: foreground, fontSize: designTokens.typography.size.md }}>{localizedLabel}</AppText>
  </Pressable>;
}
