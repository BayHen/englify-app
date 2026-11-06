import { useColorScheme } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppStore } from '@/state/app-store';
import type { ThemeMode } from '@/state/app-store';

export function resolvePalette(mode: ThemeMode, system: 'light' | 'dark' | null | undefined) {
  const dark = mode === 'system' ? system === 'dark' : mode === 'dark';
  return { dark, ...designTokens.palette[dark ? 'dark' : 'light'] };
}

export function useAppPalette() {
  const system = useColorScheme();
  const mode = useAppStore((state) => state.themeMode);
  return resolvePalette(mode, system);
}
