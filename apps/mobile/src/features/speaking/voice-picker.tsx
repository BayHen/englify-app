import { useMemo, useState } from 'react';
import { FlatList, Pressable, TextInput, View, useWindowDimensions } from 'react-native';
import { SymbolView } from 'expo-symbols';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppBottomSheet, AppButton, AppText } from '@/ui';
import { accentLabels, availableAccents, filterVoices, voiceLocaleLabel, type Accent } from './voice-catalog';
import type { SpeechVoice } from './speech-provider';

export function ReferenceVoiceSelector({ voice, loading, disabled, onPress }: { voice: SpeechVoice | null; loading: boolean; disabled: boolean; onPress: () => void }) {
  const palette = useAppPalette();
  return <Pressable accessibilityRole="button" accessibilityLabel={voice ? `Reference voice: ${voice.name}, ${voiceLocaleLabel(voice)}. Change voice.` : 'Choose a reference voice'} accessibilityState={{ disabled, busy: loading }} disabled={disabled} onPress={onPress} style={({ pressed }) => ({ minHeight: 72, borderRadius: designTokens.radius.lg, borderWidth: 1, borderColor: palette.border, backgroundColor: palette.surface, paddingHorizontal: designTokens.spacing.lg, flexDirection: 'row', alignItems: 'center', gap: designTokens.spacing.md, opacity: disabled ? 0.55 : pressed ? 0.78 : 1 })}>
    <SymbolView name={{ ios: 'speaker.wave.2.fill', android: 'volume_up', web: 'volume_up' }} size={25} tintColor={palette.primary} />
    <View style={{ flex: 1, minWidth: 0 }}><AppText variant="label" numberOfLines={1}>{loading ? 'Loading device voices…' : voice?.name || 'Choose a reference voice'}</AppText><AppText variant="caption" tone="muted" numberOfLines={1}>{voice ? voiceLocaleLabel(voice) : 'Device default voice is available as a fallback'}</AppText></View>
    <SymbolView name={{ ios: 'chevron.down', android: 'keyboard_arrow_down', web: 'keyboard_arrow_down' }} size={20} tintColor={palette.muted} />
  </Pressable>;
}

function VoiceListItem({ voice, selected, onPress }: { voice: SpeechVoice; selected: boolean; onPress: () => void }) {
  const palette = useAppPalette();
  return <Pressable accessibilityRole="radio" accessibilityLabel={`${voice.name}, ${voiceLocaleLabel(voice)}`} accessibilityState={{ selected }} onPress={onPress} style={({ pressed }) => ({ minHeight: 64, flexDirection: 'row', alignItems: 'center', gap: designTokens.spacing.md, paddingVertical: designTokens.spacing.sm, borderBottomWidth: 1, borderColor: palette.border, opacity: pressed ? 0.7 : 1 })}>
    <View style={{ flex: 1, minWidth: 0, gap: 2 }}><AppText variant="label" numberOfLines={1}>{voice.name}</AppText><AppText variant="caption" tone="muted">{voiceLocaleLabel(voice)}</AppText></View>
    {selected ? <SymbolView name={{ ios: 'checkmark.circle.fill', android: 'check_circle', web: 'check_circle' }} size={22} tintColor={palette.primary} /> : null}
  </Pressable>;
}

export function VoicePickerSheet({ visible, voices, selectedId, loading, error, emptyMessage, onSelect, onClose, onRetry }: { visible: boolean; voices: SpeechVoice[]; selectedId: string | null; loading: boolean; error: string; emptyMessage: string; onSelect: (voice: SpeechVoice) => void; onClose: () => void; onRetry: () => void }) {
  const palette = useAppPalette();
  const { height } = useWindowDimensions();
  const [query, setQuery] = useState('');
  const [accent, setAccent] = useState<Accent>('all');
  const accents = useMemo(() => availableAccents(voices), [voices]);
  const filtered = useMemo(() => filterVoices(voices, query, accent), [voices, query, accent]);
  return <AppBottomSheet visible={visible} title="Choose a voice" onClose={onClose} scrollable={false}>
    <View style={{ gap: designTokens.spacing.md }}>
      <TextInput accessibilityLabel="Search voices" placeholder="Search name or locale" placeholderTextColor={palette.muted} value={query} onChangeText={setQuery} autoCorrect={false} style={{ minHeight: 48, borderRadius: designTokens.radius.md, borderWidth: 1, borderColor: palette.border, backgroundColor: palette.input, color: palette.text, fontSize: designTokens.typography.size.md, paddingHorizontal: designTokens.spacing.lg }} />
      {voices.length > 0 ? <View accessibilityRole="radiogroup" style={{ flexDirection: 'row', flexWrap: 'wrap', gap: designTokens.spacing.sm }}>{accents.map((item) => <Pressable key={item} accessibilityRole="radio" accessibilityLabel={`${accentLabels[item]} accent`} accessibilityState={{ selected: accent === item }} onPress={() => setAccent(item)} style={({ pressed }) => ({ minHeight: 40, minWidth: 44, paddingHorizontal: designTokens.spacing.md, justifyContent: 'center', alignItems: 'center', borderRadius: designTokens.radius.pill, backgroundColor: accent === item ? palette.primarySoft : palette.surface, borderWidth: 1, borderColor: accent === item ? palette.primary : palette.border, opacity: pressed ? 0.7 : 1 })}><AppText variant="caption" style={{ color: accent === item ? palette.primary : palette.text }}>{accentLabels[item]}</AppText></Pressable>)}</View> : null}
      {loading ? <AppText tone="muted">Loading device voices…</AppText> : error ? <View style={{ gap: designTokens.spacing.sm }}><AppText tone="error" accessibilityRole="alert">{error}</AppText><AppButton label="Try again" variant="secondary" onPress={onRetry} /></View> : voices.length === 0 ? <View style={{ gap: designTokens.spacing.sm }}><AppText tone="muted">{emptyMessage}</AppText><AppButton label="Refresh device voices" variant="secondary" onPress={onRetry} /></View> : filtered.length === 0 ? <AppText tone="muted">No voices match your search.</AppText> : <FlatList data={filtered} keyExtractor={(voice) => voice.id} renderItem={({ item }) => <VoiceListItem voice={item} selected={item.id === selectedId} onPress={() => onSelect(item)} />} style={{ maxHeight: Math.max(150, Math.min(350, height * 0.42)) }} initialNumToRender={10} windowSize={5} keyboardShouldPersistTaps="handled" contentInsetAdjustmentBehavior="automatic" />}
    </View>
  </AppBottomSheet>;
}
