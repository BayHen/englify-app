import { DarkTheme, DefaultTheme, Stack, ThemeProvider } from 'expo-router';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState } from 'react';
import { useColorScheme } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { AppErrorBoundary } from '@/components/app-error-boundary';
import { useAppStore } from '@/state/app-store';

export default function RootLayout() {
  const systemScheme = useColorScheme();
  const themeMode = useAppStore((state) => state.themeMode);
  const dark = themeMode === 'system' ? systemScheme === 'dark' : themeMode === 'dark';
  const [queryClient] = useState(() => new QueryClient({ defaultOptions: { queries: { retry: 1 } } }));
  return (
    <AppErrorBoundary>
      <SafeAreaProvider>
        <QueryClientProvider client={queryClient}>
          <ThemeProvider value={dark ? DarkTheme : DefaultTheme}>
            <Stack screenOptions={{ headerShown: false }} />
          </ThemeProvider>
        </QueryClientProvider>
      </SafeAreaProvider>
    </AppErrorBoundary>
  );
}
