import { describe, expect, it } from 'vitest';
import { accentOf, availableAccents, filterVoices, isEnglishVoice, preferredVoice, voiceLocaleLabel } from './voice-catalog';
import type { SpeechVoice } from './speech-provider';

const voices: SpeechVoice[] = [
  { id: 'us-1', name: 'Device Voice A', language: 'en-US', locale: 'en-US' },
  { id: 'gb-1', name: 'Device Voice B', language: 'en-GB', locale: 'en-GB' },
  { id: 'in-1', name: 'Device Voice C', language: 'en-IN', locale: 'en-IN' },
  { id: 'vi-1', name: 'Device Voice D', language: 'vi-VN', locale: 'vi-VN' },
];

describe('device voice catalog', () => {
  it('uses locale metadata for English voices and available accent filters', () => {
    const english = voices.filter(isEnglishVoice);
    expect(english.map((voice) => voice.id)).toEqual(['us-1', 'gb-1', 'in-1']);
    expect(availableAccents(english)).toEqual(['all', 'us', 'uk', 'other']);
    expect(accentOf(english[2])).toBe('other');
    expect(voiceLocaleLabel(english[1])).toBe('English (UK)');
  });

  it('searches names and locales without selecting a voice', () => {
    const english = voices.filter(isEnglishVoice);
    expect(filterVoices(english, 'voice b', 'all').map((voice) => voice.id)).toEqual(['gb-1']);
    expect(filterVoices(english, 'en-in', 'other').map((voice) => voice.id)).toEqual(['in-1']);
    expect(filterVoices(english, '', 'au')).toEqual([]);
  });

  it('restores a matching ID or falls back to an available English voice', () => {
    const english = voices.filter(isEnglishVoice);
    expect(preferredVoice(english, 'gb-1')?.id).toBe('gb-1');
    expect(preferredVoice(english, 'removed')?.id).toBe('us-1');
    expect(preferredVoice([], 'removed')).toBeNull();
  });
});
