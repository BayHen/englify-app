import { beforeEach, describe, expect, it, vi } from 'vitest';
import { getMistakes, getMistakeSummary, getQuizRecommendations, getWeaknessAnalytics, getMistakeReview, startMistakeReview, submitMistakeReview } from './mistake-review-api';
const state = vi.hoisted(() => ({ client: null as unknown }));
vi.mock('@/auth/supabase', () => ({ getSupabase: () => state.client }));
const auth = { getSession: async () => ({ data: { session: { user: { id: 'learner' } } }, error: null }) };
beforeEach(() => { state.client = null; });
describe('mistake review API integrity', () => {
  it('uses server-owned projections for dashboard data', async () => { const rpc = vi.fn().mockResolvedValue({ data: {}, error: null }); state.client = { auth, rpc }; await getMistakeSummary(); await getMistakes({ page: 2, cefr: 'B1', topic: 'grammar', status: 'learning' }); await getWeaknessAnalytics(); await getQuizRecommendations(); expect(rpc.mock.calls).toEqual([
    ['englify_quiz_mistake_summary', undefined],
    ['englify_quiz_mistakes', { p_page: 2, p_cefr: 'B1', p_topic: 'grammar', p_kind: null, p_status: 'learning' }],
    ['englify_quiz_weakness_analytics', undefined], ['englify_quiz_recommendations', undefined],
  ]); });
  it('starts and restores without accepting score, XP, stage, or answer keys', async () => { const rpc = vi.fn().mockResolvedValue({ data: { id: 'session' }, error: null }); state.client = { auth, rpc }; await startMistakeReview('request', 5); await getMistakeReview('session'); expect(rpc.mock.calls).toEqual([
    ['englify_quiz_start_review', { p_request_id: 'request', p_count: 5 }], ['englify_quiz_review_session', { p_session: 'session' }],
  ]); });
  it('submits only session, current item, idempotency key, and answer', async () => { const rpc = vi.fn().mockResolvedValue({ data: {}, error: null }); state.client = { auth, rpc }; await submitMistakeReview('session', 'progress', 'request', 'answer'); expect(rpc).toHaveBeenCalledWith('englify_quiz_submit_review', { p_session: 'session', p_progress: 'progress', p_request_id: 'request', p_answer: 'answer' }); });
});
