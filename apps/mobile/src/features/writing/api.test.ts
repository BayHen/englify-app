import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createWritingRevision, getDailyWritingOverview, getExercises, getWritingAnalytics, getWritingAnalyticsDetail,
  getWritingAnalyticsHistory, getWritingHistory, getWritingTopics,
  recommendExercises, requestWritingCoach, requestWritingRewrite, setWritingLevel, setWritingTimezone,
  submitDailyWriting, submitWriting, type Exercise } from './api';

const state = vi.hoisted(() => ({ client: null as unknown }));
vi.mock('@/auth/supabase', () => ({ getSupabase: () => state.client }));
const auth = { getSession: async () => ({ data: { session: { user: { id: 'learner-1' }, access_token: 'token' } }, error: null }) };
beforeEach(() => { state.client = null; });

describe('writing Supabase client', () => {
  it('loads published exercises through the filtered library RPC', async () => {
    const exercises = [{ id: 'exercise-1', kind: 'sentence', prompt: 'Write a greeting.', hint: 'Be friendly.', tokens: [] }];
    const rpc = vi.fn().mockResolvedValue({ data: { items: exercises, total: 1, page: 1, page_size: 50 }, error: null, status: 200 });
    state.client = { auth, rpc };

    await expect(getExercises()).resolves.toEqual(exercises);
    expect(rpc).toHaveBeenCalledWith('englify_writing_library', { p_query: '', p_level: null, p_topic_id: null,
      p_kind: null, p_page: 1, p_page_size: 50 });
  });

  it('keeps rule feedback when optional grammar Edge service is unavailable', async () => {
    const saved = { id: 'submission-1', body: 'Hello.', feedback: { rule_result: 'matched', grammar_status: 'unavailable' } };
    const rpc = vi.fn().mockResolvedValue({ data: saved, error: null, status: 200 });
    const invoke = vi.fn().mockRejectedValue(new Error('Edge unavailable'));
    state.client = { auth, rpc, functions: { invoke } };
    await expect(submitWriting('request-1', 'exercise-1', 'Hello.', true)).resolves.toBe(saved);
    expect(rpc).toHaveBeenCalledWith('englify_submit_writing', {
      p_request_id: 'request-1', p_exercise_id: 'exercise-1', p_body: 'Hello.', p_grammar_check: true,
    });
    expect(invoke).toHaveBeenCalledWith('writing-grammar', { body: { submissionId: 'submission-1' } });
  });
  it('reloads persisted provider feedback only after Edge confirms it', async () => {
    const saved = { id: 'submission-1', feedback: { grammar_status: 'unavailable' } };
    const enriched = { id: 'submission-1', feedback: { grammar_status: 'available', grammar_matches: [] } };
    const rpc = vi.fn().mockResolvedValueOnce({ data: saved, error: null, status: 200 })
      .mockResolvedValueOnce({ data: enriched, error: null, status: 200 });
    state.client = { auth, rpc, functions: { invoke: vi.fn().mockResolvedValue({ data: { status: 'available' }, error: null }) } };
    await expect(submitWriting('request-1', 'exercise-1', 'Hello.', true)).resolves.toBe(enriched);
    expect(rpc).toHaveBeenNthCalledWith(2, 'englify_writing_submission', { p_submission_id: 'submission-1' });
  });
  it('loads durable history through the ownership-checked RPC', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: [{ id: 'submission-1' }], error: null, status: 200 });
    state.client = { auth, rpc };
    await expect(getWritingHistory()).resolves.toEqual([{ id: 'submission-1' }]);
    expect(rpc).toHaveBeenCalledWith('englify_writing_history', { p_limit: 30 });
  });
  it('invokes the dedicated coach and rewrite functions with typed requests', async () => {
    const feedback = { id: 'feedback-1', overall_score: 80 };
    const rewrite = { id: 'rewrite-1', mode: 'natural' };
    const invoke = vi.fn().mockResolvedValueOnce({ data: { feedback }, error: null })
      .mockResolvedValueOnce({ data: { rewrite }, error: null });
    state.client = { auth, functions: { invoke } };
    await expect(requestWritingCoach('submission-1', 'request-1')).resolves.toBe(feedback);
    await expect(requestWritingRewrite('submission-1', 'request-2', 'natural')).resolves.toBe(rewrite);
    expect(invoke).toHaveBeenNthCalledWith(1, 'writing-ai-coach', { body: { submissionId: 'submission-1', requestId: 'request-1' } });
    expect(invoke).toHaveBeenNthCalledWith(2, 'writing-ai-rewrite', { body: { submissionId: 'submission-1', requestId: 'request-2', mode: 'natural' } });
  });
  it('creates a revision only through the ownership-checked RPC', async () => {
    const revision = { id: 'revision-1', revision_number: 1 };
    const rpc = vi.fn().mockResolvedValue({ data: revision, error: null, status: 200 }); state.client = { auth, rpc };
    await expect(createWritingRevision('request-3', 'submission-1', 'Revised text.', 'rewrite-1', 'feedback-1')).resolves.toBe(revision);
    expect(rpc).toHaveBeenCalledWith('englify_create_writing_revision', { p_request_id: 'request-3', p_submission_id: 'submission-1',
      p_revised_text: 'Revised text.', p_rewrite_id: 'rewrite-1', p_ai_feedback_id: 'feedback-1' });
  });
  it('persists an independent writing level and loads topic counts', async () => {
    const rpc = vi.fn().mockResolvedValueOnce({ data: 'B1', error: null, status: 200 })
      .mockResolvedValueOnce({ data: [{ id: 'topic-1', exercise_count: 4 }], error: null, status: 200 });
    state.client = { auth, rpc };
    await expect(setWritingLevel('B1')).resolves.toBe('B1');
    await expect(getWritingTopics('B1')).resolves.toEqual([{ id: 'topic-1', exercise_count: 4 }]);
  });
  it('loads the server-authoritative daily challenge and updates timezone through RPCs', async () => {
    const overview = { local_date: '2026-11-17', timezone: 'Asia/Ho_Chi_Minh', challenge: { assignment_id: 'assignment-1' } };
    const timezone = { timezone: 'Asia/Tokyo', pending_timezone: null, effective_at: null };
    const rpc = vi.fn().mockResolvedValueOnce({ data: overview, error: null, status: 200 })
      .mockResolvedValueOnce({ data: timezone, error: null, status: 200 });
    state.client = { auth, rpc };
    await expect(getDailyWritingOverview()).resolves.toBe(overview);
    await expect(setWritingTimezone('Asia/Tokyo')).resolves.toBe(timezone);
    expect(rpc).toHaveBeenNthCalledWith(1, 'englify_writing_daily_overview');
    expect(rpc).toHaveBeenNthCalledWith(2, 'englify_set_writing_timezone', { p_timezone: 'Asia/Tokyo' });
  });
  it('submits a daily challenge with a stable request identity and no client XP value', async () => {
    const result = { completed: true, newly_completed: true, earned_xp: 20 };
    const rpc = vi.fn().mockResolvedValue({ data: result, error: null, status: 200 });
    state.client = { auth, rpc };
    await expect(submitDailyWriting('assignment-1', 'request-1', 'My server-validated response.', false)).resolves.toBe(result);
    expect(rpc).toHaveBeenCalledWith('englify_submit_daily_writing', { p_assignment_id: 'assignment-1',
      p_request_id: 'request-1', p_body: 'My server-validated response.', p_grammar_check: false });
  });
  it('recommends unique incomplete exercises before completed ones', () => {
    const exercise = (id: string, difficulty: number) => ({ id, difficulty } as Exercise);
    const result = recommendExercises([exercise('done', 1), exercise('new-2', 2), exercise('new-1', 1), exercise('new-1', 1)],
      [{ exercise_id: 'done' }] as never[], 3);
    expect(result.map((item) => item.id)).toEqual(['new-1', 'new-2', 'done']);
  });
  it('loads Writing analytics through bounded ownership-checked RPCs', async () => {
    const rpc = vi.fn().mockImplementation(async (name:string) => ({ data: name==='englify_writing_analytics_history'
      ? { items:[],total:0,page:1,page_size:5 } : name==='englify_writing_analytics_detail' ? { id:'submission-1' }
        : name==='englify_writing_progress_summary' ? { total_submissions:0 } : [], error:null,status:200 }));
    state.client={auth,rpc};
    await expect(getWritingAnalyticsHistory({range:'30d',aiStatus:'scored',page:2,pageSize:5})).resolves.toMatchObject({page:1,page_size:5});
    expect(rpc).toHaveBeenCalledWith('englify_writing_analytics_history',{p_range:'30d',p_level:null,p_topic_id:null,
      p_kind:null,p_ai_status:'scored',p_page:2,p_page_size:5});
    await expect(getWritingAnalyticsDetail('submission-1')).resolves.toEqual({id:'submission-1'});
    expect(rpc).toHaveBeenCalledWith('englify_writing_analytics_detail',{p_submission_id:'submission-1'});
    await getWritingAnalytics('7d');
    expect(rpc).toHaveBeenCalledWith('englify_writing_activity_stats',{p_range:'7d'});
    expect(rpc).toHaveBeenCalledWith('englify_writing_score_analytics',{p_range:'7d',p_level:null,p_kind:null});
    expect(rpc).toHaveBeenCalledWith('englify_writing_report',{p_period:'weekly'});
  });
});
