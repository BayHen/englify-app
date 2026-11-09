import { beforeEach, describe, expect, it } from 'vitest';
import { readVoicePreference, writeVoicePreference } from './voice-preference.web';

const values = new Map<string, string>();
Object.defineProperty(globalThis, 'localStorage', { configurable: true, value: {
  getItem: (key: string) => values.get(key) ?? null,
  setItem: (key: string, value: string) => { values.set(key, value); },
} });

describe('web voice preference', () => {
  beforeEach(() => values.clear());
  it('persists the stable voice ID per account', async () => {
    await writeVoicePreference('user-a', 'device-voice-1');
    expect(await readVoicePreference('user-a')).toBe('device-voice-1');
    expect(await readVoicePreference('user-b')).toBeNull();
  });
});
