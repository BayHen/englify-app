import { useColorScheme } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppStore } from '@/state/app-store';

export function useAppPalette() {
  const system = useColorScheme();
  const mode = useAppStore((state) => state.themeMode);
  const dark = mode === 'system' ? system === 'dark' : mode === 'dark';
  return {
    dark,
    background: dark ? '#151226' : designTokens.color.background,
    surface: dark ? '#242039' : '#FFFFFF',
    text: dark ? '#F8F6FF' : '#211B3A',
    muted: dark ? '#BDB6D6' : '#655D80',
    border: dark ? '#393250' : '#E9E3FA',
    primary: designTokens.color.primary,
    reward: designTokens.color.reward,
    success: designTokens.color.success,
    error: designTokens.color.error,
  };
}
