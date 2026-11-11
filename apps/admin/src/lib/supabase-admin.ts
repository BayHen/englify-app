import type { SupabaseClient } from '@supabase/supabase-js';

type Row = Record<string, unknown> & { id: string };
type Resource = keyof typeof schema;
const schema = {
  vocabulary: { term: 'text', definition: 'text', translation: 'text', ipa: 'optional', part_of_speech: 'optional', example: 'optional', audio_url: 'optional', source_name: 'text', license_id: 'text' },
  courses: { slug: 'slug', title: 'text', description: 'optional', level: 'positive' },
  units: { course_id: 'uuid', slug: 'slug', title: 'text', position: 'positive' },
  lessons: { course_id: 'uuid', unit_id: 'uuid', slug: 'slug', title: 'text', objective: 'text', position: 'positive', xp_reward: 'xp', content: 'object' },
  'lesson-items': { lesson_id: 'uuid', position: 'positive', kind: 'item_kind', body: 'object' },
  'quiz-questions': { lesson_id: 'uuid', position: 'positive', kind: 'question_kind', prompt: 'text', explanation: 'optional', payload: 'object', answer: 'json' },
  'quiz-options': { question_id: 'uuid', position: 'positive', answer_text: 'text', is_correct: 'boolean' },
  'real-english': { slug: 'slug', kind: 'expression_kind', expression: 'text', meaning_vi: 'text', context_explanation: 'text', example_en: 'text', example_vi: 'text', dialogue: 'array', formality: 'formality', region_note: 'text', source_name: 'text', license_id: 'text', provenance_note: 'text' },
  badges: { code: 'slug', title: 'text', description: 'optional', metric: 'badge_metric', target: 'positive' },
} as const;
const tables: Record<Resource, string> = {
  vocabulary: 'dictionary_entries', courses: 'courses', units: 'learning_units', lessons: 'lessons',
  'lesson-items': 'lesson_items', 'quiz-questions': 'quiz_questions', 'quiz-options': 'quiz_options',
  'real-english': 'real_english_expressions', badges: 'badges',
};
const searchFields = ['title', 'term', 'expression', 'prompt', 'answer_text', 'kind', 'slug', 'code'] as const;

function checked<T>(result: { data: T | null; error: { message: string } | null }): T {
  if (result.error) throw new Error(result.error.message);
  if (result.data === null) throw new Error('Content item not found.');
  return result.data;
}
function noError(result: { error: { message: string } | null }): void {
  if (result.error) throw new Error(result.error.message);
}
function resourceOf(value: string): Resource {
  if (!(value in tables)) throw new Error('Unknown content resource.');
  return value as Resource;
}
async function row(client: SupabaseClient, resource: Resource, id: string): Promise<Row> {
  const item = checked(await client.from(tables[resource]).select('*').eq('id', id).maybeSingle()) as Row | null;
  if (!item) throw new Error('Content item not found.');
  if (resource === 'quiz-questions') {
    const answer = checked(await client.from('quiz_answer_keys').select('answer').eq('question_id', id).maybeSingle()) as { answer: unknown } | null;
    item.answer = answer?.answer ?? null;
  }
  if (resource === 'badges') {
    const rule = checked(await client.from('badge_rules').select('metric,target').eq('badge_id', id).maybeSingle()) as { metric: string; target: number } | null;
    item.metric = rule?.metric ?? null; item.target = rule?.target ?? null;
  }
  return item;
}
async function write(client: SupabaseClient, resource: Resource, id: string | null, raw: Record<string, unknown>): Promise<Row> {
  const data = { ...raw };
  if (!Object.keys(data).length || Object.keys(data).some((key) => !(key in schema[resource]))) {
    throw new Error('Unknown or empty content fields.');
  }
  const answer = resource === 'quiz-questions' ? data.answer : undefined;
  const metric = resource === 'badges' ? data.metric : undefined;
  const target = resource === 'badges' ? data.target : undefined;
  delete data.answer; delete data.metric; delete data.target;
  if (resource === 'vocabulary' && typeof data.term === 'string') {
    data.normalized_term = data.term.toLocaleLowerCase('en');
  }
  if (resource === 'vocabulary' && !id) data.language = 'en';
  if (id) noError(await client.from(tables[resource]).update(data).eq('id', id));
  else {
    id = crypto.randomUUID();
    noError(await client.from(tables[resource]).insert({ ...data, id }));
  }
  if (resource === 'quiz-questions' && answer !== undefined) {
    noError(await client.from('quiz_answer_keys').upsert({ question_id: id, answer }, { onConflict: 'question_id' }));
  }
  if (resource === 'badges' && (metric !== undefined || target !== undefined)) {
    const current = id ? checked(await client.from('badge_rules').select('metric,target').eq('badge_id', id).maybeSingle()) as { metric: string; target: number } | null : null;
    const nextMetric = metric ?? current?.metric; const nextTarget = target ?? current?.target;
    if (!nextMetric || !nextTarget) throw new Error('Badge rule needs metric and target.');
    noError(await client.from('badge_rules').upsert({ badge_id: id, metric: nextMetric, target: nextTarget }, { onConflict: 'badge_id' }));
  }
  return row(client, resource, id);
}

