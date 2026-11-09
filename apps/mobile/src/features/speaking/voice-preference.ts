import Storage from 'expo-sqlite/kv-store';
import { Platform } from 'react-native';

const key = (userId: string) => `speaking-voice:v1:${Platform.OS}:${userId}`;

export async function readVoicePreference(userId: string): Promise<string | null> {
  return Storage.getItem(key(userId));
}

export async function writeVoicePreference(userId: string, voiceId: string): Promise<void> {
  await Storage.setItem(key(userId), voiceId);
}
