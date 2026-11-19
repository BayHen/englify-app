import { beforeEach, describe, expect, it, vi } from 'vitest';
import { endArena, getArenaCatalog, getArenaHistory, getArenaSession, reportArenaQuestion, startArena, submitArena, type ArenaConfig } from './arena-api';
const state = vi.hoisted(() => ({ client: null as unknown }));
vi.mock('@/auth/supabase', () => ({ getSupabase: () => state.client }));
const auth = { getSession: async () => ({ data: { session: { user: { id: 'learner' } } }, error: null }) };
const config: ArenaConfig = { level: 'B1', topic: 'business', kind: 'reading', count: 10, difficulty: 2 };
beforeEach(() => { state.client = null; });
describe('Arena server API', () => {
  it('sends configuration and stable start identity without a score or reward', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { id: 'session' }, error: null, status: 200 }); state.client = { auth, rpc };
    await startArena('request', config); await startArena('request', config);
    expect(rpc.mock.calls).toEqual(Array(2).fill(['englify_arena_start', { p_request_id: 'request', p_level: 'B1', p_topic: 'business', p_kind: 'reading', p_count: 10, p_difficulty: 2 }]));
  });
  it('submits only the session identity and answers, retaining retry semantics', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { status: 'completed', earned_xp: 10 }, error: null, status: 200 }); state.client = { auth, rpc };
    const answers = { question: 'choice' }; await submitArena('session', answers); await submitArena('session', answers);
    expect(rpc.mock.calls).toEqual(Array(2).fill(['englify_arena_submit', { p_session_id: 'session', p_answers: answers }]));
  });
  it('loads catalog, owner session and paginated history through RPCs', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: {}, error: null, status: 200 }); state.client = { auth, rpc };
    await getArenaCatalog(); await getArenaSession('session'); await getArenaHistory(2);
    expect(rpc.mock.calls).toEqual([['englify_arena_catalog'], ['englify_arena_session', { p_session_id: 'session' }], ['englify_arena_history', { p_page: 2 }]]);
  });
  it('handles a void end response without treating it as a missing record', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: null, status: 204 }); state.client = { auth, rpc };
    await expect(endArena('session')).resolves.toBeUndefined();
  });
  it('reports only a session question and reason without changing results', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { id: 'report' }, error: null, status: 200 }); state.client = { auth, rpc };
    await reportArenaQuestion('session', 'question', 'unclear');
    expect(rpc).toHaveBeenCalledWith('englify_report_arena_question', { p_session: 'session', p_question: 'question', p_reason: 'unclear', p_details: '' });
  });
  it('surfaces network failure and allows the same request to be retried', async () => {
    const rpc = vi.fn().mockResolvedValueOnce({ data: null, error: { message: 'network' }, status: 0 })
      .mockResolvedValueOnce({ data: { id: 'session' }, error: null, status: 200 }); state.client = { auth, rpc };
    await expect(startArena('stable', config)).rejects.toThrow('Cannot reach Supabase');
    await expect(startArena('stable', config)).resolves.toEqual({ id: 'session' });
    expect(rpc.mock.calls[0]).toEqual(rpc.mock.calls[1]);
  });
  it('refuses unauthenticated calls before reading or submitting', async () => {
    const rpc = vi.fn(); state.client = { auth: { getSession: async () => ({ data: { session: null }, error: null }) }, rpc };
    await expect(submitArena('session', {})).rejects.toThrow('Session expired'); expect(rpc).not.toHaveBeenCalled();
  });
  it('surfaces ownership and end-session failures', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: null, error: { message: 'Practice session not found' }, status: 404 }); state.client = { auth, rpc };
    await expect(getArenaSession('other')).rejects.toThrow('Practice session not found');
    await expect(endArena('other')).rejects.toThrow('Practice session not found');
  });
});