export async function supabaseAdminRequest<T>(client: SupabaseClient, path: string, init: RequestInit = {}): Promise<T> {
  const { data: session, error: sessionError } = await client.auth.getSession();
  if (sessionError || !session.session) throw new Error('Your session expired. Sign in again.');
  if (checked(await client.rpc('englify_is_admin')) !== true) throw new Error('Administrator access required.');
  const url = new URL(path, 'http://local-admin');
  const parts = url.pathname.split('/').filter(Boolean);
  const method = init.method?.toUpperCase() ?? 'GET';
  if (parts[0] === 'me' && method === 'GET') return { user_id: session.session.user.id, role: 'admin' } as T;
  if (parts[0] === 'schema' && method === 'GET') return schema as T;
  if (['overview', 'publishing', 'analytics'].includes(parts[0]) && method === 'GET') {
    return checked(await client.rpc('englify_admin_metrics', { p_view: parts[0] })) as T;
  }
  if (parts[0] === 'audit' && method === 'GET') {
    return checked(await client.from('admin_audit_logs').select('id,actor_id,action,resource,record_id,created_at')
      .order('created_at', { ascending: false }).order('id', { ascending: false }).limit(30)) as T;
  }
  if (parts[0] !== 'catalog' || !parts[1]) throw new Error('Unknown admin operation.');
  const resource = resourceOf(parts[1]);
  const table = tables[resource];
  if (method === 'GET' && !parts[2]) {
    const page = Number(url.searchParams.get('page') ?? '1');
    const pageSize = Number(url.searchParams.get('page_size') ?? '15');
    const query = (url.searchParams.get('q') ?? '').trim();
    if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 50 || query.length > 80) {
      throw new Error('Invalid search or page.');
    }
    let builder = client.from(table).select('*', { count: 'exact' });
    if (resource !== 'quiz-options') builder = builder.is('archived_at', null);
    const search = searchFields.find((field) => field in schema[resource]);
    if (query && search) builder = builder.ilike(search, `%${query.replaceAll('%', '\\%').replaceAll('_', '\\_')}%`);
    const order = resource === 'quiz-options' || resource === 'lesson-items' ? 'id' : 'created_at';
    const result = await builder.order(order, { ascending: false }).range((page - 1) * pageSize, page * pageSize - 1);
    return { items: checked(result), total: result.count ?? 0, page, page_size: pageSize } as T;
  }
  if (method === 'GET' && parts[2] && !parts[3]) return await row(client, resource, parts[2]) as T;
  if (method === 'POST' && !parts[2]) {
    const payload = JSON.parse(String(init.body ?? '{}')) as { data?: Record<string, unknown> };
    return await write(client, resource, null, payload.data ?? {}) as T;
  }
  if (method === 'PATCH' && parts[2] && !parts[3]) {
    const payload = JSON.parse(String(init.body ?? '{}')) as { data?: Record<string, unknown> };
    return await write(client, resource, parts[2], payload.data ?? {}) as T;
  }
  if (method === 'POST' && parts[2] && parts[3] === 'publish' && resource !== 'quiz-options') {
    const published = url.searchParams.get('published') !== 'false';
    noError(await client.from(table).update({ is_published: published }).eq('id', parts[2]));
    return await row(client, resource, parts[2]) as T;
  }
  if (method === 'DELETE' && parts[2] && resource !== 'quiz-options') {
    noError(await client.from(table).update({ is_published: false, archived_at: new Date().toISOString() }).eq('id', parts[2]));
    return { archived: true } as T;
  }
  throw new Error('Unsupported admin operation.');
}
