const key = (userId: string) => `speaking-voice:v1:web:${userId}`;

export async function readVoicePreference(userId: string): Promise<string | null> {
  return globalThis.localStorage?.getItem(key(userId)) ?? null;
}

export async function writeVoicePreference(userId: string, voiceId: string): Promise<void> {
  globalThis.localStorage?.setItem(key(userId), voiceId);
}
