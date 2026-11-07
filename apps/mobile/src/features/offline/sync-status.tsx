import { useCallback, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import * as Network from 'expo-network';
import { useAuth } from '@/auth/provider';
import { AppButton, AppCard, AppText } from '@/ui';
import { listEvents } from './storage';
import { retryPendingNow, syncOutbox } from './sync';

export function SyncStatus() {
  const { profile } = useAuth();
  const userId = profile?.id;
  const [online, setOnline] = useState(true);
  const [busy, setBusy] = useState(false);
  const [pending, setPending] = useState(0);
  const [conflicts, setConflicts] = useState(0);
  const [message, setMessage] = useState('');
  const refresh = useCallback(async () => {
    if (!userId) return;
    const events = await listEvents(userId);
    setPending(events.filter((event) => event.status === 'pending').length);
    setConflicts(events.filter((event) => event.status === 'conflict' || event.status === 'rejected').length);
  }, [userId]);
  useFocusEffect(useCallback(() => { void refresh(); }, [refresh]));
  useFocusEffect(useCallback(() => {
    if (!userId) return;
    const subscription = Network.addNetworkStateListener((state) => {
      const connected = Boolean(state.isConnected && state.isInternetReachable !== false);
      setOnline(connected);
      if (connected) void syncOutbox(userId).then(() => refresh()).catch(() => refresh());
    });
    void Network.getNetworkStateAsync().then((state) => {
      const connected = Boolean(state.isConnected && state.isInternetReachable !== false);
      setOnline(connected);
      if (connected) void syncOutbox(userId).then(() => refresh()).catch(() => refresh());
    });
    const timer = setInterval(() => { void syncOutbox(userId).then(() => refresh()).catch(() => refresh()); }, 30_000);
    return () => { subscription.remove(); clearInterval(timer); };
  }, [userId, refresh]));
  async function manualSync() {
    if (!userId || busy) return;
    setBusy(true); setMessage('');
    try { const result = await retryPendingNow(userId); setMessage(`${result.synced} item(s) synced. ${result.pending} waiting.`); await refresh(); }
    catch (cause) { setMessage(cause instanceof Error ? cause.message : 'Sync unavailable'); }
    finally { setBusy(false); }
  }
  return <AppCard tone={online ? 'surface' : 'reward'} style={{ gap: 6 }}>
    <AppText variant="label">{online ? busy ? 'Syncing…' : 'Online' : 'Offline'} · {pending} waiting · {conflicts} need review</AppText>
    {conflicts > 0 ? <AppText tone="muted">Some attempts could not be accepted. Your local answers are retained; open the lesson and download the latest version before retrying.</AppText> : null}
    {message ? <AppText tone="muted">{message}</AppText> : null}
    <AppButton label="Sync now" variant="secondary" onPress={() => { void manualSync(); }} loading={busy} />
  </AppCard>;
}
