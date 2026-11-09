import { useCallback, useEffect, useRef } from 'react';
import { AppState, Platform } from 'react-native';
import * as Speech from 'expo-speech';
import { File } from 'expo-file-system';
import { AudioModule, RecordingPresets, setAudioModeAsync, useAudioPlayer, useAudioRecorder, useAudioRecorderState } from 'expo-audio';

export type SpeechVoice = { id: string; name: string; language: string; locale: string; quality?: string };
export type RecordingResult = { uri: string; durationMillis: number };

export interface SpeechProvider {
  getVoices(): Promise<SpeechVoice[]>;
  speak(text: string, voiceId: string | null): Promise<void>;
  stopSpeech(): Promise<void>;
  startRecording(): Promise<'granted' | 'denied'>;
  stopRecording(): Promise<RecordingResult>;
  play(uri: string): Promise<void>;
  stopPlayback(): Promise<void>;
  deleteAudio(uri: string): Promise<void>;
  readonly isRecording: boolean;
  readonly durationMillis: number;
}

export function useExpoSpeechProvider(): SpeechProvider {
  const recorder = useAudioRecorder({ ...RecordingPresets.HIGH_QUALITY, directory: 'document' });
  const recorderState = useAudioRecorderState(recorder);
  const player = useAudioPlayer(null);
  const recording = useRef(false);
  const discarded = useRef(false);

  const deleteAudio = useCallback(async (uri: string) => {
    if (Platform.OS === 'web') {
      if (uri.startsWith('blob:')) URL.revokeObjectURL(uri);
      return;
    }
    const file = new File(uri);
    if (file.exists) file.delete();
  }, []);

  useEffect(() => {
    const listener = AppState.addEventListener('change', (state) => {
      if (state === 'active') return;
      void Speech.stop();
      player.pause();
      if (recording.current) {
        recording.current = false;
        discarded.current = true;
        void recorder.stop().then(async () => { if (recorder.uri) await deleteAudio(recorder.uri); });
      }
    });
    return () => {
      listener.remove();
      void Speech.stop();
      player.pause();
      if (recording.current) {
        recording.current = false;
        void recorder.stop().then(async () => { if (recorder.uri) await deleteAudio(recorder.uri); });
      }
    };
  }, [deleteAudio, player, recorder]);

  return {
    async getVoices() {
      const voices = await Speech.getAvailableVoicesAsync();
      return voices.map(({ identifier, name, language, quality }) => ({ id: identifier, name, language, locale: language, quality }));
    },
    async speak(text, voiceId) {
      await Speech.stop();
      player.pause();
      Speech.speak(text, { language: voiceId ? undefined : 'en-US', voice: voiceId ?? undefined, rate: 0.85 });
    },
    stopSpeech: () => Speech.stop(),
    async startRecording() {
      const permission = await AudioModule.requestRecordingPermissionsAsync();
      if (!permission.granted) return 'denied';
      await Speech.stop();
      player.pause();
      await setAudioModeAsync({ allowsRecording: true, playsInSilentMode: true });
      await recorder.prepareToRecordAsync();
      recorder.record();
      discarded.current = false;
      recording.current = true;
      return 'granted';
    },
    async stopRecording() {
      if (!recording.current) throw new Error('No recording is in progress.');
      recording.current = false;
      const durationMillis = recorder.getStatus().durationMillis;
      await recorder.stop();
      await setAudioModeAsync({ allowsRecording: false, playsInSilentMode: true });
      if (discarded.current || !recorder.uri) throw new Error('Recording was interrupted. Please retry.');
      return { uri: recorder.uri, durationMillis };
    },
    async play(uri) {
      await Speech.stop();
      await setAudioModeAsync({ allowsRecording: false, playsInSilentMode: true });
      player.replace(uri);
      player.play();
    },
    async stopPlayback() { player.pause(); },
    deleteAudio,
    isRecording: recorderState.isRecording,
    durationMillis: recorderState.durationMillis,
  };
}
