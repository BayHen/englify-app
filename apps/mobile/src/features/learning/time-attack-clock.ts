// Only an estimate for presentation. The server independently enforces every deadline.
export type ServerClock = { remainingAtReceipt: number; receivedAt: number; roundTripMs: number };
export function captureServerClock(expiresAt: string, serverNow: string, sentAt: number, receivedAt: number): ServerClock {
  const roundTripMs = Math.max(0, receivedAt - sentAt);
  const budget = Date.parse(expiresAt) - Date.parse(serverNow) - roundTripMs / 2;
  return { remainingAtReceipt: Number.isFinite(budget) ? Math.max(0, budget) : 0, receivedAt, roundTripMs };
}
export function remainingServerTime(clock: ServerClock, monotonicNow: number): number {
  return Math.max(0, clock.remainingAtReceipt - Math.max(0, monotonicNow - clock.receivedAt));
}
export function timeAttackClockLabel(ms: number): string {
  const seconds = Math.max(0, Math.ceil(ms / 1000)); return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}
