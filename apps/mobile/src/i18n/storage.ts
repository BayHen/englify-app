import { Platform } from 'react-native';
import * as SecureStore from 'expo-secure-store';
import type { InterfaceLanguage } from './types';

const key = 'englify.interface-language.v1';
export type StoredLanguage = { language: InterfaceLanguage; pendingSync: boolean };

function parse(value: string | null): StoredLanguage | null {
  if (!value) return null;
  try {
    const parsed = JSON.parse(value) as Partial<StoredLanguage>;
    return (parsed.language === 'en' || parsed.language === 'vi')
      ? { language: parsed.language, pendingSync: parsed.pendingSync === true }
      : null;
  } catch { return null; }
}

export async function readStoredLanguage(): Promise<StoredLanguage | null> {
  if (Platform.OS === 'web') {
    try { return parse(globalThis.localStorage?.getItem(key) ?? null); } catch { return null; }
  }
  return parse(await SecureStore.getItemAsync(key));
}

export async function writeStoredLanguage(value: StoredLanguage): Promise<void> {
  const serialized = JSON.stringify(value);
  if (Platform.OS === 'web') {
    try { globalThis.localStorage?.setItem(key, serialized); } catch { /* Keep the in-memory selection. */ }
    return;
  }
  await SecureStore.setItemAsync(key, serialized);
}
