import { create } from 'zustand';

export type ThemeMode = 'system' | 'light' | 'dark';
type AppState = {
  displayName: string | null;
  themeMode: ThemeMode;
  setDisplayName: (name: string | null) => void;
  setThemeMode: (mode: ThemeMode) => void;
};

export const useAppStore = create<AppState>((set) => ({
  displayName: null,
  themeMode: 'system',
  setDisplayName: (name) => set({ displayName: name?.trim() || null }),
  setThemeMode: (themeMode) => set({ themeMode }),
}));
