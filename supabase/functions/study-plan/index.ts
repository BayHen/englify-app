// Supabase Edge orchestration for deterministic plan version 1. All mutations use database RPCs.
// @ts-ignore Deno requires explicit TypeScript extensions.
import { ALGORITHM_VERSION, generateWeek, type PlanInput } from '../_shared/plan-rules.ts';

declare const Deno: { env: { get(name: string): string | undefined }; serve(handler: (request: Request) => Promise<Response>): void };
type Row = Record<string, unknown>;
type Preferences = { learning_goal: string; initial_proficiency: string; daily_goal_minutes: number; preferred_topics: string[]; onboarding_completed_at: string | null };
type Lesson = { id: string; title: string; unit_id: string; position: number };
type Unit = { id: string; course_id: string; position: number };
type Course = { id: string; level: number };
class PlanError extends Error { constructor(public status: number, message: string) { super(message); } }
const allowedOrigin = (origin?: string) => !origin || (Deno.env.get('EDGE_ALLOWED_ORIGINS') ?? '').split(',').map((x) => x.trim()).includes(origin);
const json = (value: unknown, status = 200, origin?: string) => new Response(JSON.stringify(value), { status, headers: {
  'Content-Type': 'application/json; charset=utf-8', Vary: 'Origin', ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}),
} });
function key(): string | null {
  const direct = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  if (direct) return direct;
  try { const keys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') ?? '{}') as Record<string, string>;
    return keys.default ?? Object.values(keys)[0] ?? null; } catch { return null; }
}

