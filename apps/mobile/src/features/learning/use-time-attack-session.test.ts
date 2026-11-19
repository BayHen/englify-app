import { beforeEach, describe, expect, it, vi } from 'vitest';
import { useTimeAttackSession } from './use-time-attack-session';
import type { TimeAttackSnapshot } from './time-attack-api';
const model = vi.hoisted(() => ({ slots: [] as unknown[], cursor: 0, mounting: true, effects: [] as (() => void | (() => void))[],
  focus: null as null | (() => void | (() => void)), change: null as null | (() => void), state: 'active', load: vi.fn(), answer: vi.fn(), finish: vi.fn() }));
// Command/lifecycle harness; native event delivery and real rendering are verified separately.
vi.mock('react', () => ({
  useState: (initial: unknown) => { const i = model.cursor++; if (!(i in model.slots)) model.slots[i] = typeof initial === 'function' ? initial() : initial;
    return [model.slots[i], (next: unknown) => { model.slots[i] = typeof next === 'function' ? next(model.slots[i]) : next; }]; },
  useRef: (value: unknown) => { const i = model.cursor++; if (!(i in model.slots)) model.slots[i] = { current: value }; return model.slots[i]; },
  useCallback: (fn: unknown) => fn, useEffect: (fn: () => void | (() => void)) => { if (model.mounting) model.effects.push(fn); },
}));
vi.mock('react-native', () => ({ AppState: { get currentState() { return model.state; }, addEventListener: (_: string, callback: () => void) => { model.change = callback; return { remove() {} }; } }, Platform: { OS: 'ios' } }));
vi.mock('expo-router', () => ({ useFocusEffect: (fn: () => void | (() => void)) => { model.focus = fn; } }));
vi.mock('expo-crypto', () => ({ randomUUID: () => 'stable-answer-request' }));
vi.mock('./time-attack-api', () => ({ getTimeAttack: model.load, answerTimeAttack: model.answer, finishTimeAttack: model.finish }));
function snapshot(answered = 0, status = 'active') { return { session: { id: 'game', status, answered_count: answered, score: answered * 150 }, clock: { receivedAt: 0, remainingAtReceipt: status === 'active' ? 120000 : 0, roundTripMs: 0 } } as TimeAttackSnapshot; }
function renderCommands() {
  model.cursor = 0;
  // React is replaced above: this harness invokes async commands, not a real React render.
  // eslint-disable-next-line react-hooks/rules-of-hooks
  const result = useTimeAttackSession('game');
  if (model.mounting) { model.mounting = false; for (const setup of model.effects) setup(); }
  return result;
}

function deferred<T>() { let resolve!: (value: T) => void; const promise = new Promise<T>(done => { resolve = done; }); return { promise, resolve }; }
beforeEach(() => { model.slots = []; model.cursor = 0; model.mounting = true; model.effects = []; model.state = 'active'; model.focus = null; model.change = null;
  model.load.mockReset().mockResolvedValue(snapshot()); model.answer.mockReset(); model.finish.mockReset(); });
async function start() { renderCommands(); model.focus?.(); await vi.waitFor(() => expect(renderCommands().synced).toBe(true)); return renderCommands(); }
describe('Time Attack recovery and ordering', () => {
  it('locks double answer commands while acceptance is in flight', async () => {
    const value = await start(), accepted = deferred<TimeAttackSnapshot>(); model.answer.mockReturnValue(accepted.promise);
    const first = value.submit('q1', 1, 'answer'); const second = value.submit('q1', 1, 'answer');
    expect(model.answer).toHaveBeenCalledTimes(1); accepted.resolve(snapshot(1)); await first; await second;
    expect(renderCommands().snapshot?.session.answered_count).toBe(1); expect(renderCommands().pending).toBeNull();
  });
  it('retains the exact answer/request through a lost response', async () => {
    const value = await start(); model.answer.mockRejectedValueOnce(new Error('timeout')).mockResolvedValueOnce(snapshot(1));
    await value.submit('q1', 1, 'original'); expect(renderCommands().pending?.answer).toBe('original');
    await renderCommands().submit('q1', 1, 'changed input');
    expect(model.answer.mock.calls[0]).toEqual(model.answer.mock.calls[1]); expect(renderCommands().pending).toBeNull();
  });
  it('requires a fresh server sync after background/foreground even if an older response arrives late', async () => {
    const old = deferred<TimeAttackSnapshot>(), fresh = deferred<TimeAttackSnapshot>(); model.load.mockReturnValueOnce(old.promise).mockReturnValueOnce(fresh.promise);
    renderCommands(); model.focus?.(); model.state = 'background'; model.change?.(); expect(renderCommands().visible).toBe(false);
    model.state = 'active'; model.change?.(); old.resolve(snapshot(0));
    await vi.waitFor(() => expect(model.load).toHaveBeenCalledTimes(2)); expect(renderCommands().synced).toBe(false);
    fresh.resolve(snapshot(2, 'expired')); await vi.waitFor(() => expect(renderCommands().synced).toBe(true));
    expect(renderCommands().snapshot?.session.status).toBe('expired'); expect(renderCommands().snapshot?.session.score).toBe(300);
  });
  it('queues restoration behind an uncertain answer instead of applying out-of-order state', async () => {
    const value = await start(), accepted = deferred<TimeAttackSnapshot>(); model.answer.mockReturnValueOnce(accepted.promise); model.load.mockResolvedValue(snapshot(1));
    const request = value.submit('q1', 1, 'answer'); renderCommands().refresh(); expect(renderCommands().synced).toBe(false);
    accepted.resolve(snapshot(1)); await request; await vi.waitFor(() => expect(model.load).toHaveBeenCalledTimes(2));
    await vi.waitFor(() => expect(renderCommands().synced).toBe(true)); expect(renderCommands().snapshot?.session.answered_count).toBe(1);
  });
});
