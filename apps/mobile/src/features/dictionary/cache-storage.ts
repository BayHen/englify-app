import Storage from 'expo-sqlite/kv-store';

export const readStorage = (key: string): Promise<string | null> => Storage.getItem(key);
export const writeStorage = (key: string, value: string): Promise<void> => Storage.setItem(key, value);
