import 'react-native-url-polyfill/auto';
import { AppState, Platform } from 'react-native';
import * as SecureStore from 'expo-secure-store';
import { createClient, type SupabaseClient, type SupportedStorage } from '@supabase/supabase-js';

const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const key = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
export const authConfigured = Boolean(url && key && !url.includes('your-project') && !key.includes('replace_me'));

const secureStorage: SupportedStorage = {
  getItem: (name) => SecureStore.getItemAsync(name),
  setItem: (name, value) => SecureStore.setItemAsync(name, value),
  removeItem: (name) => SecureStore.deleteItemAsync(name),
};

let instance: SupabaseClient | null = null;
export function getSupabase(): SupabaseClient {
  if (!authConfigured || !url || !key) throw new Error('Set public Supabase URL and publishable key in apps/mobile/.env');
  if (!instance) {
    instance = createClient(url, key, {
      auth: {
        ...(Platform.OS === 'web' ? {} : { storage: secureStorage }),
        autoRefreshToken: true,
        persistSession: Platform.OS !== 'web',
        detectSessionInUrl: false,
        flowType: 'pkce',
      },
    });
    if (Platform.OS !== 'web') {
      AppState.addEventListener('change', (state) => {
        if (state === 'active') instance?.auth.startAutoRefresh();
        else instance?.auth.stopAutoRefresh();
      });
    }
  }
  return instance;
}
