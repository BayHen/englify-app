import type { SpeechVoice } from './speech-provider';

export type Accent = 'all' | 'us' | 'uk' | 'au' | 'other';
export const accentLabels: Record<Accent, string> = { all: 'All', us: 'US', uk: 'UK', au: 'Australia', other: 'Other' };

export function isEnglishVoice(voice: SpeechVoice): boolean {
  return /^en(?:[-_]|$)/i.test(voice.locale);
}

export function accentOf(voice: SpeechVoice): Exclude<Accent, 'all'> {
  const region = voice.locale.replace('_', '-').split('-')[1]?.toUpperCase();
  return region === 'US' ? 'us' : region === 'GB' ? 'uk' : region === 'AU' ? 'au' : 'other';
}

export function availableAccents(voices: SpeechVoice[]): Accent[] {
  const groups = new Set(voices.map(accentOf));
  return (['all', 'us', 'uk', 'au', 'other'] as Accent[]).filter((accent) => accent === 'all' || groups.has(accent));
}

export function filterVoices(voices: SpeechVoice[], query: string, accent: Accent): SpeechVoice[] {
  const term = query.trim().toLocaleLowerCase();
  return voices.filter((voice) =>
    (accent === 'all' || accentOf(voice) === accent)
    && (!term || `${voice.name} ${voice.language} ${voice.locale}`.toLocaleLowerCase().includes(term))
  );
}

export function preferredVoice(voices: SpeechVoice[], storedId: string | null): SpeechVoice | null {
  if (!voices.length) return null;
  const stored = voices.find((voice) => voice.id === storedId);
  if (stored) return stored;
  return voices.find((voice) => accentOf(voice) === 'us') ?? voices[0];
}

export function voiceLocaleLabel(voice: SpeechVoice): string {
  const region = voice.locale.replace('_', '-').split('-')[1]?.toUpperCase();
  const accent = region === 'US' ? 'US' : region === 'GB' ? 'UK' : region === 'AU' ? 'Australia' : region;
  return accent ? `English (${accent})` : 'English';
}
