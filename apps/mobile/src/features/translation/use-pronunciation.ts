import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';
import * as Speech from 'expo-speech';
import { setAudioModeAsync, useAudioPlayer, useAudioPlayerStatus } from 'expo-audio';
import { startPronunciation, waitForAudioStart } from './audio-control';

export function usePronunciation() {
  const player = useAudioPlayer(null);
  const status = useAudioPlayerStatus(player);
  const [mode, setMode] = useState<'audio' | 'speech' | null>(null);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState('');
  const session = useRef(0);
  const audioListener = useRef<{ remove: () => void } | null>(null);

  const stop = useCallback(async () => {
    session.current++;
    audioListener.current?.remove();
    audioListener.current = null;
    player.pause();
    await Speech.stop();
    setMode(null);
    setStarting(false);
  }, [player]);

  useEffect(() => {
    const listener = AppState.addEventListener('change', (state) => {
      if (state !== 'active') void stop();
    });
    return () => {
      listener.remove();
      // The current session must be invalidated when this screen unmounts.
      // eslint-disable-next-line react-hooks/exhaustive-deps
      session.current++;
      audioListener.current?.remove();
      audioListener.current = null;
      player.pause();
      void Speech.stop();
    };
  }, [player, stop]);

  async function play(text: string, audioUrl: string | null) {
    if (!text.trim() || starting) return;
    const currentSession = ++session.current;
    audioListener.current?.remove();
    audioListener.current = null;
    setStarting(true);
    setError('');
    const speak = (value: string) => Speech.speak(value, {
      language: 'en-US', rate: 0.9,
      onDone: () => { if (currentSession === session.current) setMode(null); },
      onStopped: () => { if (currentSession === session.current) setMode(null); },
      onError: () => {
        if (currentSession === session.current) { setMode(null); setError('Device voice is unavailable.'); }
      },
    });
    try {
      const next = await startPronunciation(text, audioUrl, {
        isCurrent: () => currentSession === session.current,
        stopSpeech: () => Speech.stop(),
        stopAudio: () => player.pause(),
        playAudio: async (url) => {
          await setAudioModeAsync({ allowsRecording: false, playsInSilentMode: true });
          await waitForAudioStart(
            (listener) => player.addListener('playbackStatusUpdate', listener),
            () => { player.replace(url); player.play(); },
          );
        },
        speak,
      });
      if (currentSession !== session.current) return;
      setMode(next);
      if (next === 'audio') {
        const fallbackToDeviceVoice = () => {
          if (currentSession !== session.current) return;
          audioListener.current?.remove();
          audioListener.current = null;
          player.pause();
          try {
            speak(text);
            setMode('speech');
            setError('');
          } catch {
            setMode(null);
            setError('Pronunciation is unavailable right now.');
          }
        };
        audioListener.current = player.addListener('playbackStatusUpdate', (nextStatus) => {
          if (nextStatus.error) fallbackToDeviceVoice();
          else if (nextStatus.didJustFinish) {
            audioListener.current?.remove();
            audioListener.current = null;
            setMode(null);
          }
        });
        if (player.currentStatus.error) fallbackToDeviceVoice();
      }
    } catch {
      if (currentSession === session.current) { setError('Pronunciation is unavailable right now.'); setMode(null); }
    } finally { if (currentSession === session.current) setStarting(false); }
  }

  return { play, stop, active: mode === 'speech' || (mode === 'audio' && !status.didJustFinish && !status.error),
    loading: starting,
    error: error || (mode === 'audio' && status.error ? 'Audio playback failed. Try the device voice.' : '') };
}
