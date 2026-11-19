import { useCallback, useState } from 'react';
import { router, useFocusEffect, type Href } from 'expo-router';
import { randomUUID } from 'expo-crypto';
import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { Page } from '@/components/page';
import { AppButton, AppCard, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { arenaKinds } from './arena-model';
import type { ArenaKind, ArenaLevel } from './arena-api';
import { getMistakes, getMistakeSummary, getQuizRecommendations, getWeaknessAnalytics, startMistakeReview, type MasteryStatus, type MistakePage, type MistakeSummary, type QuizRecommendation, type WeaknessAnalytics } from './mistake-review-api';

const gap = designTokens.spacing.md;
const levels: ArenaLevel[] = ['A1', 'A2', 'B1', 'B2', 'C1'];
const topics = ['grammar', 'vocabulary', 'reading', 'everyday', 'business', 'travel', 'sentence_structure', 'phrasal_verbs', 'idioms', 'journey'];
const statusLabels: Record<MasteryStatus, string> = { needs_review: 'Needs review', learning: 'Learning', improving: 'Improving', mastered: 'Mastered' };
export function MistakeDashboardScreen() {
  const [summary, setSummary] = useState<MistakeSummary | null>(null); const [page, setPage] = useState<MistakePage | null>(null);
  const [analytics, setAnalytics] = useState<WeaknessAnalytics | null>(null); const [recommendations, setRecommendations] = useState<QuizRecommendation[]>([]);
  const [status, setStatus] = useState<MasteryStatus | null>(null); const [cefr, setCefr] = useState<ArenaLevel | null>(null); const [topic, setTopic] = useState<string | null>(null); const [kind, setKind] = useState<ArenaKind | null>(null);
  const [loading, setLoading] = useState(true); const [busy, setBusy] = useState(false); const [error, setError] = useState('');
  const load = useCallback(async () => { setLoading(true); setError(''); try { const [nextSummary, mistakes, weak, recs] = await Promise.all([getMistakeSummary(), getMistakes({ status, cefr, topic, kind }), getWeaknessAnalytics(), getQuizRecommendations()]); setSummary(nextSummary); setPage(mistakes); setAnalytics(weak); setRecommendations(recs); } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load mistake review.'); } finally { setLoading(false); } }, [cefr, kind, status, topic]);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  async function begin(count: 0 | 5 | 10) { if (busy) return; setBusy(true); setError(''); try { const session = await startMistakeReview(randomUUID(), count); router.push({ pathname: '/mistake-review/[id]', params: { id: session.id } } as unknown as Href); } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not start review.'); } finally { setBusy(false); } }
  return <Page eyebrow="SMART REVIEW" title="Mistake Review" description="Real mistakes from Journey and Quiz Arena, scheduled with spaced repetition.">
    {loading ? <LoadingSkeleton lines={6} /> : <>
      {summary ? <AppCard tone="primary" style={{ gap }}><AppText variant="heading">{summary.due} due now · {summary.total} tracked</AppText><AppText>{summary.needs_review} need review · {summary.learning} learning · {summary.improving} improving · {summary.mastered} mastered</AppText><View style={{ flexDirection: 'row', flexWrap: 'wrap', gap }}><AppButton label="Review 5" disabled={busy || summary.due === 0} onPress={() => { void begin(5); }} /><AppButton label="Review 10" variant="secondary" disabled={busy || summary.due === 0} onPress={() => { void begin(10); }} /><AppButton label="All due" variant="secondary" disabled={busy || summary.due === 0} onPress={() => { void begin(0); }} /></View><AppText variant="caption" tone="muted">Review changes mastery only. It never grants XP, score, combo, or rating.</AppText></AppCard> : null}
      {recommendations.length > 0 ? <View style={{ gap }}><AppText variant="heading">Recommended next</AppText>{recommendations.map((item, index) => <AppCard key={`${item.kind}-${index}`} style={{ gap }}><AppText variant="label">{item.title}</AppText><AppText tone="muted">{item.reason}</AppText>{item.action === 'review' ? <AppButton label="Start due review" variant="secondary" disabled={busy || (summary?.due ?? 0) === 0} onPress={() => { void begin(5); }} /> : <AppButton label="Open Practice" variant="secondary" onPress={() => router.push('/quiz-arena')} />}</AppCard>)}</View> : null}
      <View style={{ gap }}><AppText variant="heading">Mistake bank</AppText><AppText variant="label">Mastery</AppText><View style={{ flexDirection: 'row', flexWrap: 'wrap', gap }}><AppButton label="All" size="medium" variant={status === null ? 'primary' : 'secondary'} onPress={() => setStatus(null)} />{(Object.keys(statusLabels) as MasteryStatus[]).map(value => <AppButton key={value} label={statusLabels[value]} size="medium" variant={status === value ? 'primary' : 'secondary'} onPress={() => setStatus(value)} />)}</View>
        <AppText variant="label">CEFR</AppText><View style={{ flexDirection: 'row', flexWrap: 'wrap', gap }}><AppButton label="All" size="medium" variant={cefr === null ? 'primary' : 'secondary'} onPress={() => setCefr(null)} />{levels.map(value => <AppButton key={value} label={value} size="medium" variant={cefr === value ? 'primary' : 'secondary'} onPress={() => setCefr(value)} />)}</View>
        <AppText variant="label">Topic</AppText><View style={{ flexDirection: 'row', flexWrap: 'wrap', gap }}><AppButton label="All" size="medium" variant={topic === null ? 'primary' : 'secondary'} onPress={() => setTopic(null)} />{topics.map(value => <AppButton key={value} label={value.replaceAll('_', ' ')} size="medium" variant={topic === value ? 'primary' : 'secondary'} onPress={() => setTopic(value)} />)}</View>
        <AppText variant="label">Question type</AppText><View style={{ flexDirection: 'row', flexWrap: 'wrap', gap }}><AppButton label="All" size="medium" variant={kind === null ? 'primary' : 'secondary'} onPress={() => setKind(null)} />{(Object.keys(arenaKinds) as ArenaKind[]).map(value => <AppButton key={value} label={arenaKinds[value]} size="medium" variant={kind === value ? 'primary' : 'secondary'} onPress={() => setKind(value)} />)}</View>
        {page?.items.length ? page.items.map(item => <AppCard key={item.id} style={{ gap }}><AppText variant="caption" tone="primary">{item.cefr_level} · {item.topic} · {arenaKinds[item.question_kind] ?? item.question_kind}</AppText><AppText variant="heading">{item.question.prompt}</AppText><AppText>{statusLabels[item.mastery_status]} · stage {item.review_stage}/5 · {item.incorrect_attempts + item.incorrect_reviews} mistakes</AppText><AppText tone="muted">Giải thích: {item.explanation_vi}</AppText><AppText variant="caption" tone="muted">Next review: {new Date(item.next_review_at).toLocaleString()}</AppText></AppCard>) : <EmptyState title="No matching mistakes" message="Only incorrect answers persisted by Journey or Quiz Arena appear here." />}
      </View>
      {analytics ? <AppCard style={{ gap }}><AppText variant="heading">Weak areas</AppText><AppText tone="muted">Rates become reliable after {analytics.minimum_sample} real attempts.</AppText>{analytics.topics.filter(item => item.reliable).slice(0, 3).map(item => <AppText key={item.topic}>{item.topic}: {item.error_rate}% errors ({item.attempts} attempts)</AppText>)}</AppCard> : null}
    </>}
    {Boolean(error) ? <ErrorState message={error} retry={() => { void load(); }} /> : null}
  </Page>;
}
