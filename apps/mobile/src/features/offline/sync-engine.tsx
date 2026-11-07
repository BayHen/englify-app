import { useEffect } from 'react';
import * as Network from 'expo-network';
import { useAuth } from '@/auth/provider';
import { syncOutbox } from './sync';

/** Keeps the queue moving even when the learner stays on Home after reconnecting. */
export function SyncEngine() {
  const { profile } = useAuth();
  const userId = profile?.id;
  useEffect(() => {
    if (!userId) return;
    let mounted = true;
    const attempt = async () => {
      try {
        const state = await Network.getNetworkStateAsync();
        if (mounted && state.isConnected && state.isInternetReachable !== false) await syncOutbox(userId);
      } catch { /* Outbox stays intact; a later retry can recover. */ }
    };
    const listener = Network.addNetworkStateListener((state) => {
      if (state.isConnected && state.isInternetReachable !== false) void attempt();
    });
    void attempt();
    const timer = setInterval(() => { void attempt(); }, 30_000);
    return () => { mounted = false; listener.remove(); clearInterval(timer); };
  }, [userId]);
  return null;
}
