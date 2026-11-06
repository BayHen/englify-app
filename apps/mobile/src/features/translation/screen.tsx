import { useEffect, useState } from 'react';
import { View } from 'react-native';
import * as Clipboard from 'expo-clipboard';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppInput, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { getPhrases, translateText, type Language, type Phrase, type TranslateResult } from './api';
import { readSavedPhrases, savePhrase, type SavedPhrase } from './saved';
import { getSupabase } from '@/auth/supabase';

export function TranslationScreen() {
  const [source, setSource] = useState<Language>('en');
  const target: Language = source === 'en' ? 'vi' : 'en';
  const [input, setInput] = useState('');
  const [result, setResult] = useState<TranslateResult | null>(null);
  const [phrases, setPhrases] = useState<Phrase[]>([]);
  const [saved, setSaved] = useState<SavedPhrase[]>([]);
  const [userId, setUserId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  useEffect(() => {
    void getSupabase().auth.getSession().then(({ data }) => {
      const id = data.session?.user.id;
      if (id) { setUserId(id); void readSavedPhrases(id).then(setSaved); }
    });
    void getPhrases().then(setPhrases).catch(() => { /* Suggestions are optional. */ });
  }, []);

  async function submit() {
    if (!input.trim()) return;
    setLoading(true); setError(''); setResult(null); setNotice('');
    try { setResult(await translateText({ source, target, text: input.trim() })); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Translation is unavailable.'); }
    finally { setLoading(false); }
  }

  async function save() {
    if (!result || !userId) return;
    try { setSaved(await savePhrase(userId, result)); setNotice('Saved on this device.'); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save phrase.'); }
  }

  return <Page eyebrow="LANGUAGE TOOLS" title="Translation" description="Exact phrasebook lookup is available now. Full-text translation requires a verified self-hosted provider.">
    <AppCard style={{ gap: 10 }}>
      <AppText variant="label">From {source === 'en' ? 'English' : 'Vietnamese'} to {target === 'vi' ? 'Vietnamese' : 'English'}</AppText>
      <AppButton label="Swap languages" variant="secondary" onPress={() => { setSource(target); setInput(''); setResult(null); setError(''); }} />
    </AppCard>
    <AppInput label="Text to translate" placeholder={source === 'en' ? 'Try Hello.' : 'Thử Xin chào.'} value={input} onChangeText={(text) => { setInput(text); setResult(null); }} multiline maxLength={500} style={{ minHeight: 110, textAlignVertical: 'top', paddingVertical: 14 }} hint={`${input.length}/500 characters`} />
    <AppButton label="Translate" onPress={() => { void submit(); }} disabled={!input.trim()} loading={loading} />
    {loading && <LoadingSkeleton accessibilityLabel="Translating" />}
    {!!error && <ErrorState title="Translation unavailable" message={error} retry={() => { void submit(); }} />}
    {!loading && !error && !result && <EmptyState title="Ready to translate" message="Enter a phrase or choose a curated suggestion below." />}
    {result?.status === 'unavailable' && <EmptyState title="No verified translation" message="This text has no exact phrasebook match, and full-text translation is not available. Try a phrase below." />}
    {result?.status === 'translated' && <AppCard tone="primary" style={{ gap: 10 }}>
      <AppText variant="caption" tone="primary">{result.scope === 'exact_phrase' ? 'EXACT PHRASEBOOK MATCH' : 'FULL-TEXT MACHINE TRANSLATION'}</AppText>
      <AppText variant="heading" accessibilityRole="text">{result.translated_text}</AppText>
      <AppText variant="caption" tone="muted">{result.message}</AppText>
      <View style={{ gap: 8 }}><AppButton label="Copy translation" variant="secondary" onPress={() => { if (result.translated_text) void Clipboard.setStringAsync(result.translated_text).then(() => setNotice('Copied.')).catch(() => setError('Could not copy translation.')); }} />
        <AppButton label="Save useful phrase" variant="secondary" onPress={() => { void save(); }} /></View>
      {!!notice && <AppText variant="caption" tone="success" accessibilityRole="alert">{notice}</AppText>}
    </AppCard>}
    <View style={{ gap: 10 }}><AppText variant="heading">Curated phrases</AppText>
      {phrases.length ? phrases.map((phrase) => <AppCard key={phrase.en} onPress={() => { setInput(phrase[source]); setResult(null); }} accessibilityLabel={`Use ${phrase[source]}`}><AppText>{phrase[source]}</AppText><AppText tone="muted">{phrase[target]}</AppText></AppCard>) : <AppText tone="muted">Suggestions load when the API is available.</AppText>}
    </View>
    <View style={{ gap: 10 }}><AppText variant="heading">Saved on this device</AppText>
      {saved.length ? saved.map((item) => <AppCard key={`${item.source}:${item.source_text}`}><AppText variant="label">{item.source_text}</AppText><AppText>{item.translated_text}</AppText><AppText variant="caption" tone="muted">{item.scope === 'exact_phrase' ? 'Exact phrase match' : 'Machine translation'}</AppText></AppCard>) : <EmptyState title="No saved phrases" message="Save a translated phrase to find it here later on this device." />}
    </View>
    <NavLink href="/home" label="Back to dashboard" />
  </Page>;
}
