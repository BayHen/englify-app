import type { SupabaseClient } from '@supabase/supabase-js';

type Row = Record<string, unknown> & { id: string };
type Resource = keyof typeof schema;
const schema = {
  vocabulary: { term: 'text', definition: 'text', translation: 'text', ipa: 'optional', part_of_speech: 'optional', example: 'optional', audio_url: 'optional', source_name: 'text', license_id: 'text' },
  courses: { slug: 'slug', title: 'text', description: 'optional', level: 'positive', cefr_level: 'cefr_level' },
  chapters: { course_id: 'uuid', slug: 'slug', title: 'text', description: 'optional', position: 'positive' },
  units: { course_id: 'uuid', chapter_id: 'uuid', slug: 'slug', title: 'text', position: 'positive', is_required: 'boolean' },
  lessons: { course_id: 'uuid', unit_id: 'uuid', slug: 'slug', title: 'text', objective: 'text', position: 'positive', xp_reward: 'xp', content: 'object', is_required: 'boolean', estimated_minutes: 'positive', lesson_kind: 'lesson_kind' },
  'lesson-items': { lesson_id: 'uuid', position: 'positive', kind: 'item_kind', body: 'object' },
  'quiz-questions': { lesson_id: 'uuid', position: 'positive', kind: 'question_kind', prompt: 'text', explanation: 'optional', payload: 'object', answer: 'json' },
  'quiz-options': { question_id: 'uuid', position: 'positive', answer_text: 'text', is_correct: 'boolean' },
  'real-english': { slug: 'slug', kind: 'expression_kind', expression: 'text', meaning_vi: 'text', context_explanation: 'text', example_en: 'text', example_vi: 'text', dialogue: 'array', formality: 'formality', region_note: 'text', source_name: 'text', license_id: 'text', provenance_note: 'text' },
  'writing-topics': { slug: 'slug', title: 'text', description: 'text', icon: 'optional', sort_order: 'positive', is_published: 'boolean' },
  'writing-exercises': { slug: 'slug', topic_id: 'uuid', cefr_level: 'cefr_level', kind: 'writing_kind', title: 'text', prompt: 'text', instructions: 'optional', hint: 'optional', min_words: 'positive', recommended_words: 'positive', estimated_minutes: 'positive', difficulty: 'positive', tokens: 'array', accepted_answers: 'array', is_published: 'boolean' },
  badges: { code: 'slug', title: 'text', description: 'optional', metric: 'badge_metric', target: 'positive' },
} as const;
const tables: Record<Resource, string> = {
  vocabulary: 'dictionary_entries', courses: 'courses', chapters: 'journey_chapters', units: 'learning_units', lessons: 'lessons',
  'lesson-items': 'lesson_items', 'quiz-questions': 'quiz_questions', 'quiz-options': 'quiz_options',
  'real-english': 'real_english_expressions', badges: 'badges',
  'writing-topics': 'writing_topics', 'writing-exercises': 'writing_exercises',
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
  if (resource === 'writing-exercises') {
    const answer = checked(await client.from('writing_answer_keys').select('accepted_answers').eq('exercise_id', id).maybeSingle()) as { accepted_answers: unknown } | null;
    item.accepted_answers = answer?.accepted_answers ?? [];
  }
  return item;
}
async function write(
  client: SupabaseClient,
  resource: Resource,
  id: string | null,
  raw: Record<string, unknown>,
  requestId?: string,
): Promise<Row> {
  const data = { ...raw };
  if (!Object.keys(data).length || Object.keys(data).some((key) => !(key in schema[resource]))) {
    throw new Error('Unknown or empty content fields.');
  }
  if (process.env.NEXT_PUBLIC_ADMIN_ATOMIC_CRUD_ENABLED === 'true' && (resource === 'quiz-questions' || resource === 'badges')) {
    if (!requestId || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(requestId)) {
      throw new Error('A valid mutation request ID is required.');
    }
    const recordId = id ?? crypto.randomUUID();
    const functionName = resource === 'quiz-questions'
      ? 'englify_admin_upsert_quiz_question'
      : 'englify_admin_upsert_badge';
    const idName = resource === 'quiz-questions' ? 'p_question_id' : 'p_badge_id';
    return checked(await client.rpc(functionName, {
      p_request_id: requestId,
      [idName]: recordId,
      p_data: data,
    })) as Row;
  }
  const answer = resource === 'quiz-questions' ? data.answer : undefined;
  const metric = resource === 'badges' ? data.metric : undefined;
  const target = resource === 'badges' ? data.target : undefined;
  const acceptedAnswers = resource === 'writing-exercises' ? data.accepted_answers : undefined;
  delete data.answer; delete data.metric; delete data.target; delete data.accepted_answers;
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
  if (resource === 'writing-exercises' && acceptedAnswers !== undefined) {
    if (!Array.isArray(acceptedAnswers)) throw new Error('Accepted answers must be an array.');
    noError(await client.from('writing_answer_keys').upsert({ exercise_id: id, accepted_answers: acceptedAnswers }, { onConflict: 'exercise_id' }));
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
  if (parts[0] === 'arena' && parts[1] === 'overview' && method === 'GET') {
    return checked(await client.rpc('englify_admin_arena_overview')) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'seasons' && method === 'POST' && !parts[2]) {
    const payload = JSON.parse(String(init.body ?? '{}')) as { code?:string;title?:string;ruleset_version?:number;starts_at?:string;ends_at?:string };
    return checked(await client.rpc('englify_admin_upsert_arena_season',{p_id:null,p_code:payload.code,p_title:payload.title,p_ruleset:payload.ruleset_version,p_starts_at:payload.starts_at,p_ends_at:payload.ends_at})) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'seasons' && parts[2] && parts[3] === 'transition' && method === 'POST') {
    const payload = JSON.parse(String(init.body ?? '{}')) as { status?:string };
    return checked(await client.rpc('englify_admin_transition_arena_season',{p_id:parts[2],p_status:payload.status})) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'rulesets' && method === 'POST') {
    const p = JSON.parse(String(init.body ?? '{}')) as Record<string, unknown>;
    return checked(await client.rpc('englify_admin_upsert_ranked_ruleset',{
      p_version:p.version,p_name:p.name,p_question_count:p.question_count,p_time_limit_seconds:p.time_limit_seconds,
      p_initial_lives:p.initial_lives,p_base_points:p.base_points,p_initial_rating:p.initial_rating,
      p_max_rating_change:p.max_rating_change,p_reference_score:p.reference_score,p_cefr_level:p.cefr_level,p_enabled:p.enabled,
    })) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'rewards' && method === 'POST') {
    const p = JSON.parse(String(init.body ?? '{}')) as Record<string, unknown>;
    return checked(await client.rpc('englify_admin_set_season_reward',{p_season_id:p.season_id,p_reward_code:p.reward_code,p_badge_id:p.badge_id,p_enabled:p.enabled})) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'questions' && parts[2] === 'overview' && method === 'GET') {
    return checked(await client.rpc('englify_admin_question_management_overview')) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'questions' && method === 'GET' && !parts[2]) {
    return checked(await client.rpc('englify_admin_question_list', {
      p_page: Number(url.searchParams.get('page') ?? '1'), p_page_size: Number(url.searchParams.get('page_size') ?? '20'),
      p_search: url.searchParams.get('q') || null, p_cefr: url.searchParams.get('cefr') || null,
      p_topic: url.searchParams.get('topic') || null, p_kind: url.searchParams.get('kind') || null,
      p_status: url.searchParams.get('status') || null,
      p_difficulty: url.searchParams.get('difficulty') ? Number(url.searchParams.get('difficulty')) : null,
    })) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'questions' && parts[2] && method === 'GET' && !parts[3]) {
    return checked(await client.rpc('englify_admin_question_detail', { p_id: parts[2] })) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'questions' && method === 'POST' && !parts[2]) {
    const p=JSON.parse(String(init.body??'{}')) as {request_id?:string;id?:string|null;data?:Record<string,unknown>;change_note?:string};
    return checked(await client.rpc('englify_admin_save_arena_question',{p_request_id:p.request_id,p_id:p.id??null,p_data:p.data,p_change_note:p.change_note??''})) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'questions' && parts[2] && parts[3] === 'transition' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {status?:string;note?:string};
    return checked(await client.rpc('englify_admin_transition_arena_question',{p_id:parts[2],p_status:p.status,p_note:p.note??''})) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'questions' && parts[2] && parts[3] === 'duplicate' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {request_id?:string};
    return checked(await client.rpc('englify_admin_duplicate_arena_question',{p_id:parts[2],p_request_id:p.request_id})) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'questions' && parts[2] && parts[3] === 'analytics' && method === 'GET') {
    return checked(await client.rpc('englify_admin_question_analytics',{p_question:parts[2]})) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'imports' && parts[2] === 'stage' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {request_id?:string;filename?:string;format?:string;rows?:unknown[]};
    return checked(await client.rpc('englify_admin_stage_arena_import',{p_request_id:p.request_id,p_filename:p.filename,p_format:p.format,p_rows:p.rows})) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'imports' && parts[2] && parts[3] === 'commit' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {request_id?:string;row_ids?:string[]};
    return checked(await client.rpc('englify_admin_commit_arena_import',{p_batch:parts[2],p_row_ids:p.row_ids??[],p_request_id:p.request_id})) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'reports' && parts[2] && parts[3] === 'resolve' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {status?:string;note?:string};
    return checked(await client.rpc('englify_admin_resolve_question_report',{p_id:parts[2],p_status:p.status,p_note:p.note??''})) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'generate' && method === 'POST') {
    return checked(await client.functions.invoke('arena-question-generate',{body:JSON.parse(String(init.body??'{}'))})) as T;
  }
  if (parts[0] === 'arena' && parts[1] === 'topics' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {slug?:string;title?:string;description?:string;sort_order?:number;status?:string};
    return checked(await client.rpc('englify_admin_upsert_arena_topic',{p_slug:p.slug,p_title:p.title,p_description:p.description??'',p_sort_order:p.sort_order??0,p_status:p.status??'published'})) as T;
  }
  if (parts[0] === 'journey' && parts[1] === 'overview' && method === 'GET') {
    return checked(await client.rpc('englify_admin_journey_overview')) as T;
  }
  if (parts[0] === 'journey' && parts[1] === 'quality' && method === 'GET') {
    return checked(await client.rpc('englify_admin_journey_curriculum_quality')) as T;
  }
  if (parts[0] === 'journey' && parts[1] === 'lessons' && method === 'POST' && !parts[2]) {
    const p=JSON.parse(String(init.body??'{}')) as {request_id?:string;id?:string|null;data?:Record<string,unknown>};
    return checked(await client.rpc('englify_admin_save_journey_lesson',{p_request_id:p.request_id,p_id:p.id??null,p_data:p.data})) as T;
  }
  if (parts[0] === 'journey' && parts[1] === 'lessons' && parts[2] && parts[3] === 'transition' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {status?:string;reason?:string};
    return checked(await client.rpc('englify_admin_transition_journey_lesson',{p_id:parts[2],p_status:p.status,p_reason:p.reason??''})) as T;
  }
  if (parts[0] === 'journey' && parts[1] === 'nodes' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {kind?:string;id?:string|null;data?:Record<string,unknown>}; return checked(await client.rpc('englify_admin_save_journey_node',{p_kind:p.kind,p_id:p.id??null,p_data:p.data})) as T;
  }
  if (parts[0] === 'journey' && parts[1] === 'prerequisites' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {lesson_id?:string;required?:string[]}; return checked(await client.rpc('englify_admin_set_journey_prerequisites',{p_lesson:p.lesson_id,p_required:p.required??[]})) as T;
  }
  if (parts[0] === 'journey' && parts[1] === 'checkpoints' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {lesson_id?:string;unit_id?:string;objectives?:unknown[];passing_percent?:number}; return checked(await client.rpc('englify_admin_save_journey_checkpoint',{p_lesson:p.lesson_id,p_unit:p.unit_id,p_objectives:p.objectives??[],p_passing:p.passing_percent??70})) as T;
  }
  if (parts[0] === 'journey' && parts[1] === 'reorder' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {kind?:string;parent_id?:string;ids?:string[]}; return checked(await client.rpc('englify_admin_reorder_journey',{p_kind:p.kind,p_parent:p.parent_id,p_ids:p.ids??[]})) as T;
  }
  if (parts[0] === 'journey' && parts[1] === 'imports' && parts[2] === 'stage' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {request_id?:string;filename?:string;format?:string;rows?:unknown[]}; return checked(await client.rpc('englify_admin_stage_journey_import',{p_request_id:p.request_id,p_filename:p.filename,p_format:p.format,p_rows:p.rows})) as T;
  }
  if (parts[0] === 'journey' && parts[1] === 'imports' && parts[2] && parts[3] === 'commit' && method === 'POST') {
    const p=JSON.parse(String(init.body??'{}')) as {request_id?:string}; return checked(await client.rpc('englify_admin_commit_journey_import',{p_batch:parts[2],p_request_id:p.request_id})) as T;
  }
  if (parts[0] === 'journey' && parts[1] === 'analytics' && method === 'GET') return checked(await client.rpc('englify_admin_journey_analytics')) as T;
  if (parts[0] === 'journey' && parts[1] === 'generate' && method === 'POST') return checked(await client.functions.invoke('journey-lesson-generate',{body:JSON.parse(String(init.body??'{}'))})) as T;
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
    const payload = JSON.parse(String(init.body ?? '{}')) as { data?: Record<string, unknown>; request_id?: string };
    return await write(client, resource, null, payload.data ?? {}, payload.request_id) as T;
  }
  if (method === 'PATCH' && parts[2] && !parts[3]) {
    const payload = JSON.parse(String(init.body ?? '{}')) as { data?: Record<string, unknown>; request_id?: string };
    return await write(client, resource, parts[2], payload.data ?? {}, payload.request_id) as T;
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
