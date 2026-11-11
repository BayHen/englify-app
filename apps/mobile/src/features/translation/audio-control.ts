export type PronunciationControls = {
  stopSpeech: () => Promise<void>;
  stopAudio: () => void;
  playAudio: (url: string) => Promise<void>;
  speak: (text: string) => void;
  isCurrent?: () => boolean;
};

type PlaybackStatus = { playing: boolean; didJustFinish: boolean; error?: string | null };

export function waitForAudioStart(
  subscribe: (listener: (status: PlaybackStatus) => void) => { remove: () => void },
  start: () => void,
  timeoutMs = 3500,
): Promise<void> {
  return new Promise((resolve, reject) => {
    let settled = false;
    let subscription: { remove: () => void } | null = null;
    let timer: ReturnType<typeof setTimeout> | null = null;
    const finish = (error?: Error) => {
      if (settled) return;
      settled = true;
      if (timer) clearTimeout(timer);
      subscription?.remove();
      if (error) reject(error);
      else resolve();
    };
    try {
      subscription = subscribe((status) => {
        if (status.error) finish(new Error('Audio playback failed.'));
        else if (status.playing || status.didJustFinish) finish();
      });
      timer = setTimeout(() => finish(new Error('Audio did not start.')), timeoutMs);
      start();
    } catch { finish(new Error('Audio playback failed.')); }
  });
}

export async function startPronunciation(
  text: string, audioUrl: string | null, controls: PronunciationControls,
): Promise<'audio' | 'speech'> {
  await controls.stopSpeech();
  controls.stopAudio();
  if (audioUrl) {
    try {
      await controls.playAudio(audioUrl);
      return 'audio';
    } catch {
      controls.stopAudio();
    }
  }
  if (controls.isCurrent?.() === false) throw new Error('Pronunciation was stopped.');
  controls.speak(text);
  return 'speech';
}
