import { describe, expect, it } from 'vitest';
import { captureServerClock, remainingServerTime, timeAttackClockLabel } from './time-attack-clock';
describe('server-synchronized Time Attack clock', () => {
  it('anchors the deadline to monotonic receipt time and accounts for round-trip latency', () => {
    const clock = captureServerClock('2026-11-18T00:02:00Z', '2026-11-18T00:00:00Z', 1000, 1200);
    expect(clock.roundTripMs).toBe(200); expect(remainingServerTime(clock, 1200)).toBe(119900);
    expect(remainingServerTime(clock, 51200)).toBe(69900); expect(remainingServerTime(clock, 200000)).toBe(0);
  });
  it('never derives time from the device wall clock', () => {
    const clock = captureServerClock('2026-11-18T00:02:00Z', '2026-11-18T00:00:00Z', 0, 0);
    const original = Date.now; Date.now = () => 0;
    try { expect(remainingServerTime(clock, 30000)).toBe(90000); Date.now = () => 999999999999999; expect(remainingServerTime(clock, 30000)).toBe(90000); }
    finally { Date.now = original; }
  });
  it('does not add time for a backwards monotonic sample or an invalid timestamp', () => {
    const clock = captureServerClock('2026-11-18T00:02:00Z', '2026-11-18T00:00:00Z', 20, 10);
    expect(clock.roundTripMs).toBe(0); expect(remainingServerTime(clock, 0)).toBe(120000);
    expect(captureServerClock('invalid', 'invalid', 0, 0).remainingAtReceipt).toBe(0);
  });
  it('restores a backgrounded session from a fresh server deadline without restoring elapsed time', () => {
    const initial = captureServerClock('2026-11-18T00:02:00Z', '2026-11-18T00:00:00Z', 0, 0);
    expect(remainingServerTime(initial, 20000)).toBe(100000);
    // Even if a platform paused its monotonic clock while suspended, foreground sync uses fresh server_now.
    const foreground = captureServerClock('2026-11-18T00:02:00Z', '2026-11-18T00:03:00Z', 20000, 20100);
    expect(remainingServerTime(foreground, 20100)).toBe(0);
  });
  it.each([[120000, '2:00'], [119001, '2:00'], [119000, '1:59'], [1, '0:01'], [0, '0:00']])('formats %s milliseconds', (value, label) => {
    expect(timeAttackClockLabel(Number(value))).toBe(label);
  });
});
