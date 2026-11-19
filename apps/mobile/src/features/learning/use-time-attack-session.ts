import { useCallback, useEffect, useRef, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import { AppState, Platform } from 'react-native';
import { randomUUID } from 'expo-crypto';
import type { ArenaAnswer } from './arena-api';
import { answerTimeAttack, finishTimeAttack, getTimeAttack, type TimeAttackSnapshot } from './time-attack-api';

type PendingAnswer = { questionId: string; requestId: string; position: number; answer: ArenaAnswer };
export function useTimeAttackSession(id: string) {
  const [snapshot, setSnapshot] = useState<TimeAttackSnapshot | null>(null);
  const [busy, setBusy] = useState(false); const [synced, setSynced] = useState(false); const [error, setError] = useState('');
  const [visible, setVisible] = useState(true); const [pending, setPending] = useState<PendingAnswer | null>(null);
  const alive = useRef(true); const focused = useRef(false); const visibleRef = useRef(true); const epoch = useRef(0);
  const inFlight = useRef(false); const afterFlight = useRef<(() => void) | null>(null); const pendingRef = useRef<PendingAnswer | null>(null);
  const run = useCallback(async (operation: () => Promise<TimeAttackSnapshot>) => {
    if (inFlight.current || !alive.current) return null;
    inFlight.current = true; const startedEpoch = epoch.current; setBusy(true); setError('');
    try {
      const value = await operation(); if (!alive.current) return null;
      setSnapshot(value); setSynced(startedEpoch === epoch.current && visibleRef.current);
      if (pendingRef.current && value.session.answered_count >= pendingRef.current.position) { pendingRef.current = null; setPending(null); }
      if (value.session.status !== 'active') { pendingRef.current = null; setPending(null); }
      return value;
    } catch (cause) { if (alive.current) setError(cause instanceof Error ? cause.message : 'Could not reach Time Attack. Reconnect and synchronize.'); return null; }
    finally {
      inFlight.current = false; if (alive.current) { setBusy(false); const next = afterFlight.current; afterFlight.current = null; next?.(); }
    }
  }, []);
  const refresh = useCallback(function sync() {
    if (!alive.current || !visibleRef.current) return;
    setSynced(false); if (inFlight.current) { afterFlight.current = sync; return; }
    void run(() => getTimeAttack(id));
  }, [id, run]);
  useEffect(() => {
    alive.current = true;
    const updateVisibility = () => {
      const foreground = focused.current && (AppState.currentState === 'active' || AppState.currentState === null)
        && (Platform.OS !== 'web' || typeof document === 'undefined' || document.visibilityState !== 'hidden');
      epoch.current += 1; visibleRef.current = foreground; setVisible(foreground); setSynced(false);
      if (foreground) refresh();
    };
    const subscription = AppState.addEventListener('change', updateVisibility);
    if (Platform.OS === 'web' && typeof document !== 'undefined') document.addEventListener('visibilitychange', updateVisibility);
    return () => { alive.current = false; epoch.current += 1; subscription.remove();
      if (Platform.OS === 'web' && typeof document !== 'undefined') document.removeEventListener('visibilitychange', updateVisibility); };
  }, [refresh]);
  useFocusEffect(useCallback(() => {
    focused.current = true; epoch.current += 1;
    visibleRef.current = (AppState.currentState === 'active' || AppState.currentState === null)
      && (Platform.OS !== 'web' || typeof document === 'undefined' || document.visibilityState !== 'hidden');
    setVisible(visibleRef.current); refresh();
    return () => { focused.current = false; visibleRef.current = false; epoch.current += 1; setVisible(false); setSynced(false); };
  }, [refresh]));
  const submit = useCallback(async (questionId: string, position: number, answer: ArenaAnswer) => {
    if (!visibleRef.current || !synced || inFlight.current) return null;
    const request = pendingRef.current ?? { questionId, requestId: randomUUID(), position, answer };
    pendingRef.current = request; setPending(request);
    return run(() => answerTimeAttack(id, request.questionId, request.requestId, request.answer));
  }, [id, run, synced]);
  const finish = useCallback((abandon = false) => run(() => finishTimeAttack(id, abandon)), [id, run]);
  return { snapshot, busy, synced, visible, pending, error, refresh, submit, finish };
}
