import { useEffect, useState } from 'react';
import { AccessibilityInfo, Linking, Platform, View } from 'react-native';
import { Page, NavLink } from '@/components/page';
import { useAuth } from '@/auth/provider';
import { AppButton, AppCard, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { practicePrompts } from './practice-data';
import { completeTake, type PracticeHistory } from './practice-history';
import { readPracticeHistory, writePracticeHistory } from './practice-storage';
import { useExpoSpeechProvider, type SpeechVoice } from './speech-provider';
import { isEnglishVoice, preferredVoice } from './voice-catalog';
import { readVoicePreference, writeVoicePreference } from './voice-preference';
import { ReferenceVoiceSelector, VoicePickerSheet } from './voice-picker';

export function SpeakingScreen() {
  const { profile } = useAuth();
  return <SpeakingSession key={profile?.id ?? 'guest'} userId={profile?.id} />;
}

function SpeakingSession({ userId }: { userId: string | undefined }) {
  const speech = useExpoSpeechProvider();
  const [promptId, setPromptId] = useState(practicePrompts[0].id);
  const [voices, setVoices] = useState<SpeechVoice[]>([]);
  const [voiceId, setVoiceId] = useState<string | null>(null);
  const [voiceLoading, setVoiceLoading] = useState(true);
  const [voiceError, setVoiceError] = useState('');
  const [voiceEmptyMessage, setVoiceEmptyMessage] = useState('No English voices are installed. Close this sheet to use the device default voice.');
  const [voicePickerOpen, setVoicePickerOpen] = useState(false);
  const [history, setHistory] = useState<PracticeHistory | null>(null);
  const [webUri, setWebUri] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [permissionDenied, setPermissionDenied] = useState(false);
  const prompt = practicePrompts.find((item) => item.id === promptId) ?? practicePrompts[0];
  const currentUri = Platform.OS === 'web' ? webUri : history?.recordings[promptId] ?? null;
  const takeCompleted = !!currentUri && history?.completedTakes[promptId] === currentUri;
  const selectedVoice = voices.find((voice) => voice.id === voiceId) ?? null;

  useEffect(() => {
    let live = true;
    if (userId) void readPracticeHistory(userId).then((data) => { if (live) setHistory(data); }).catch(() => { if (live) setError('Could not read local practice history.'); });
    void (async () => {
      try {
        const [available, storedId] = await Promise.all([speech.getVoices(), userId ? readVoicePreference(userId).catch(() => null) : Promise.resolve(null)]);
        if (!live) return;
        const english = available.filter(isEnglishVoice);
        setVoiceEmptyMessage(available.length ? 'This device has no English voices. Close this sheet to try the device default.' : 'No device voices were listed. Close this sheet to try the device default.');
        const selected = preferredVoice(english, storedId);
        setVoices(english);
        setVoiceId(selected?.id ?? null);
        setVoiceError('');
        if (userId && selected && selected.id !== storedId) void writeVoicePreference(userId, selected.id).catch(() => undefined);
      } catch { if (live) { setVoices([]); setVoiceId(null); setVoiceError('Device voices are temporarily unavailable. You can still try the default voice.'); } }
      finally { if (live) setVoiceLoading(false); }
    })();
    return () => { live = false; };
    // The provider owns recorder/player lifecycle. Reload only for account changes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  async function retryVoices() {
    setVoiceLoading(true); setVoiceError('');
    try {
      const all = await speech.getVoices();
      const available = all.filter(isEnglishVoice);
      setVoiceEmptyMessage(all.length ? 'This device has no English voices. Close this sheet to try the device default.' : 'No device voices were listed. Close this sheet to try the device default.');
      const selected = preferredVoice(available, voiceId);
      setVoices(available); setVoiceId(selected?.id ?? null);
    } catch { setVoiceError('Device voices are temporarily unavailable. You can still try the default voice.'); }
    finally { setVoiceLoading(false); }
  }

  function selectVoice(voice: SpeechVoice) {
    setVoiceId(voice.id);
    setVoicePickerOpen(false);
    if (Platform.OS !== 'web') AccessibilityInfo.announceForAccessibility(`${voice.name} selected`);
    if (userId) void writeVoicePreference(userId, voice.id).catch(() => setError('Voice selection could not be saved on this device.'));
  }

  async function run(action: () => Promise<void>) {
    if (busy) return;
    setBusy(true); setError('');
    try { await action(); } catch (cause) { setError(cause instanceof Error ? cause.message : 'Audio action failed.'); }
    finally { setBusy(false); }
  }

  async function start() {
    await run(async () => {
      const result = await speech.startRecording();
      if (result === 'denied') {
        setPermissionDenied(true);
        setError('Microphone permission is required to record. You can still listen to the reference.');
      } else setPermissionDenied(false);
    });
  }

  async function stop() {
    await run(async () => {
      const result = await speech.stopRecording();
      if (result.durationMillis < 500) {
        await speech.deleteAudio(result.uri);
        throw new Error('Recording was too short. Please try again.');
      }
      if (!userId || !history) throw new Error('Your local practice history is not ready.');
      const previous = currentUri;
      const next = Platform.OS === 'web' ? history : { ...history, recordings: { ...history.recordings, [promptId]: result.uri } };
      try { await writePracticeHistory(userId, next); }
      catch (cause) { await speech.deleteAudio(result.uri); throw cause; }
      setHistory(next);
      if (Platform.OS === 'web') setWebUri(result.uri);
      if (previous && previous !== result.uri) await speech.deleteAudio(previous);
    });
  }

  async function removeRecording() {
    if (!userId || !history || !currentUri) return;
    await run(async () => {
      await speech.stopPlayback();
      await speech.deleteAudio(currentUri);
      const recordings = { ...history.recordings };
      delete recordings[promptId];
      const next = { ...history, recordings };
      await writePracticeHistory(userId, next);
      setHistory(next);
      if (Platform.OS === 'web') setWebUri(null);
    });
  }

  async function markComplete() {
    if (!userId || !history || !currentUri || takeCompleted) return;
    await run(async () => {
      const next = completeTake(history, promptId, currentUri);
      await writePracticeHistory(userId, next);
      setHistory(next);
    });
  }

  return <Page eyebrow="SPEAKING PRACTICE" title="Listen, say, compare" description="Practice with your device voice and your own recording. No speech recognition or pronunciation score is used.">
    <AppCard tone="primary" style={{ gap: 8 }}><AppText variant="heading">Local sessions completed: {history?.completed ?? 0}</AppText><AppText tone="muted">Only a count and your latest recording for each prompt are stored on this device. Audio is never uploaded.</AppText></AppCard>
    {!history && !error ? <LoadingSkeleton lines={2} /> : null}
    <View style={{ gap: 8 }}><AppText variant="heading">Choose a line</AppText>{practicePrompts.map((item) => <AppButton key={item.id} label={item.text} variant={item.id === promptId ? 'primary' : 'secondary'} disabled={speech.isRecording || busy} onPress={() => { void speech.stopPlayback(); if (Platform.OS === 'web' && webUri) { void speech.deleteAudio(webUri); setWebUri(null); } setPromptId(item.id); }} />)}</View>
    <AppCard style={{ gap: 10 }}><AppText variant="caption" tone="primary">REFERENCE TEXT</AppText><AppText variant="title">{prompt.text}</AppText><AppText tone="muted">{prompt.hint}</AppText><AppText>Read the line while listening. Compare the written words with what you hear in your recording; this is a self-check.</AppText></AppCard>
    <View style={{ gap: 8 }}><AppText variant="heading">Reference voice</AppText><ReferenceVoiceSelector voice={selectedVoice} loading={voiceLoading} disabled={speech.isRecording || voiceLoading} onPress={() => setVoicePickerOpen(true)} />{!voiceLoading && voices.length === 0 ? <AppText variant="caption" tone="muted">No English voice was listed. Playback will try the device default.</AppText> : null}<AppButton label="Play reference" disabled={speech.isRecording || busy} onPress={() => { void run(() => speech.speak(prompt.text, voiceId)); }} /><AppButton label="Stop reference" variant="secondary" onPress={() => { void speech.stopSpeech(); }} /></View>
    <VoicePickerSheet visible={voicePickerOpen} voices={voices} selectedId={voiceId} loading={voiceLoading} error={voiceError} emptyMessage={voiceEmptyMessage} onSelect={selectVoice} onClose={() => setVoicePickerOpen(false)} onRetry={() => { void retryVoices(); }} />
    <AppCard style={{ gap: 10 }}><AppText variant="heading">Your recording</AppText><AppText tone="muted">{speech.isRecording ? `Recording… ${Math.round(speech.durationMillis / 1000)} s` : currentUri ? 'Latest take is stored locally.' : 'No recording yet.'}</AppText>{speech.isRecording ? <AppButton label="Stop recording" onPress={() => { void stop(); }} disabled={busy} /> : <AppButton label={currentUri ? 'Record a new take' : 'Start recording'} onPress={() => { void start(); }} disabled={busy || !history} />}{!!currentUri && !speech.isRecording && <><AppButton label="Play my recording" variant="secondary" onPress={() => { void run(() => speech.play(currentUri)); }} disabled={busy} /><AppButton label="Stop playback" variant="secondary" onPress={() => { void speech.stopPlayback(); }} /><AppButton label={takeCompleted ? 'Practice recorded' : 'I completed this practice'} onPress={() => { void markComplete(); }} disabled={busy || takeCompleted} /><AppButton label="Delete this recording" variant="secondary" onPress={() => { void removeRecording(); }} disabled={busy} /></>}</AppCard>
    {permissionDenied && <AppButton label="Open app settings for microphone permission" variant="secondary" onPress={() => { void Linking.openSettings(); }} />}
    {!!error && <ErrorState message={error} retry={() => setError('')} />}
    {!currentUri && !speech.isRecording && <EmptyState title="Ready when you are" message="Listen to the reference, then record a short take. You can delete it at any time." />}
    {Platform.OS === 'web' && <AppText variant="caption" tone="muted">On web, recording playback is available only in this browser session; the browser may remove the audio after reload.</AppText>}
    <NavLink href="/home" label="Back to dashboard" />
  </Page>;
}
