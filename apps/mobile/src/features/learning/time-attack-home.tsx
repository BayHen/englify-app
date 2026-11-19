import { useCallback, useEffect, useRef, useState } from 'react';
import { View } from 'react-native';
import { router } from 'expo-router';
import { randomUUID } from 'expo-crypto';
import { designTokens } from '@englify/shared';
import { ApiError } from '@/lib/api';
import { AppButton, AppCard, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { getJourneySummary } from './api';
import { getArenaCatalog, type ArenaCatalog, type ArenaLevel } from './arena-api';
import { availableArenaQuestions } from './arena-model';
import { getTimeAttackHistory, getTimeAttackRecords, startTimeAttack, type TimeAttackDifficulty, type TimeAttackHistory, type TimeAttackRecords } from './time-attack-api';
const gap = designTokens.spacing.md;
export function TimeAttackHome() {
  const [xpTotal, setXpTotal] = useState(0);
  const [data, setData] = useState<TimeAttackRecords | null>(null); const [bank, setBank] = useState<ArenaCatalog | null>(null);
  const [history, setHistory] = useState<TimeAttackHistory>({ items: [], page: 1, total: 0 });
  const [level, setLevel] = useState<ArenaLevel>('A1'); const [difficulty, setDifficulty] = useState<TimeAttackDifficulty>('normal');
  const [loading, setLoading] = useState(true); const [busy, setBusy] = useState(false); const [error, setError] = useState('');
  const requestId = useRef<string | null>(null); const inFlight = useRef(false); const retry = useRef<() => void>(() => {});
  const load = useCallback(async () => {
    retry.current = () => { void load(); }; setLoading(true); setError('');
    try { const [records, recent, catalog, summary] = await Promise.all([getTimeAttackRecords(), getTimeAttackHistory(), getArenaCatalog(), getJourneySummary()]); setXpTotal(summary.xp_total); setData(records); setHistory(recent); setBank(catalog); }
    catch (cause) { setError(cause instanceof ApiError && cause.status === 404 ? 'Time Attack is not available on this learning server yet. You can still use Practice Mode.' : cause instanceof Error ? cause.message : 'Time Attack is unavailable. You can still use Practice Mode.'); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { void load(); }, [load]);
  async function start() {
    if (inFlight.current) return; inFlight.current = true; setBusy(true); setError(''); requestId.current ??= randomUUID(); retry.current = () => { void start(); };
    try { const value = await startTimeAttack(requestId.current, level, difficulty); requestId.current = null;
      router.push({ pathname: '/time-attack/[id]', params: { id: value.session.id } }); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not start Time Attack. Retry preserves your request.'); }
    finally { inFlight.current = false; setBusy(false); }
  }
  async function page(next: number) { if (inFlight.current) return; inFlight.current = true; setBusy(true); setError(''); retry.current = () => { void page(next); };
    try { setHistory(await getTimeAttackHistory(next)); } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load Time Attack history.'); }
    finally { inFlight.current = false; setBusy(false); } }
  const rules = data?.rules ?? []; const rule = rules.find(value => value.difficulty === difficulty);
  const available = availableArenaQuestions(bank?.groups ?? [], { level, topic: null, kind: null, difficulty: null, count: 5 });
  return <View style={{ gap }}>
    {loading ? <LoadingSkeleton lines={4} /> : data ? <>
      <AppCard tone="reward" style={{ gap }}><AppText variant="heading">Beat your personal best</AppText>
        <AppText>{xpTotal} XP ? {data.completed_sessions} finished games · highest combo {data.highest_combo}</AppText>
        <AppText tone="muted">Arena points measure this game. They do not convert to XP.</AppText></AppCard>
      <AppCard style={{ gap }}><AppText variant="heading">Time Attack</AppText><AppText variant="label">CEFR level</AppText>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap }}>{(['A1', 'A2', 'B1', 'B2', 'C1'] as const).map(value => <AppButton key={value} label={value} disabled={busy} size="medium"
          variant={level === value ? 'primary' : 'secondary'} onPress={() => { setLevel(value); requestId.current = null; }} />)}</View>
        <AppText variant="label">Game difficulty</AppText>
        {rules.map(value => <AppButton key={value.difficulty} label={`${value.difficulty.toUpperCase()} · ${value.question_count} questions · ${value.time_limit_seconds}s · ${value.initial_lives} lives`}
          disabled={busy} variant={difficulty === value.difficulty ? 'primary' : 'secondary'} onPress={() => { setDifficulty(value.difficulty); requestId.current = null; }} />)}
        {rules.length === 0 ? <EmptyState title="Time Attack is paused" message="No difficulty is currently available. Practice Mode remains available." /> : null}
        {rule && available < rule.question_count ? <AppText tone="muted">This level needs at least {rule.question_count} published questions for this difficulty.</AppText> : null}
        <AppButton label="Start Time Attack" loading={busy} disabled={!rule || available < rule.question_count} onPress={() => { void start(); }} />
        <AppText tone="muted">The timer keeps running in the background. Wrong answers cost a life. Speed points use server-observed time, including the network.</AppText>
      </AppCard>
      <View style={{ gap }}><AppText variant="heading">Personal records by difficulty</AppText>{data.records.map(record => <AppCard key={record.difficulty} style={{ gap }}>
        <AppText variant="label">{record.difficulty.toUpperCase()} · rules v{record.rules_version}</AppText>
        <AppText>{record.highest_score} best points · {record.best_accuracy}% best accuracy · combo {record.highest_combo}</AppText>
        <AppText tone="muted">{record.fastest_completion_ms === null ? 'Finish every question with at least 70% accuracy to set a time record.' : `Fastest qualifying finish: ${(record.fastest_completion_ms / 1000).toFixed(1)}s`}</AppText>
        {record.best_session_id ? <AppButton label={`Review ${record.difficulty} personal best`} variant="secondary" disabled={busy} onPress={() => router.push({ pathname: '/time-attack/[id]', params: { id: record.best_session_id! } })} /> : null}
      </AppCard>)}</View>
      <View style={{ gap }}><AppText variant="heading">Recent Time Attack results</AppText>
        {history.items.length === 0 ? <EmptyState title="Ready for your first timed quiz?" message="Your results and personal records will appear here." /> : history.items.map(item => <AppCard key={item.id} style={{ gap }}>
          <AppText variant="label">{item.cefr_level} · {item.difficulty.toUpperCase()} · {item.score} points</AppText>
          <AppText tone="muted">{new Date(item.started_at).toLocaleString()} · {item.status.replaceAll('_', ' ')} · combo {item.max_combo}</AppText>
          <AppButton label={item.status === 'active' ? 'Resume Time Attack' : 'Review Time Attack result'} variant="secondary" disabled={busy} onPress={() => router.push({ pathname: '/time-attack/[id]', params: { id: item.id } })} />
        </AppCard>)}
        <View style={{ flexDirection: 'row', gap }}><AppButton label="Previous games" variant="secondary" style={{ flex: 1 }} disabled={busy || history.page <= 1} onPress={() => { void page(history.page - 1); }} />
          <AppButton label="More games" variant="secondary" style={{ flex: 1 }} disabled={busy || history.page * 10 >= history.total} onPress={() => { void page(history.page + 1); }} /></View>
      </View>
    </> : null}
    {Boolean(error) ? <ErrorState message={error} retry={() => retry.current()} /> : null}
  </View>;
}
