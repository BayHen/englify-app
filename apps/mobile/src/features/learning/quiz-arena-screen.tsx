import { useCallback, useRef, useState } from 'react';
import { router, useFocusEffect, type Href } from 'expo-router';
import { randomUUID } from 'expo-crypto';
import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppModal, AppText, EmptyState, ErrorState, LoadingSkeleton, XPProgressBar } from '@/ui';
import { getJourneySummary, type JourneySummary } from './api';
import { getArenaCatalog, getArenaHistory, startArena, type ArenaCatalog, type ArenaConfig, type ArenaHistory, type ArenaLevel } from './arena-api';
import { TimeAttackHome } from './time-attack-home';
import { RankedHome } from './ranked-home';
import { arenaKinds, arenaTopics, availableArenaQuestions } from './arena-model';

const levels: ArenaLevel[] = ['A1', 'A2', 'B1', 'B2', 'C1'];
const counts = [5, 10, 15, 20] as const;
const gap = designTokens.spacing.md;
export function QuizArenaScreen() {
  const [mode, setMode] = useState<'practice'|'time_attack'|'ranked'>('practice');
  const [catalog, setCatalog] = useState<ArenaCatalog | null>(null);
  const [summary, setSummary] = useState<JourneySummary | null>(null);
  const [history, setHistory] = useState<ArenaHistory>({ items: [], total: 0, page: 1 });
  const [config, setConfig] = useState<ArenaConfig>({ level: 'A1', topic: null, kind: null, count: 5, difficulty: null });
  const [picker, setPicker] = useState<'topic' | 'kind' | null>(null);
  const [loading, setLoading] = useState(true); const [busy, setBusy] = useState(false); const [error, setError] = useState('');
  const retryAction = useRef<() => void>(() => {});
  const inFlight = useRef(false); const requestId = useRef<string | null>(null);
  const load = useCallback(async () => {
    retryAction.current = () => { void load(); };
    setLoading(true); setError('');
    try { const [bank, xp, recent] = await Promise.all([getArenaCatalog(), getJourneySummary(), getArenaHistory()]); setCatalog(bank); setSummary(xp); setHistory(recent); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load Quiz Arena.'); }
    finally { setLoading(false); }
  }, []);
  useFocusEffect(useCallback(() => { void load(); }, [load]));
  function configure(next: Partial<ArenaConfig>) { if (inFlight.current) return; setConfig(value => ({ ...value, ...next })); requestId.current = null; setError(''); }
  async function start() {
    if (inFlight.current || !catalog) return;
    retryAction.current = () => { void start(); };
    inFlight.current = true; setBusy(true); setError(''); requestId.current ??= randomUUID();
    try { const session = await startArena(requestId.current, config); requestId.current = null;
      router.push({ pathname: '/quiz-practice/[id]', params: { id: session.id } }); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not start practice. Retry uses the same request ID.'); }
    finally { inFlight.current = false; setBusy(false); }
  }
  async function historyPage(page: number) { if (inFlight.current) return; inFlight.current = true; setBusy(true); setError('');
    retryAction.current = () => { void historyPage(page); };
    try { setHistory(await getArenaHistory(page)); } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not load attempts.'); }
    finally { inFlight.current = false; setBusy(false); } }
  const groups = catalog?.groups ?? []; const available = availableArenaQuestions(groups, config);
  const levelGroups = groups.filter(group => group.cefr_level === config.level);
  const topics = [...new Set(levelGroups.map(group => group.topic))];
  const kinds = [...new Set(levelGroups.filter(group => config.topic === null || group.topic === config.topic).map(group => group.kind))];
  const difficulties = [...new Set(levelGroups.filter(group => (config.topic === null || group.topic === config.topic)
    && (config.kind === null || group.kind === config.kind)).map(group => group.difficulty))].sort();
  return <Page eyebrow="PRACTICE" title="Quiz Arena" description="Choose a mode to practise, race the clock, or compete in ranked play." compact>
    <AppCard tone="primary" style={{ gap: 12 }}>
      <AppText variant="heading" accessibilityRole="header">Choose your challenge</AppText>
      <AppButton label="Practice" disabled={busy} variant={mode === 'practice' ? 'primary' : 'secondary'} onPress={() => setMode('practice')} />
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap }}>
        <AppButton label="Time Attack" style={{ flexGrow: 1 }} disabled={busy} variant={mode === 'time_attack' ? 'primary' : 'secondary'} onPress={() => setMode('time_attack')} />
        <AppButton label="Ranked Arena" style={{ flexGrow: 1 }} disabled={busy} variant={mode === 'ranked' ? 'primary' : 'secondary'} onPress={() => setMode('ranked')} />
      </View>
    </AppCard>
    {mode === 'time_attack' ? <TimeAttackHome /> : mode === 'ranked' ? <RankedHome /> : <>
    {loading ? <LoadingSkeleton lines={5} /> : catalog ? <>
      {summary ? <AppCard tone="primary" style={{ gap }}><AppText variant="heading">Level {summary.level} · {summary.xp_total} XP</AppText>
        <XPProgressBar value={summary.xp_into_level} max={summary.xp_for_next_level} />
        <AppText tone="muted">Journey progress and rewards stay with your account.</AppText></AppCard> : null}
      {groups.length === 0 ? <EmptyState title="Question bank is being prepared" message="Published practice questions will appear here when available." /> : <>
        <AppCard style={{ gap }}><AppText variant="heading">Start Practice</AppText><AppText variant="label">CEFR level</AppText>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap }}>{levels.map(level => <AppButton key={level} label={level} size="medium" disabled={busy}
            variant={config.level === level ? 'primary' : 'secondary'} onPress={() => configure({ level, topic: null, kind: null, difficulty: null })} />)}</View>
          <AppText variant="label">Topic</AppText>
          <AppButton label={config.topic ? arenaTopics[config.topic] : 'Mixed Practice'} disabled={busy} variant="secondary" onPress={() => setPicker('topic')} />
          <AppText variant="label">Question type</AppText>
          <AppButton label={config.kind ? arenaKinds[config.kind] : 'All question types'} disabled={busy} variant="secondary" onPress={() => setPicker('kind')} />
          <AppText variant="label">Difficulty within this CEFR level</AppText>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap }}><AppButton label="Any" disabled={busy} size="medium" variant={config.difficulty === null ? 'primary' : 'secondary'} onPress={() => configure({ difficulty: null })} />
            {difficulties.map(difficulty => <AppButton key={difficulty} label={['', 'Foundation', 'Standard', 'Challenge'][difficulty]} size="medium" disabled={busy}
              variant={config.difficulty === difficulty ? 'primary' : 'secondary'} onPress={() => configure({ difficulty })} />)}</View>
          <AppText variant="label">Number of questions</AppText><View style={{ flexDirection: 'row', flexWrap: 'wrap', gap }}>{counts.map(count => <AppButton key={count} label={`${count} questions`}
            size="medium" disabled={busy || count > available} variant={config.count === count ? 'primary' : 'secondary'} onPress={() => configure({ count })} />)}</View>
          <AppText tone="muted">{available} published questions match these filters.</AppText>
          {available < config.count ? <AppText tone="muted">Choose a smaller quiz or broaden your filters. At least 5 questions are needed.</AppText> : null}
          <AppButton label="Start Practice" loading={busy} disabled={available < config.count} onPress={() => { void start(); }} />
          <AppText variant="caption" tone="muted">Earn {catalog.daily_reward_xp} XP for your first practice with at least {catalog.reward_threshold}% accuracy each UTC day. Further practice saves your results without extra XP.</AppText>
        </AppCard>
        <View style={{ gap }}><AppText variant="heading">Recommended for {config.level}</AppText>
          <AppCard onPress={() => configure({ topic: null, kind: null, count: 5, difficulty: null })} accessibilityLabel="Configure mixed practice" style={{ gap }}>
            <AppText variant="label">A quick warm-up</AppText><AppText tone="muted">Mix published question types and discover what to review next.</AppText></AppCard>
          {topics.filter(topic => availableArenaQuestions(groups, { ...config, topic, kind: null, difficulty: null }) >= 5).slice(0, 3).map(topic =>
            <AppButton key={topic} label={`Practise ${arenaTopics[topic]}`} variant="secondary" disabled={busy} onPress={() => configure({ topic, kind: null, count: 5, difficulty: null })} />)}
        </View>
      </>}
      <View style={{ gap }}><AppText variant="heading">Recent attempts</AppText>
        {history.items.length === 0 ? <EmptyState title="Your first practice starts here" message="Completed quizzes and unfinished sessions will appear here." />
          : history.items.map(attempt => <AppCard key={attempt.id} style={{ gap }}>
            <AppText variant="label">{attempt.cefr_level} · {attempt.topic ? arenaTopics[attempt.topic] : 'Mixed Practice'}</AppText>
            <AppText tone="muted">{new Date(attempt.started_at).toLocaleString()} · {attempt.question_count} questions</AppText>
            <AppText>{attempt.status === 'completed' ? `${attempt.correct_count}/${attempt.question_count} correct · ${attempt.accuracy}% · ${attempt.earned_xp} XP` : attempt.status === 'active' ? 'Unfinished practice' : 'Practice ended'}</AppText>
            {attempt.status !== 'abandoned' ? <AppButton label={attempt.status === 'active' ? 'Resume practice' : 'Review attempt'} variant="secondary" disabled={busy} onPress={() => router.push({ pathname: '/quiz-practice/[id]', params: { id: attempt.id } })} /> : null}
          </AppCard>)}
        <View style={{ flexDirection: 'row', gap }}><AppButton label="Previous attempts" style={{ flex: 1 }} variant="secondary" disabled={busy || history.page <= 1} onPress={() => { void historyPage(history.page - 1); }} />
          <AppButton label="More attempts" style={{ flex: 1 }} variant="secondary" disabled={busy || history.page * 10 >= history.total} onPress={() => { void historyPage(history.page + 1); }} /></View>
      </View>
    </> : null}
    {Boolean(error) ? <ErrorState message={error} retry={() => retryAction.current()} /> : null}
    <AppModal visible={picker !== null} title={picker === 'topic' ? 'Choose a topic' : 'Choose a question type'} onClose={() => setPicker(null)}>
      {picker === 'topic' ? <>
        <AppButton label="Mixed Practice" variant={config.topic === null ? 'primary' : 'secondary'} onPress={() => { configure({ topic: null, kind: null, difficulty: null }); setPicker(null); }} />
        {topics.map(topic => <AppButton key={topic} label={arenaTopics[topic]} variant={config.topic === topic ? 'primary' : 'secondary'} onPress={() => { configure({ topic, kind: null, difficulty: null }); setPicker(null); }} />)}
      </> : <>
        <AppButton label="All question types" variant={config.kind === null ? 'primary' : 'secondary'} onPress={() => { configure({ kind: null, difficulty: null }); setPicker(null); }} />
        {kinds.map(kind => <AppButton key={kind} label={arenaKinds[kind]} variant={config.kind === kind ? 'primary' : 'secondary'} onPress={() => { configure({ kind, difficulty: null }); setPicker(null); }} />)}
      </>}
    </AppModal>
    </>}
    <AppButton label="Mistake Review & Smart Practice" variant="secondary" onPress={() => router.push('/mistakes' as Href)} />
    <NavLink href="/journey" label="Continue Journey lessons" />
  </Page>;
}
