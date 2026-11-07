import { useEffect, useState } from 'react';
import { View } from 'react-native';
import * as Speech from 'expo-speech';
import { Page, NavLink } from '@/components/page';
import { useAuth } from '@/auth/provider';
import { ApiError } from '@/lib/api';
import { AppButton, AppCard, AppInput, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { getCachedSavedWords, getRecentSearches, cacheSavedWords, cacheWords, rememberSearch, searchCachedWords } from './cache';
import { listSavedWords, removeSavedWord, saveWord, searchDictionary } from './api';
import type { DictionaryWord, SavedWord } from './types';
import * as Crypto from 'expo-crypto';
import { listEvents, queueEvent } from '@/features/offline/storage';
import { SyncStatus } from '@/features/offline/sync-status';

type Tab = 'search' | 'saved' | 'recent' | 'flashcards';

function WordCard({ word, saved, onSave, onSpeak }: {
  word: DictionaryWord; saved: boolean; onSave: () => void; onSpeak: () => void;
}) {
  return <AppCard style={{ gap: 8 }}>
    <AppText variant="heading">{word.term} {word.ipa && <AppText variant="caption" tone="muted">{word.ipa}</AppText>}</AppText>
    <AppText variant="label" tone="primary">{word.part_of_speech ?? 'word'} · {word.translation ?? 'Meaning unavailable'}</AppText>
    <AppText>{word.definition}</AppText>
    {!!word.example && <AppText tone="muted">“{word.example}”</AppText>}
    <AppText variant="caption" tone="muted">{word.source_name} · {word.license_id}</AppText>
    <View style={{ gap: 8 }}>
      <AppButton label={`Pronounce ${word.term}`} variant="secondary" onPress={onSpeak} accessibilityHint="Uses the device English text-to-speech voice" />
      <AppButton label={saved ? 'Remove from saved words' : 'Save word'} variant={saved ? 'ghost' : 'primary'} onPress={onSave} />
    </View>
  </AppCard>;
}

export function DictionaryScreen() {
  const { profile, signOut } = useAuth();
  const userId = profile?.id ?? '';
  const [tab, setTab] = useState<Tab>('search');
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<DictionaryWord[]>([]);
  const [saved, setSaved] = useState<SavedWord[]>([]);
  const [recent, setRecent] = useState<string[]>([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [offline, setOffline] = useState(false);
  const [flashcardIndex, setFlashcardIndex] = useState(0);
  const [revealed, setRevealed] = useState(false);

  async function loadSaved(id: string) {
    const cached = await getCachedSavedWords(id);
    setSaved(cached);
    try {
      const remote = await listSavedWords();
      const pendingIds = new Set((await listEvents(id)).filter((event) => event.status === 'pending' && event.kind === 'save_word').map((event) => (event.payload as { wordId: string }).wordId));
      const merged = [...remote, ...cached.filter((item) => pendingIds.has(item.word.id) && !remote.some((entry) => entry.word.id === item.word.id))];
      setSaved(merged); await cacheSavedWords(id, merged);
    } catch (cause) {
      if (cause instanceof ApiError && cause.status === 401) { void signOut(); return; }
      setOffline(true);
    }
  }

  useEffect(() => {
    if (!userId) return;
    let live = true;
    void (async () => {
      try {
        const [cached, past, stored] = await Promise.all([
          searchCachedWords(''), getRecentSearches(userId), getCachedSavedWords(userId),
        ]);
        if (!live) return;
        setResults(cached); setRecent(past); setSaved(stored);
        try {
          const [remoteWords, remoteSaved] = await Promise.all([searchDictionary(''), listSavedWords()]);
          if (!live) return;
          const pendingIds = new Set((await listEvents(userId)).filter((event) => event.status === 'pending' && event.kind === 'save_word').map((event) => (event.payload as { wordId: string }).wordId));
          const merged = [...remoteSaved, ...stored.filter((item) => pendingIds.has(item.word.id) && !remoteSaved.some((entry) => entry.word.id === item.word.id))];
          setResults(remoteWords); setSaved(merged); setOffline(false);
          await Promise.all([cacheWords(remoteWords), cacheSavedWords(userId, merged)]);
        } catch (cause) {
          if (cause instanceof ApiError && cause.status === 401) { void signOut(); return; }
          if (live) setOffline(true);
        }
      } catch (cause) { if (live) setError(cause instanceof Error ? cause.message : 'Could not open dictionary cache'); }
      finally { if (live) setLoading(false); }
    })();
    return () => { live = false; };
  }, [userId, signOut]);

  async function search(value = query) {
    const term = value.trim();
    setQuery(value); setLoading(true); setError(null);
    try {
      const cached = await searchCachedWords(term);
      setResults(cached);
      if (term && userId) { await rememberSearch(userId, term); setRecent(await getRecentSearches(userId)); }
      try {
        const remote = await searchDictionary(term);
        setResults(remote); setOffline(false); await cacheWords(remote);
      } catch (cause) {
        if (cause instanceof ApiError && cause.status === 401) { void signOut(); return; }
        setOffline(true);
        if (!cached.length) setError('Could not reach the dictionary. This word has not been cached yet.');
      }
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Search failed'); }
    finally { setLoading(false); setTab('search'); }
  }

  async function toggleSaved(word: DictionaryWord) {
    if (!userId) return;
    setBusyId(word.id); setError(null);
    try {
      const alreadySaved = saved.some((item) => item.word.id === word.id);
      if (offline && alreadySaved) { setError('Removing saved words requires a connection.'); return; }
      if (offline && !alreadySaved) { await queueOfflineSave(word); return; }
      if (alreadySaved) await removeSavedWord(word.id);
      else await saveWord(word.id);
      await loadSaved(userId);
    } catch (cause) {
      if (cause instanceof ApiError && cause.status === 401) { void signOut(); return; }
      if (cause instanceof ApiError && cause.status === 0 && !saved.some((item) => item.word.id === word.id)) { setOffline(true); await queueOfflineSave(word); return; }
      setError(cause instanceof Error ? cause.message : 'Could not change saved words');
    } finally { setBusyId(null); }
  }

  async function queueOfflineSave(word: DictionaryWord) {
    const existing = saved.find((item) => item.word.id === word.id);
    if (existing) return;
    const next = [{ id: Crypto.randomUUID(), word, created_at: new Date().toISOString(), next_review_at: null }, ...saved];
    await queueEvent({ id: Crypto.randomUUID(), userId, kind: 'save_word', payload: { wordId: word.id }, status: 'pending', attempts: 0, nextRetryAt: 0, message: null, createdAt: new Date().toISOString(), result: null });
    setSaved(next); await cacheSavedWords(userId, next);
  }

  function speak(word: DictionaryWord) {
    setError(null);
    Speech.stop();
    Speech.speak(word.term, {
      language: 'en-US', rate: 0.9,
      onError: () => setError('Device pronunciation is unavailable right now.'),
    });
  }

  const card = saved[Math.min(flashcardIndex, Math.max(saved.length - 1, 0))];
  return <Page eyebrow="WORD LAB" title="Dictionary" description="Search real English–Vietnamese seed entries, save words, and review them offline.">
    <SyncStatus />
    {offline && <AppCard tone="reward"><AppText variant="label">Offline cache</AppText><AppText tone="muted">Showing cached words. New saves wait for synchronization; removing words needs a connection.</AppText></AppCard>}
    <View style={{ gap: 8 }}>
      {(['search', 'saved', 'recent', 'flashcards'] as Tab[]).map((item) =>
        <AppButton key={item} label={item === 'flashcards' ? 'Flashcards' : item === 'recent' ? 'Recent' : item === 'saved' ? `Saved (${saved.length})` : 'Search'} variant={tab === item ? 'primary' : 'secondary'} onPress={() => { setTab(item); setError(null); }} />
      )}
    </View>
    {!!error && <ErrorState title="Dictionary unavailable" message={error} retry={() => { void (tab === 'search' ? search() : loadSaved(userId)); }} />}
    {tab === 'search' && <>
      <AppInput label="English word or Vietnamese meaning" placeholder="Try curious or tò mò" value={query} onChangeText={setQuery} onSubmitEditing={() => { void search(); }} returnKeyType="search" autoCapitalize="none" />
      <AppButton label="Search dictionary" onPress={() => { void search(); }} />
      {loading ? <LoadingSkeleton lines={4} /> : results.length ? results.map((word) => <WordCard key={word.id} word={word} saved={saved.some((item) => item.word.id === word.id)} onSave={() => { if (!busyId) void toggleSaved(word); }} onSpeak={() => speak(word)} />) : <EmptyState title="No matching word" message={offline ? 'This word is not in the offline cache.' : 'Try another English word or Vietnamese meaning.'} />}
    </>}
    {tab === 'saved' && (saved.length ? saved.map((item) => <WordCard key={item.id} word={item.word} saved onSave={() => { if (!busyId) void toggleSaved(item.word); }} onSpeak={() => speak(item.word)} />) : <EmptyState title="No saved words" message="Save a word from search to make it available for flashcards." actionLabel="Find a word" onAction={() => setTab('search')} />)}
    {tab === 'recent' && (recent.length ? recent.map((term) => <AppCard key={term} onPress={() => { void search(term); }}><AppText variant="label">{term}</AppText></AppCard>) : <EmptyState title="No recent searches" message="Words you search for will appear here on this device." />)}
    {tab === 'flashcards' && (card ? <AppCard tone="primary" style={{ gap: 14 }}><AppText variant="caption" tone="primary">CARD {Math.min(flashcardIndex + 1, saved.length)} / {saved.length}</AppText><AppText variant="display" style={{ textAlign: 'center' }}>{card.word.term}</AppText><AppText tone="muted" style={{ textAlign: 'center' }}>{card.word.ipa}</AppText>{revealed ? <><AppText variant="heading" style={{ textAlign: 'center' }}>{card.word.translation}</AppText><AppText style={{ textAlign: 'center' }}>{card.word.definition}</AppText><AppText tone="muted" style={{ textAlign: 'center' }}>{card.word.example}</AppText></> : <AppButton label="Reveal meaning" onPress={() => setRevealed(true)} variant="reward" />}<AppButton label="Pronounce word" onPress={() => speak(card.word)} variant="secondary" /><AppButton label="Next card" onPress={() => { setFlashcardIndex((flashcardIndex + 1) % saved.length); setRevealed(false); }} variant="secondary" /></AppCard> : <EmptyState title="Your deck is empty" message="Save vocabulary first to build your personal flashcards." actionLabel="Search words" onAction={() => setTab('search')} />)}
    <NavLink href="/home" label="Back to dashboard" />
  </Page>;
}
