import { beforeEach, describe, expect, it, vi } from 'vitest';
import { answerTimeAttack, finishTimeAttack, getTimeAttack, getTimeAttackHistory, getTimeAttackRecords, startTimeAttack } from './time-attack-api';
const state = vi.hoisted(() => ({ client: null as unknown }));
vi.mock('@/auth/supabase', () => ({ getSupabase: () => state.client }));
const auth = { getSession: async () => ({ data: { session: { user: { id: 'learner' } } }, error: null }) };
const data = { id: 'game', server_now: '2026-11-18T00:00:00Z', expires_at: '2026-11-18T00:02:00Z' };
beforeEach(() => { state.client = null; });
describe('Time Attack API integrity', () => {
  it('sends only the named difficulty and CEFR instead of arbitrary game rules', async () => {
    const rpc = vi.fn().mockResolvedValue({ data, error: null, status: 200 }); state.client = { auth, rpc };
    const result = await startTimeAttack('request', 'B1', 'hard');
    expect(rpc).toHaveBeenCalledWith('englify_time_attack_start', { p_request_id: 'request', p_level: 'B1', p_difficulty: 'hard' });
    expect(result.session).toBe(data); expect(result.clock.remainingAtReceipt).toBeLessThanOrEqual(120000);
  });
  it('sends one answer and a stable identity, never a client score, combo, life count or timestamp', async () => {
    const rpc = vi.fn().mockResolvedValue({ data, error: null, status: 200 }); state.client = { auth, rpc };
    await answerTimeAttack('game', 'question', 'request', 'choice'); await answerTimeAttack('game', 'question', 'request', 'choice');
    expect(rpc.mock.calls).toEqual(Array(2).fill(['englify_time_attack_answer', { p_session_id: 'game', p_question_id: 'question', p_request_id: 'request', p_answer: 'choice' }]));
  });
  it('loads authoritative state and can finish only by requesting expiry or abandonment', async () => {
    const rpc = vi.fn().mockResolvedValue({ data, error: null, status: 200 }); state.client = { auth, rpc };
    await getTimeAttack('game'); await finishTimeAttack('game'); await finishTimeAttack('game', true);
    expect(rpc.mock.calls).toEqual([['englify_time_attack_session', { p_session_id: 'game' }], ['englify_time_attack_finish', { p_session_id: 'game', p_abandon: false }], ['englify_time_attack_finish', { p_session_id: 'game', p_abandon: true }]]);
  });
  it('gets records and history through owner-scoped operations', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: {}, error: null, status: 200 }); state.client = { auth, rpc };
    await getTimeAttackHistory(3); await getTimeAttackRecords();
    expect(rpc.mock.calls).toEqual([['englify_time_attack_history', { p_page: 3 }], ['englify_time_attack_records']]);
  });
  it('preserves request identity through a timeout and retry', async () => {
    const rpc = vi.fn().mockResolvedValueOnce({ data: null, error: { message: 'timeout' }, status: 0 }).mockResolvedValueOnce({ data, error: null, status: 200 }); state.client = { auth, rpc };
    await expect(answerTimeAttack('game', 'q', 'stable', 'answer')).rejects.toThrow('Cannot reach Supabase');
    await expect(answerTimeAttack('game', 'q', 'stable', 'answer')).resolves.toMatchObject({ session: data });
    expect(rpc.mock.calls[0]).toEqual(rpc.mock.calls[1]);
  });
  it('rejects unauthenticated state access without calling the server', async () => {
    const rpc = vi.fn(); state.client = { auth: { getSession: async () => ({ data: { session: null }, error: null }) }, rpc };
    await expect(getTimeAttack('game')).rejects.toThrow('Session expired'); expect(rpc).not.toHaveBeenCalled();
  });
});
