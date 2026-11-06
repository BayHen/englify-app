import { create } from 'zustand';

export type ThemeMode = 'system' | 'light' | 'dark';
type AppState = {
  displayName: string | null;
  themeMode: ThemeMode;
  completeDemoAuth: (name: string) => void;
  signOut: () => void;
  setThemeMode: (mode: ThemeMode) => void;
};

export const useAppStore = create<AppState>((set) => ({
  displayName: null,
  themeMode: 'system',
  completeDemoAuth: (name) => set({ displayName: name.trim() || 'Learner' }),
  signOut: () => set({ displayName: null }),
  setThemeMode: (themeMode) => set({ themeMode }),
}));
