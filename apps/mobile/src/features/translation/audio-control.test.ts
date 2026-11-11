import { describe, expect, it, vi } from 'vitest';
import { startPronunciation, waitForAudioStart, type PronunciationControls } from './audio-control';

function controls(events: string[]): PronunciationControls {
  return {
    stopSpeech: vi.fn(async () => { events.push('stop speech'); }),
    stopAudio: vi.fn(() => { events.push('stop audio'); }),
    playAudio: vi.fn(async () => { events.push('play audio'); }),
    speak: vi.fn(() => { events.push('speak'); }),
  };
}

describe('pronunciation source selection', () => {
  it('stops previous playback before dictionary audio', async () => {
    const events: string[] = [];
    expect(await startPronunciation('license', 'https://example.com/license.mp3', controls(events))).toBe('audio');
    expect(events).toEqual(['stop speech', 'stop audio', 'play audio']);
  });
  it('uses device speech when audio is absent or fails', async () => {
    const noAudio: string[] = [];
    expect(await startPronunciation('license', null, controls(noAudio))).toBe('speech');
    expect(noAudio).toEqual(['stop speech', 'stop audio', 'speak']);
    const events: string[] = [];
    const failing = controls(events);
    failing.playAudio = vi.fn(async () => { events.push('play audio'); throw new Error('unavailable'); });
    expect(await startPronunciation('license', 'https://example.com/license.mp3', failing)).toBe('speech');
    expect(events).toEqual(['stop speech', 'stop audio', 'play audio', 'stop audio', 'speak']);
  });
  it('does not start device speech after playback was cancelled', async () => {
    const events: string[] = [];
    const cancelled = controls(events);
    cancelled.isCurrent = () => false;
    cancelled.playAudio = vi.fn(async () => { throw new Error('network'); });
    await expect(startPronunciation('love', 'https://example.com/love.mp3', cancelled)).rejects.toThrow('stopped');
    expect(events).not.toContain('speak');
  });
});

describe('dictionary audio startup', () => {
  it('accepts a real playback event and removes the listener', async () => {
    const remove = vi.fn();
    let notify: ((status: { playing: boolean; didJustFinish: boolean; error?: string }) => void) | null = null;
    const waiting = waitForAudioStart((listener) => { notify = listener; return { remove }; }, vi.fn());
    (notify as unknown as (status: { playing: boolean; didJustFinish: boolean }) => void)({ playing: true, didJustFinish: false });
    await expect(waiting).resolves.toBeUndefined();
    expect(remove).toHaveBeenCalledOnce();
  });
  it('rejects a stalled or failed audio source so device speech can take over', async () => {
    vi.useFakeTimers();
    try {
      const remove = vi.fn();
      const stalled = waitForAudioStart(() => ({ remove }), vi.fn(), 1000);
      const stalledAssertion = expect(stalled).rejects.toThrow('Audio did not start');
      await vi.advanceTimersByTimeAsync(1000);
      await stalledAssertion;
      expect(remove).toHaveBeenCalledOnce();
      let notify: ((status: { playing: boolean; didJustFinish: boolean; error?: string }) => void) | null = null;
      const failed = waitForAudioStart((listener) => { notify = listener; return { remove }; }, vi.fn());
      (notify as unknown as (status: { playing: boolean; didJustFinish: boolean; error?: string }) => void)({
        playing: false, didJustFinish: false, error: 'network',
      });
      await expect(failed).rejects.toThrow('Audio playback failed');
    } finally { vi.useRealTimers(); }
  });
});
