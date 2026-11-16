import { useCallback, useRef, useState } from 'react';
import { randomUUID } from 'expo-crypto';
import { useFocusEffect } from 'expo-router';
import { View } from 'react-native';
import { Page, NavLink } from '@/components/page';
import { useAuth } from '@/auth/provider';
import { ApiError } from '@/lib/api';
import { AppButton, AppCard, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { queueEvent } from '@/features/offline/storage';
import { listDueVocabulary, reviewVocabulary, type DueVocabulary, type RecallRating } from './api';
import { cardDirection, ratings } from './scheduler';

export function VocabularyReviewScreen() {
  const { profile } = useAuth();
  const [cards, setCards] = useState<DueVocabulary[]>([]);
  const [index, setIndex] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [offlineMessage, setOfflineMessage] = useState('');
  const requestId = useRef<string | null>(null);
  const load = useCallback(async () => {
    setLoading(true);
    try { setCards(await listDueVocabulary()); setIndex(0); setError(''); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load due vocabulary.'); }
    finally { setLoading(false); }
  }, []);
  useFocusEffect(useCallback(() => { void load(); }, [load]));

  async function rate(rating: RecallRating) {
    const card = cards[index];
    if (!card || busy || !profile) return;
    setBusy(true); requestId.current ??= randomUUID();
    try {
      await reviewVocabulary(card.id, rating, requestId.current); setOfflineMessage('');
    } catch (cause) {
      if (!(cause instanceof ApiError) || (cause.status !== 0 && cause.status < 500)) {
        setError(cause instanceof Error ? cause.message : 'Could not save this review.'); setBusy(false); return;
      }
      await queueEvent({ id: requestId.current, userId: profile.id, kind: 'vocabulary_review',
        payload: { savedVocabularyId: card.id, rating }, status: 'pending', attempts: 0, nextRetryAt: 0,
        message: null, createdAt: new Date().toISOString(), result: null });
      setOfflineMessage('Review saved on this device and will sync after reconnecting.');
    }
    requestId.current = null; setCards((current) => current.filter((item) => item.id !== card.id));
    setIndex(0); setRevealed(false); setBusy(false);
  }

  const card = cards[index];
  const direction = cardDirection(index);
  return <Page eyebrow="SMART REVIEW" title="Vocabulary review" description="Review only words that are due. Ratings schedule the next review; no pronunciation or essay score is invented.">
    {loading ? <LoadingSkeleton lines={5} /> : error ? <ErrorState message={error} retry={() => { void load(); }} />
      : !card ? <EmptyState title="All caught up" message="There are no saved words due right now." />
        : <AppCard tone="primary" style={{ gap: 16 }}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', gap: 8 }}><AppText variant="caption" tone="primary">{direction === 'en-vi' ? 'ENGLISH → VIETNAMESE' : 'VIETNAMESE → ENGLISH'}</AppText>
            <AppText variant="caption" tone="muted">{cards.length} due</AppText></View>
          <AppText variant="display" style={{ textAlign: 'center' }}>{direction === 'en-vi' ? card.term : card.translation ?? card.definition}</AppText>
          {revealed ? <View style={{ gap: 8 }}><AppText variant="heading" style={{ textAlign: 'center' }}>{direction === 'en-vi' ? card.translation ?? card.definition : card.term}</AppText>
            <AppText tone="muted" style={{ textAlign: 'center' }}>{card.ipa ?? card.part_of_speech ?? ''}</AppText>
            {card.example ? <AppText style={{ textAlign: 'center' }}>{card.example}</AppText> : null}
            {card.example_vi ? <AppText tone="muted" style={{ textAlign: 'center' }}>{card.example_vi}</AppText> : null}
            {ratings.map((rating) => <AppButton key={rating.value} label={`${rating.label} · ${rating.hint}`} variant={rating.value === 3 ? 'primary' : 'secondary'} disabled={busy} onPress={() => { void rate(rating.value); }} />)}
          </View> : <AppButton label="Reveal answer" variant="reward" onPress={() => setRevealed(true)} />}
        </AppCard>}
    {offlineMessage ? <AppCard tone="reward"><AppText>{offlineMessage}</AppText></AppCard> : null}
    <NavLink href="/dictionary" label="Open saved vocabulary" />
    <NavLink href="/home" label="Back to dashboard" />
  </Page>;
}
