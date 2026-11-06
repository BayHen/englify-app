import { ActivityIndicator, Pressable, type StyleProp, type ViewStyle } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from './app-text';

export type AppButtonProps = {
  label: string;
  onPress: () => void;
  variant?: 'primary' | 'secondary' | 'reward' | 'ghost';
  size?: 'medium' | 'large';
  disabled?: boolean;
  loading?: boolean;
  accessibilityHint?: string;
  style?: StyleProp<ViewStyle>;
};

export function AppButton({ label, onPress, variant = 'primary', size = 'medium', disabled = false, loading = false, accessibilityHint, style }: AppButtonProps) {
  const palette = useAppPalette();
  const inactive = disabled || loading;
  const backgroundColor = variant === 'primary' ? palette.primary : variant === 'reward' ? palette.reward : variant === 'secondary' ? palette.surface : 'transparent';
  const foreground = variant === 'primary' ? palette.primaryOn : variant === 'reward' ? palette.rewardOn : palette.text;
  return <Pressable
    accessibilityRole="button"
    accessibilityLabel={label}
    accessibilityHint={accessibilityHint}
    accessibilityState={{ disabled: inactive, busy: loading }}
    disabled={inactive}
    onPress={onPress}
    style={({ pressed }) => [{ minHeight: size === 'large' ? 56 : 48, paddingHorizontal: designTokens.spacing.xl, borderRadius: designTokens.radius.pill, backgroundColor, borderColor: variant === 'secondary' ? palette.border : backgroundColor, borderWidth: variant === 'secondary' ? 1 : 0, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', opacity: inactive ? 0.5 : pressed ? 0.82 : 1 }, style]}>
    {loading && <ActivityIndicator color={foreground} style={{ marginRight: designTokens.spacing.sm }} />}
    <AppText variant="label" style={{ color: foreground, fontSize: designTokens.typography.size.md }}>{label}</AppText>
  </Pressable>;
}