Deno.serve(async (request) => {
  const origin = request.headers.get('Origin') ?? undefined;
  if (!allowedOrigin(origin)) return json({ error: 'Origin not allowed.' }, 403);
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: {
    Vary: 'Origin', ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}),
    'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  } });
  if (request.method !== 'POST') return json({ error: 'Method not allowed.' }, 405, origin);
  const authorization = request.headers.get('Authorization') ?? '';
  if (!/^Bearer [A-Za-z0-9._-]+$/.test(authorization)) return json({ error: 'Authentication required.' }, 401, origin);
  const base = Deno.env.get('SUPABASE_URL'); const publicKey = key();
  if (!base || !publicKey) return json({ error: 'Learning service is not configured.' }, 503, origin);
  const headers = { apikey: publicKey, Authorization: authorization, 'Content-Type': 'application/json' };
  let userId: string;
  try {
    const verified = await fetch(`${base}/auth/v1/user`, { headers, signal: AbortSignal.timeout(5000) });
    if (!verified.ok) return json({ error: 'Session expired. Sign in again.' }, 401, origin);
    const user = await verified.json() as { id?: string };
    if (!user.id || !/^[0-9a-f-]{36}$/i.test(user.id)) return json({ error: 'Invalid session.' }, 401, origin);
    userId = user.id;
  } catch { return json({ error: 'Authentication service unavailable.' }, 503, origin); }
  let body: Row;
  try {
    const raw = await request.text();
    if (raw.length > 4000) return json({ error: 'Request is too large.' }, 413, origin);
    body = JSON.parse(raw) as Row;
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error('invalid body');
  } catch { return json({ error: 'Invalid request.' }, 400, origin); }
  const action = body.action;
  if (!['get', 'regenerate', 'reschedule', 'preferences', 'complete'].includes(String(action))) {
    return json({ error: 'Unknown plan action.' }, 422, origin);
  }
  async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
    let response: Response;
    try { response = await fetch(`${base}/rest/v1/${path}`, { ...init,
      headers: { ...headers, ...init.headers }, signal: AbortSignal.timeout(8000) }); }
    catch { throw new PlanError(503, 'Learning database is unavailable.'); }
    if (!response.ok) {
      const detail = await response.json().catch(() => ({})) as { code?: string };
      throw new PlanError(detail.code === 'P0002' ? 404 : detail.code === '22023' ? 422 : 503,
        detail.code === 'P0002' ? 'Plan item not found.' : detail.code === '22023' ? 'Invalid plan operation.' : 'Learning plan could not be updated.');
    }
    if (response.status === 204) return null as T;
    return response.json() as Promise<T>;
  }
  const select = <T>(table: string, params: Record<string, string>) => api<T[]>(`${table}?${new URLSearchParams(params)}`);
  const rpc = <T>(name: string, values: Row) => api<T>(`rpc/${name}`, { method: 'POST', body: JSON.stringify(values) });
  async function preferences(): Promise<Preferences> {
    const rows = await select<Preferences>('user_preferences', { select: 'learning_goal,initial_proficiency,daily_goal_minutes,preferred_topics,onboarding_completed_at', user_id: `eq.${userId}`, limit: '1' });
    const pref = rows[0];
    if (!pref?.onboarding_completed_at || !pref.learning_goal || !pref.initial_proficiency) throw new PlanError(409, 'Complete onboarding first.');
    return pref;
  }
  async function catalog() {
    const [courses, units, lessons, progress] = await Promise.all([
      select<Course>('courses', { select: 'id,level', is_published: 'eq.true', archived_at: 'is.null' }),
      select<Unit>('learning_units', { select: 'id,course_id,position', is_published: 'eq.true', archived_at: 'is.null' }),
      select<Lesson>('lessons', { select: 'id,title,unit_id,position', is_published: 'eq.true', archived_at: 'is.null' }),
      select<{ lesson_id: string; status: string }>('learning_progress', { select: 'lesson_id,status', user_id: `eq.${userId}` }),
    ]);
    const courseById = new Map(courses.map((c) => [c.id, c]));
    const unitById = new Map(units.filter((u) => courseById.has(u.course_id)).map((u) => [u.id, u]));
    const statusById = new Map(progress.map((p) => [p.lesson_id, p.status]));
    const sorted = lessons.filter((l) => unitById.has(l.unit_id)).sort((a, b) => {
      const ua = unitById.get(a.unit_id)!; const ub = unitById.get(b.unit_id)!;
      const ca = courseById.get(ua.course_id)!; const cb = courseById.get(ub.course_id)!;
      return ca.level - cb.level || ca.id.localeCompare(cb.id) || ua.position - ub.position || a.position - b.position;
    });
    const states = new Map<string, string>(); const candidates: PlanInput['lessons'] = [];
    let courseId = ''; let previousDone = true;
    for (const lesson of sorted) {
      const unit = unitById.get(lesson.unit_id)!;
      if (unit.course_id !== courseId) { courseId = unit.course_id; previousDone = true; }
      const status = statusById.get(lesson.id);
      states.set(lesson.id, status && ['in_progress', 'completed', 'mastered'].includes(status) ? status : previousDone ? 'available' : 'locked');
      previousDone = status === 'completed' || status === 'mastered';
      candidates.push({ id: lesson.id, title: lesson.title, completed: previousDone });
    }
    return { candidates, states, statusById };
  }
  async function activePlan() {
    const rows = await select<{ id: string; starts_on: string; algorithm_version: number }>('learning_plans', {
      select: 'id,starts_on,algorithm_version', user_id: `eq.${userId}`, status: 'eq.active', limit: '1',
    });
    return rows[0] ?? null;
  }
  async function generate(force: boolean) {
    if (!force && await activePlan()) return;
    const pref = await preferences(); const current = await catalog();
    const recent = await select<{ correct_count: number; question_count: number }>('lesson_attempts', {
      select: 'correct_count,question_count', user_id: `eq.${userId}`, order: 'created_at.desc', limit: '10',
    });
    const totals = recent.reduce((acc, row) => ({ correct: acc.correct + row.correct_count, questions: acc.questions + row.question_count }), { correct: 0, questions: 0 });
    const now = new Date(); const today = now.toISOString().slice(0, 10);
    const due = await select<{ id: string }>('saved_vocabulary', {
      select: 'id', user_id: `eq.${userId}`, or: `(next_review_at.is.null,next_review_at.lte.${now.toISOString()})`, limit: '10',
    });
    const tasks = generateWeek({ start: today, proficiency: pref.initial_proficiency, goal: pref.learning_goal,
      daily_minutes: pref.daily_goal_minutes, topics: pref.preferred_topics ?? [],
      quiz_accuracy: totals.questions ? totals.correct / totals.questions : null,
      lessons: current.candidates, due_reviews: due.length });
    await rpc<string>('englify_plan_replace', { p_tasks: tasks, p_force: force });
  }
  async function readPlan() {
    const pref = await preferences(); const plan = await activePlan();
    if (!plan) throw new PlanError(404, 'Learning plan not found.');
    const [tasks, current] = await Promise.all([
      select<Row>('learning_plan_tasks', { select: 'id,kind,title,scheduled_on,original_date,duration_minutes,target_count,topic,lesson_id,status,position',
        user_id: `eq.${userId}`, plan_id: `eq.${plan.id}`, order: 'scheduled_on.asc,position.asc' }), catalog(),
    ]);
    const mapped = tasks.map((item) => {
      const lessonId = typeof item.lesson_id === 'string' ? item.lesson_id : null;
      const lessonState = lessonId ? current.states.get(lessonId) ?? 'locked' : null;
      return { ...item, status: lessonState === 'completed' || lessonState === 'mastered' ? 'completed' : item.status,
        lesson_state: lessonState };
    });
    return { id: plan.id, starts_on: plan.starts_on, algorithm_version: plan.algorithm_version,
      preferences: { learning_goal: pref.learning_goal, initial_proficiency: pref.initial_proficiency,
        daily_goal_minutes: pref.daily_goal_minutes, preferred_topics: pref.preferred_topics ?? [] },
      tasks: mapped, completed_count: mapped.filter((item) => item.status === 'completed').length,
      total_count: mapped.length, weekly_minutes: mapped.reduce((sum, item) => sum + Number(item.duration_minutes), 0) };
  }
  try {
    if (action === 'preferences') {
      const value = body.preferences as Row | undefined;
      const topics = value?.preferred_topics;
      if (!value || !['conversation','travel','work','exams','real_english'].includes(String(value.learning_goal))
          || !['beginner','intermediate','advanced'].includes(String(value.initial_proficiency))
          || !Number.isInteger(value.daily_goal_minutes) || Number(value.daily_goal_minutes) < 1 || Number(value.daily_goal_minutes) > 180
          || !Array.isArray(topics) || topics.length > 8 || topics.some((t) => typeof t !== 'string' || !t.trim() || t.length > 40)
          || new Set(topics.map((t) => String(t).toLowerCase())).size !== topics.length) {
        throw new PlanError(422, 'Invalid study preferences.');
      }
      await preferences();
      await api<unknown>(`user_preferences?user_id=eq.${userId}`, { method: 'PATCH', body: JSON.stringify({
        learning_goal: value.learning_goal, initial_proficiency: value.initial_proficiency,
        daily_goal_minutes: value.daily_goal_minutes, preferred_topics: topics.map((t) => String(t).trim().toLowerCase()),
      }) });
      await generate(true);
    } else if (action === 'regenerate') await generate(true);
    else if (action === 'get') await generate(false);
    else if (action === 'reschedule') await rpc('englify_plan_reschedule', {});
    else if (action === 'complete') {
      if (typeof body.taskId !== 'string' || !/^[0-9a-f-]{36}$/i.test(body.taskId)) throw new PlanError(422, 'Invalid task ID.');
      await rpc('englify_plan_complete_task', { p_task_id: body.taskId });
    }
    return json(await readPlan(), 200, origin);
  } catch (cause) {
    if (cause instanceof PlanError) return json({ error: cause.message }, cause.status, origin);
    return json({ error: 'Learning plan unavailable. Try again.' }, 503, origin);
  }
});