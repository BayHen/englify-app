import 'react-native-url-polyfill/auto';
import { AppState, Platform } from 'react-native';
import * as SecureStore from 'expo-secure-store';
import { createClient, type SupabaseClient, type SupportedStorage } from '@supabase/supabase-js';
import { supabaseConfigStatus } from './config';

const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const key = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
export const authConfigured = supabaseConfigStatus === 'ready';

const secureStorage: SupportedStorage = {
  getItem: (name) => SecureStore.getItemAsync(name),
  setItem: (name, value) => SecureStore.setItemAsync(name, value),
  removeItem: (name) => SecureStore.deleteItemAsync(name),
};

let instance: SupabaseClient | null = null;
export function getSupabase(): SupabaseClient {
  if (!authConfigured || !url || !key) throw new Error('Supabase configuration is missing or invalid. See docs/setup/SUPABASE_SETUP.md');
  if (!instance) {
    instance = createClient(url, key, {
      auth: {
        ...(Platform.OS === 'web' ? {} : { storage: secureStorage }),
        autoRefreshToken: true,
        persistSession: true,
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
