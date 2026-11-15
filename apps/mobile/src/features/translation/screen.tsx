import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Keyboard, Linking, Pressable, View } from 'react-native';
import * as Clipboard from 'expo-clipboard';
import { SymbolView } from 'expo-symbols';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppInput, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { useAppPalette } from '@/constants/app-theme';
import { translateText, utf8ByteLength, type Language, type SourceLanguage, type TranslateResult } from './api';
import { englishLookupWord, lookupEnglishWord, type DictionaryDetails } from './dictionary';
import { readSavedPhrases, savePhrase, type SavedPhrase } from './saved';
import { usePronunciation } from './use-pronunciation';
import { getSupabase } from '@/auth/supabase';

export function TranslationScreen() {
  const palette = useAppPalette();
  const audio = usePronunciation();
  const [source, setSource] = useState<SourceLanguage>('en');
  const [target, setTarget] = useState<Language>('vi');
  const [input, setInput] = useState('');
  const [result, setResult] = useState<TranslateResult | null>(null);
  const [dictionary, setDictionary] = useState<DictionaryDetails | null>(null);
  const [dictionaryLoading, setDictionaryLoading] = useState(false);
  const [dictionaryNotice, setDictionaryNotice] = useState('');
  const [exampleTranslation, setExampleTranslation] = useState('');
  const [exampleLoading, setExampleLoading] = useState(false);
  const [saved, setSaved] = useState<SavedPhrase[]>([]);
  const [userId, setUserId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const pending = useRef(false);
  const requestVersion = useRef(0);

  useEffect(() => {
    let live = true;
    void getSupabase().auth.getSession().then(async ({ data }) => {
      const id = data.session?.user.id;
      if (!id || !live) return;
      setUserId(id);
      const phrases = await readSavedPhrases(id);
      if (live) setSaved(phrases);
    }).catch(() => {});
    return () => { live = false; };
  }, []);

  function clearOutput() {
    requestVersion.current++;
    setResult(null);
    setDictionary(null);
    setDictionaryLoading(false);
    setDictionaryNotice('');
    setExampleTranslation('');
    setExampleLoading(false);
    setError('');
    setNotice('');
    if (audio.active || audio.loading) void audio.stop();
  }

  async function loadDetails(translated: TranslateResult, version: number) {
    const english = translated.source === 'en' ? translated.source_text : translated.translated_text ?? '';
    const word = englishLookupWord(english);
    if (!word) return;
    setDictionaryLoading(true);
    try {
      const details = await lookupEnglishWord(word);
      if (version === requestVersion.current) setDictionary(details);
    } catch (cause) {
      if (version === requestVersion.current) {
        setDictionaryNotice(cause instanceof Error ? cause.message : 'Dictionary details are unavailable.');
      }
    } finally {
      if (version === requestVersion.current) setDictionaryLoading(false);
    }
  }

  async function submit() {
    if (!input.trim() || pending.current) return;
    pending.current = true;
    Keyboard.dismiss();
    clearOutput();
    const version = requestVersion.current;
    setLoading(true);
    try {
      const translated = await translateText({ source, target, text: input });
      if (version === requestVersion.current) {
        setResult(translated);
        void loadDetails(translated, version);
      }
    } catch (cause) {
      if (version === requestVersion.current) setError(cause instanceof Error ? cause.message : 'Translation is unavailable.');
    } finally {
      pending.current = false;
      setLoading(false);
    }
  }

  async function translateExample(example: string) {
    if (exampleLoading || utf8ByteLength(example) > 500) return;
    setExampleLoading(true);
    setDictionaryNotice('');
    const version = requestVersion.current;
    try {
      const response = await translateText({ source: 'en', target: 'vi', text: example });
      if (version === requestVersion.current) setExampleTranslation(response.translated_text ?? '');
    } catch (cause) {
      if (version === requestVersion.current) setDictionaryNotice(cause instanceof Error ? cause.message : 'Could not translate the example.');
    } finally {
      if (version === requestVersion.current) setExampleLoading(false);
    }
  }

  async function save() {
    if (!result || !userId) return;
    try {
      setSaved(await savePhrase(userId, result, dictionary));
      setNotice('Saved on this device.');
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save phrase.'); }
  }

  const englishText = result ? (result.source === 'en' ? result.source_text : result.translated_text ?? '') : '';
  const firstSense = dictionary?.senses[0];
  const example = dictionary?.senses.find((sense) => !!sense.example)?.example ?? null;

  return <Page eyebrow="WORD LAB" title="Translate & learn" description="Translate a short sentence, then explore English word details when available.">
    <AppCard style={{ gap: 10 }}>
      <AppText variant="label">From</AppText>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        {(['en', 'vi'] as const).map((value) => <AppButton key={value} label={value === 'en' ? 'English' : 'Vietnamese'} variant={source === value ? 'primary' : 'secondary'} onPress={() => {
          setSource(value); if (value === target) setTarget(value === 'en' ? 'vi' : 'en'); clearOutput();
        }} />)}
      </View>
      <AppText variant="label">To</AppText>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        {(['en', 'vi'] as const).map((value) => <AppButton key={value} label={value === 'en' ? 'English' : 'Vietnamese'} variant={target === value ? 'primary' : 'secondary'} onPress={() => {
          setTarget(value); if (source === value) setSource(value === 'en' ? 'vi' : 'en'); clearOutput();
        }} />)}
      </View>
      <AppButton label="Swap languages" variant="secondary" onPress={() => { setSource(target); setTarget(source); clearOutput(); }} />
    </AppCard>
    <AppInput label="Text to translate" placeholder={source === 'vi' ? 'Thử: Giấy phép' : 'Try: License'} value={input}
      onChangeText={(value) => { setInput(value); clearOutput(); }} multiline
      style={{ minHeight: 100, textAlignVertical: 'top', paddingVertical: 14 }}
      hint={`${utf8ByteLength(input.trim())}/500 UTF-8 bytes`} />
    <View style={{ gap: 8 }}>
      <AppButton label="Translate" onPress={() => { void submit(); }} disabled={!input.trim() || loading} loading={loading} />
      {!!input && <AppButton label="Clear text" variant="secondary" onPress={() => { setInput(''); clearOutput(); }} />}
    </View>
    {loading && <LoadingSkeleton accessibilityLabel="Translating" />}
    {!!error && <ErrorState title="Translation unavailable" message={error} retry={() => { void submit(); }} />}
    {!loading && !error && !result && <EmptyState title="Ready to translate" message="Enter English or Vietnamese text and choose Translate." />}
    {result?.status === 'translated' && <AppCard tone="primary" style={{ gap: 18, padding: 20 }}>
      <View style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12 }}>
        <View style={{ flex: 1, gap: 5 }}>
          <AppText variant="caption" tone="muted">ORIGINAL · {result.source === 'en' ? 'ENGLISH' : 'VIETNAMESE'}</AppText>
          <AppText variant="heading" selectable accessibilityRole="text">{result.source_text}</AppText>
          {result.source === 'en' && !!dictionary?.ipa && <AppText tone="primary" selectable>{dictionary.ipa}</AppText>}
          {result.source === 'en' && !!firstSense?.partOfSpeech && <AppText variant="caption" tone="primary">{firstSense.partOfSpeech}</AppText>}
        </View>
        {!!englishText && <Pressable accessibilityRole="button"
          accessibilityLabel={audio.active ? 'Stop pronunciation' : 'Play English pronunciation'}
          accessibilityHint={dictionary?.audioUrl ? 'Plays dictionary audio; device voice is available as a fallback' : 'Uses the device English voice'}
          accessibilityState={{ busy: audio.loading }}
          onPress={() => { void (audio.active ? audio.stop() : audio.play(englishText, dictionary?.audioUrl ?? null)); }}
          style={({ pressed }) => ({ width: 48, height: 48, borderRadius: 24, alignItems: 'center', justifyContent: 'center',
            backgroundColor: palette.surface, borderWidth: 1, borderColor: palette.border, opacity: pressed ? 0.75 : 1 })}>
          {audio.loading ? <ActivityIndicator color={palette.primary} /> : <SymbolView
            name={{ ios: audio.active ? 'stop.fill' : 'speaker.wave.2.fill', android: audio.active ? 'stop' : 'volume_up', web: audio.active ? 'stop' : 'volume_up' }}
            size={22} tintColor={palette.primary} />}
        </Pressable>}
        <Pressable accessibilityRole="button" accessibilityLabel="Save translation" onPress={() => { void save(); }}
          disabled={!userId} accessibilityState={{ disabled: !userId }}
          style={({ pressed }) => ({ width: 48, height: 48, borderRadius: 24, alignItems: 'center', justifyContent: 'center',
            backgroundColor: palette.surface, borderWidth: 1, borderColor: palette.border, opacity: !userId ? 0.5 : pressed ? 0.75 : 1 })}>
          <SymbolView name={{ ios: 'bookmark', android: 'bookmark_border', web: 'bookmark_border' }} size={22} tintColor={palette.primary} />
        </Pressable>
      </View>
      <View style={{ height: 1, backgroundColor: palette.border }} />
      <View style={{ gap: 5 }}>
        <AppText variant="caption" tone="primary">{result.target === 'vi' ? 'NGHĨA TIẾNG VIỆT' : 'ENGLISH TRANSLATION'}</AppText>
        <AppText variant="heading" selectable accessibilityRole="text">{result.translated_text}</AppText>
        {result.target === 'en' && !!dictionary?.ipa && <AppText tone="primary" selectable>{dictionary.ipa}</AppText>}
        {result.target === 'en' && !!firstSense?.partOfSpeech && <AppText variant="caption" tone="primary">{firstSense.partOfSpeech}</AppText>}
      </View>
      {!!englishText && !!dictionary?.audioUrl && !!audio.error && <AppButton label="Use device voice" variant="ghost"
        onPress={() => { void audio.play(englishText, null); }} />}
      {!!audio.error && <AppText tone="error" accessibilityRole="alert">{audio.error}</AppText>}
      {dictionaryLoading && <AppText variant="caption" tone="muted">Loading English word details…</AppText>}
      {!!dictionaryNotice && <AppText variant="caption" tone="muted">{dictionaryNotice}</AppText>}
      {!!example && <View style={{ gap: 8, padding: 14, borderRadius: 16, backgroundColor: palette.surface }}>
        <AppText variant="caption" tone="primary">EXAMPLE IN CONTEXT</AppText>
        <AppText selectable>{example}</AppText>
        {!!exampleTranslation && <AppText tone="muted" selectable>{exampleTranslation}</AppText>}
        {!exampleTranslation && utf8ByteLength(example) <= 500 && <AppButton label="Translate example to Vietnamese"
          variant="secondary" loading={exampleLoading} onPress={() => { void translateExample(example); }} />}
      </View>}
      {!!dictionary && dictionary.senses.length > 0 && <View style={{ gap: 8 }}>
        <AppText variant="label">English definitions</AppText>
        {dictionary.senses.map((sense, index) => <AppText key={`${index}:${sense.definition}`} tone="muted" selectable>
          {sense.partOfSpeech ? `${sense.partOfSpeech} · ` : ''}{sense.definition}
        </AppText>)}
      </View>}
      {!!dictionary && dictionary.synonyms.length > 0 && <View style={{ gap: 8 }}>
        <AppText variant="caption" tone="primary">RELATED ENGLISH WORDS</AppText>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 7 }}>
          {dictionary.synonyms.map((word) => <View key={word} style={{ borderRadius: 12, paddingHorizontal: 10, paddingVertical: 7, backgroundColor: palette.surface }}>
            <AppText variant="caption" selectable>{word}</AppText>
          </View>)}
        </View>
      </View>}
      {!!dictionary && dictionary.antonyms.length > 0 && <View style={{ gap: 4 }}>
        <AppText variant="caption" tone="primary">ANTONYMS</AppText><AppText tone="muted" selectable>{dictionary.antonyms.join(' · ')}</AppText>
      </View>}
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        <AppButton label="Copy translation" style={{ flexGrow: 1, flexBasis: 140, paddingHorizontal: 8 }} onPress={() => {
          if (result.translated_text) void Clipboard.setStringAsync(result.translated_text)
            .then(() => setNotice('Copied.')).catch(() => setError('Could not copy translation.'));
        }} />
        <AppButton label="Save phrase" variant="secondary" style={{ flexGrow: 1, flexBasis: 140, paddingHorizontal: 8 }} disabled={!userId} onPress={() => { void save(); }} />
      </View>
      {!!notice && <AppText variant="caption" tone="success" accessibilityRole="alert">{notice}</AppText>}
      {!!dictionary && <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 6, alignItems: 'center' }}>
        <AppText variant="caption" tone="muted">Free Dictionary API{dictionary.licenseName ? ` · ${dictionary.licenseName}` : ''}</AppText>
        {!!dictionary.sourceUrl && <AppText variant="caption" tone="primary" accessibilityRole="link" onPress={() => {
          void Linking.openURL(dictionary.sourceUrl!).catch(() => setDictionaryNotice('Could not open the dictionary source.'));
        }}>Source</AppText>}
        {!!dictionary.licenseUrl && <AppText variant="caption" tone="primary" accessibilityRole="link" onPress={() => {
          void Linking.openURL(dictionary.licenseUrl!).catch(() => setDictionaryNotice('Could not open the license.'));
        }}>License</AppText>}
      </View>}
    </AppCard>}
    <View style={{ gap: 10 }}>
      <AppText variant="heading">Saved on this device</AppText>
      {saved.length ? saved.map((item) => <AppCard key={`${item.source}:${item.source_text}`} style={{ gap: 4 }}>
        <AppText variant="label">{item.source_text}</AppText>
        <AppText>{item.translated_text}</AppText>
        {!!item.ipa && <AppText variant="caption" tone="muted">{item.ipa}</AppText>}
        {!!item.part_of_speech && <AppText variant="caption" tone="muted">{item.part_of_speech}</AppText>}
      </AppCard>) : <EmptyState title="No saved phrases" message="Save a translation to find it here later on this device." />}
    </View>
    <NavLink href="/home" label="Back to dashboard" />
  </Page>;
}
