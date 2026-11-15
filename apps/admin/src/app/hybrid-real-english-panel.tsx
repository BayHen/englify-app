'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { getSupabase } from '@/lib/client';
import { normalizeLessonRelations } from './real-english-relations';
import styles from './hybrid-real-english.module.css';

type Phrase = { id: string; english_text: string; vietnamese_translation: string; mymemory_candidate_vi: string | null; formality: string; usage_context: string; is_active: boolean };
type PhraseEdit = { key: string; id?: string; englishText: string; vietnameseTranslation: string; formality: string; usageContext: string; isActive: boolean };
type Source = { id: string; english_text: string; vietnamese_text: string; english_contributor: string | null;
  vietnamese_contributor: string | null; english_license: string | null; vietnamese_license: string | null;
  source_url: string; translation_url: string; attribution_text: string; validation_status: string };
type Lesson = { id: string; title: string; description: string; difficulty: string; status: string;
  generation_source: string; created_at: string; rejection_reason: string | null;
  real_english_topics: { title: string; slug: string }[] | { title: string; slug: string } | null;
  real_english_phrases: Phrase[]; real_english_source_references: Source[];
  real_english_dialogues: { id: string; title: string; real_english_dialogue_lines: { id: string; speaker: string; english_text: string; vietnamese_translation: string; sort_order: number }[] }[] };
type Topic = { id: string; slug: string; title: string; difficulty: string; is_active: boolean; search_keyword: string };
type Settings = { id: boolean; ai_generation_enabled: boolean; source_import_enabled: boolean;
  daily_generation_target: number; maximum_daily_requests: number; maximum_output_tokens: number;
  enabled_topics: string[]; enabled_difficulty_levels: string[] };
function ictDay() {
  const parts = new Intl.DateTimeFormat('en-US',{ timeZone:'Asia/Ho_Chi_Minh',year:'numeric',month:'2-digit',day:'2-digit' }).formatToParts(new Date());
  const part = (type: string) => parts.find((item) => item.type === type)?.value ?? '';
  return `${part('year')}-${part('month')}-${part('day')}`;
}

export function HybridRealEnglishSetup() {
  type Check = { name: string; result: string; ready: boolean };
  const [checks, setChecks] = useState<Check[]>([]);
  const [checking, setChecking] = useState(false);
  const [revision, setRevision] = useState(0);

  useEffect(() => {
    let active = true;
    async function inspect() {
      setChecking(true);
      const next: Check[] = [];
      try {
        const supabase = getSupabase();
        const { data: auth, error: sessionError } = await supabase.auth.getSession();
        if (sessionError || !auth.session) {
          next.push({ name: 'Supabase session', result: 'Sign in again to check access.', ready: false });
        } else {
          next.push({ name: 'Supabase session', result: 'Active', ready: true });
          const [table, admin] = await Promise.all([
            supabase.from('real_english_lessons').select('id').limit(1),
            supabase.rpc('englify_is_admin'),
          ]);
          const tableAvailable = !table.error && table.status === 200;
          next.push({ name: 'V2 lesson table', result: !tableAvailable
            ? table.error?.code === 'PGRST205' || table.status === 404 ? 'Missing from this Supabase project.' : `Unavailable (HTTP ${table.status || 'network'}; ${table.error?.code || 'unknown'}).`
            : 'Available', ready: tableAvailable });
          next.push({ name: 'Supabase admin policy', result: admin.error
            ? `Could not verify (HTTP ${admin.status || 'network'}; ${admin.error.code || 'unknown'}).`
            : admin.data === true ? 'Admin access confirmed' : 'This account has no database admin access.',
          ready: !admin.error && admin.data === true });
          try {
            const response = await fetch('/api/hybrid-function-status', { cache: 'no-store',
              signal: AbortSignal.timeout(8000),
              headers: { Authorization: `Bearer ${auth.session.access_token}` } });
            const result = await response.json() as { status: string; httpStatus?: number; reason?: string };
            next.push({ name: 'Generation function', result: result.status === 'deployed'
              ? 'Deployed (read-only GET returned 405).' : result.status === 'missing'
                ? 'Not deployed to this Supabase project.' : result.reason ?? `Could not verify (HTTP ${result.httpStatus ?? response.status}).`,
            ready: result.status === 'deployed' });
          } catch {
            next.push({ name: 'Generation function', result: 'Diagnostic request failed or timed out.', ready: false });
          }
        }
      } catch {
        next.push({ name: 'Supabase configuration', result: 'Public URL or publishable key is missing or invalid.', ready: false });
      }
      if (active) { setChecks(next); setChecking(false); }
    }
    void inspect();
    return () => { active = false; };
  }, [revision]);

  return <section className="panel" role="status">
    <h2>AI lesson review setup</h2>
    <p>The new lesson workflow is visible. These read-only checks show what is ready in the connected Supabase project.</p>
    <ul>{checks.map((check) => <li key={check.name}><strong>{check.name}:</strong> {check.ready ? 'Ready — ' : 'Needs attention — '}{check.result}</li>)}</ul>
    <button className="secondary" type="button" disabled={checking} onClick={() => setRevision((value) => value + 1)}>{checking ? 'Checking…' : 'Check again'}</button>
    <p>Apply and verify the Real English migration and admin RLS, deploy the generation function, then set <code>NEXT_PUBLIC_REAL_ENGLISH_HYBRID_ENABLED=true</code> in <code>apps/admin/.env.local</code> and restart Admin.</p>
    <p>See <code>docs/REAL_ENGLISH_HYBRID_V2.md</code>. Draft generation and publishing remain unavailable until setup is complete.</p>
  </section>;
}

export function HybridRealEnglishPanel() {
  const scheduleEnabled = process.env.NEXT_PUBLIC_REAL_ENGLISH_CRON_ENABLED === 'true';
  const [items, setItems] = useState<Lesson[]>([]);
  const [selected, setSelected] = useState<Lesson | null>(null);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [phraseEdits, setPhraseEdits] = useState<PhraseEdit[]>([]);
  const [note, setNote] = useState('');
  const [query, setQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('pending_review');
  const [difficultyFilter, setDifficultyFilter] = useState('all');
  const [sortOrder, setSortOrder] = useState<'newest' | 'oldest'>('newest');
  const [page, setPage] = useState(0);
  const [busy, setBusy] = useState(false);
  const generationInFlight = useRef(false);
  const reviewInFlight = useRef(false);
  const reviewEditor = useRef<HTMLDivElement>(null);
  const learnerPreview = useRef<HTMLDivElement>(null);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');
  const [topics, setTopics] = useState<Topic[]>([]);
  const [topicId, setTopicId] = useState('');
  const [keyword, setKeyword] = useState('');
  const [slot, setSlot] = useState(0);
  const [settings, setSettings] = useState<Settings | null>(null);
  const [counts, setCounts] = useState<{ today: number; pending: number; approved: number; published: number } | null>(null);
  const [latestJob, setLatestJob] = useState<{ status: string; error_message: string | null } | null>(null);
  const [latestSuccess, setLatestSuccess] = useState<string | null>(null);
  const [batch, setBatch] = useState<{ target_count: number; success_count: number; failure_count: number; pending_count: number; latest_error: string | null } | null>(null);
  const [history, setHistory] = useState<{ id: string; status: string; created_at: string; error_message: string | null; generated_count: number }[]>([]);
  const [preflightHistory, setPreflightHistory] = useState<{ idempotency_key: string; error_code: string; error_message: string; attempt_count: number; updated_at: string }[]>([]);
  const [modelStatus, setModelStatus] = useState('');
  const [newTopicTitle, setNewTopicTitle] = useState('');
  const [newTopicSlug, setNewTopicSlug] = useState('');
  const [newTopicKeyword, setNewTopicKeyword] = useState('');
  const [newTopicDifficulty, setNewTopicDifficulty] = useState('A1');
  const load = useCallback(async () => {
    setLoading(true);
    let request = getSupabase().from('real_english_lessons')
      .select('id,title,description,difficulty,status,generation_source,created_at,rejection_reason,real_english_topics(title,slug),real_english_phrases(id,english_text,vietnamese_translation,mymemory_candidate_vi,formality,usage_context,is_active),real_english_source_references(id,english_text,vietnamese_text,english_contributor,vietnamese_contributor,english_license,vietnamese_license,source_url,translation_url,attribution_text,validation_status),real_english_dialogues(id,title,real_english_dialogue_lines(id,speaker,english_text,vietnamese_translation,sort_order))')
      .order('created_at', { ascending: sortOrder === 'oldest' }).range(page * 15, page * 15 + 14);
    if (statusFilter !== 'all') request = request.eq('status', statusFilter);
    if (difficultyFilter !== 'all') request = request.eq('difficulty', difficultyFilter);
    if (query.trim()) request = request.ilike('title', `%${query.trim().replaceAll('%', '\%').replaceAll('_', '\_')}%`);
    const { data, error } = await request;
    if (error) { setMessage(error.message); setItems([]); }
    else {
      try { setItems((data ?? []).map((row) => normalizeLessonRelations(row)) as unknown as Lesson[]); }
      catch { setItems([]); setMessage('Lesson relations could not be read. Refresh or inspect the database response.'); }
    }
    const today = ictDay();
    const startOfDay = new Date(`${today}T00:00:00+07:00`);
    const nextDay = new Date(startOfDay.getTime() + 86_400_000);
    const [drafts, pending, approved, published, job, successfulJob, dailyBatch, jobs, sourceFailures] = await Promise.all([
      getSupabase().from('real_english_lessons').select('id', { count: 'exact', head: true }).gte('created_at', startOfDay.toISOString()).lt('created_at', nextDay.toISOString()),
      getSupabase().from('real_english_lessons').select('id', { count: 'exact', head: true }).eq('status', 'pending_review'),
      getSupabase().from('real_english_lessons').select('id', { count: 'exact', head: true }).eq('status', 'approved'),
      getSupabase().from('real_english_lessons').select('id', { count: 'exact', head: true }).eq('status', 'published'),
      getSupabase().from('real_english_generation_jobs').select('status,error_message').order('created_at', { ascending: false }).limit(1).maybeSingle(),
      getSupabase().from('real_english_generation_jobs').select('completed_at').eq('status','completed').order('completed_at',{ ascending:false }).limit(1).maybeSingle(),
      getSupabase().from('real_english_generation_batches').select('target_count,success_count,failure_count,pending_count,latest_error').eq('generation_date', today).maybeSingle(),
      getSupabase().from('real_english_generation_jobs').select('id,status,created_at,error_message,generated_count').order('created_at', { ascending: false }).limit(10),
      getSupabase().from('real_english_generation_preflights').select('idempotency_key,error_code,error_message,attempt_count,updated_at').order('updated_at', { ascending: false }).limit(10),
    ]);
    if (!drafts.error && !pending.error && !approved.error && !published.error) setCounts({ today: drafts.count ?? 0, pending: pending.count ?? 0, approved: approved.count ?? 0, published: published.count ?? 0 });
    if (!job.error) setLatestJob(job.data);
    if (!successfulJob.error) setLatestSuccess(successfulJob.data?.completed_at ?? null);
    if (!dailyBatch.error) setBatch(dailyBatch.data);
    if (!jobs.error) setHistory(jobs.data ?? []);
    if (!sourceFailures.error) setPreflightHistory(sourceFailures.data ?? []);
    setLoading(false);
  }, [page, query, statusFilter, difficultyFilter, sortOrder]);
  useEffect(() => { queueMicrotask(() => { void load(); }); }, [load]);
  useEffect(() => { queueMicrotask(() => {
    void getSupabase().from('real_english_topics').select('id,slug,title,difficulty,is_active,search_keyword').order('title')
      .then(({ data, error }) => { if (error) setMessage(error.message); else setTopics((data ?? []) as Topic[]); });
    void getSupabase().from('real_english_generation_settings').select('*').eq('id', true).single()
      .then(({ data, error }) => { if (error) setMessage(error.message); else setSettings(data as Settings); });
  }); }, []);
  useEffect(() => {
    if (topicId || !settings) return;
    const first = topics.find((topic) => topic.is_active && settings.enabled_topics.includes(topic.slug));
    if (first) queueMicrotask(() => { setTopicId(first.id); setKeyword(first.search_keyword); });
  }, [topics, settings, topicId]);
  function choose(item: Lesson) {
    setSelected(item); setTitle(item.title); setDescription(item.description); setNote(item.rejection_reason ?? '');
    setPhraseEdits(item.real_english_phrases.map((phrase) => ({ key: phrase.id, id: phrase.id,
      englishText: phrase.english_text, vietnameseTranslation: phrase.vietnamese_translation,
      formality: phrase.formality, usageContext: phrase.usage_context, isActive: phrase.is_active })));
    requestAnimationFrame(() => reviewEditor.current?.scrollIntoView({ block: 'start' }));
  }
  function changePhrase(key: string, update: Partial<PhraseEdit>) {
    setPhraseEdits((old) => old.map((phrase) => phrase.key === key ? { ...phrase, ...update } : phrase));
  }
  async function save() {
    if (!selected || busy || !title.trim() || !description.trim() || ['published','archived'].includes(selected.status)) return;
    setBusy(true);
    const { error } = await getSupabase().rpc('englify_save_real_english_lesson', {
      p_lesson_id: selected.id, p_title: title.trim(), p_description: description.trim(),
      p_phrases: phraseEdits.map(({ id, englishText, vietnameseTranslation, formality, usageContext, isActive }) =>
        ({ id, englishText, vietnameseTranslation, formality, usageContext, isActive })),
    });
    setMessage(error?.message ?? 'Changes saved. Review the content before approving.');
    if (!error) setSelected(null);
    await load(); setBusy(false);
  }
  async function review(action: 'submit' | 'approve' | 'approve_publish' | 'publish' | 'request_revision' | 'reject' | 'archive' | 'restore') {
    if (!selected || busy || reviewInFlight.current) return;
    if (['reject', 'request_revision'].includes(action) && !note.trim()) { setMessage('Enter a review note.'); return; }
    if (['archive','reject','approve_publish','publish'].includes(action)
      && !window.confirm(`Confirm ${action.replaceAll('_',' ')} for “${selected.title}”?`)) return;
    reviewInFlight.current = true; setBusy(true);
    try {
      const { error } = await getSupabase().rpc('englify_review_real_english_lesson', {
        p_lesson_id: selected.id, p_action: action, p_note: note.trim(),
      });
      setMessage(error?.message ?? `Lesson action completed: ${action.replaceAll('_', ' ')}.`);
      if (!error) setSelected(null);
      await load();
    } finally { reviewInFlight.current = false; setBusy(false); }
  }
  async function generate() {
    const topic = topics.find((item) => item.id === topicId);
    if (!topic || !keyword.trim() || keyword.length > 80) { setMessage('Choose a topic and keyword (up to 80 characters).'); return; }
    await generateFor(topic, keyword.trim(), slot);
  }
  async function generateFor(topic: Topic, searchKeyword: string, dailySlot: number) {
    if (generationInFlight.current || busy) return;
    generationInFlight.current = true;
    setBusy(true); setMessage('');
    try {
      const { data: auth, error: sessionError } = await getSupabase().auth.getSession();
      if (sessionError || !auth.session) { setMessage('Your session expired. Sign in again.'); return; }
      const response = await fetch('/api/hybrid-generate', { method: 'POST', cache: 'no-store',
        signal: AbortSignal.timeout(80000),
        headers: { Authorization: `Bearer ${auth.session.access_token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ topicId: topic.id, keyword: searchKeyword, difficulty: topic.difficulty, slot: dailySlot }),
      });
      const result = await response.json() as { status?: string; lessonId?: string; error?: string };
      if (response.ok && ['in_review','pending_review'].includes(result.status ?? '') && result.lessonId) {
        if (query || page !== 0 || statusFilter !== 'pending_review' || difficultyFilter !== 'all') { setQuery(''); setPage(0); setStatusFilter('pending_review'); setDifficultyFilter('all'); }
        else await load();
        setMessage('Draft created and added to the review queue. Review it before publishing.');
      } else setMessage(result.error ?? `No review draft was created (HTTP ${response.status}).`);
    } catch { setMessage('Generation service is unavailable or timed out.'); }
    finally { generationInFlight.current = false; setBusy(false); }
  }
  async function generateMissing(retryFailed: boolean) {
    if (!settings || busy || generationInFlight.current) return;
    if (batch && batch.success_count >= settings.daily_generation_target) { setMessage('The daily target is already complete.'); return; }
    const day = ictDay();
    const [year,month,date] = day.split('-').map(Number);
    const dayOfYear = Math.floor((Date.UTC(year,month-1,date)-Date.UTC(year,0,0))/86_400_000);
    const eligible = topics.filter((topic) => topic.is_active && settings.enabled_topics.includes(topic.slug)
      && settings.enabled_difficulty_levels.includes(topic.difficulty)).sort((a,b) => a.slug.localeCompare(b.slug));
    const rotated = eligible.map((topic,index) => ({ topic, order: (index+dayOfYear)%eligible.length }))
      .sort((a,b) => a.order-b.order).slice(0,settings.maximum_daily_requests);
    const [jobs, preflights] = await Promise.all([
      getSupabase().from('real_english_generation_jobs')
        .select('idempotency_key,status,attempt_count,completed_at').like('idempotency_key',`real-english:${day}:%`).limit(50),
      getSupabase().from('real_english_generation_preflights')
        .select('idempotency_key,attempt_count,next_retry_at').eq('generation_date',day).limit(50),
    ]);
    if (jobs.error || preflights.error) { setMessage(jobs.error?.message ?? preflights.error?.message ?? 'Generation history unavailable.'); return; }
    const candidate = rotated.map(({ topic },dailySlot) => ({ topic,dailySlot,
      job: jobs.data?.find((job) => job.idempotency_key === `real-english:${day}:${topic.id}:${dailySlot}`),
      preflight: preflights.data?.find((item) => item.idempotency_key === `real-english:${day}:${topic.id}:${dailySlot}`) }))
      .find(({ job,preflight }) => retryFailed
        ? job?.status === 'failed' && job.attempt_count < 3 && !!job.completed_at
          && Date.now()-new Date(job.completed_at).getTime() >= 5*2**job.attempt_count*60_000
        : !job && (!preflight || (preflight.attempt_count < 3 && new Date(preflight.next_retry_at).getTime() <= Date.now())));
    if (!candidate) { setMessage(retryFailed ? 'No failed slot is ready to retry.' : 'No unattempted slot remains today; check quota and generation history.'); return; }
    await generateFor(candidate.topic,candidate.topic.search_keyword,candidate.dailySlot);
  }
  async function checkModel() {
    if (busy) return;
    setBusy(true); setModelStatus('Checking the configured Gemini model…');
    try {
      const { data } = await getSupabase().auth.getSession();
      if (!data.session) throw Error('Sign in again.');
      const response = await fetch('/api/hybrid-generate', { method: 'POST', cache: 'no-store',
        signal: AbortSignal.timeout(15000), headers: { Authorization: `Bearer ${data.session.access_token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'check_model' }) });
      const result = await response.json() as { configured?: string; models?: { model: string; available: boolean; reason?: string }[]; error?: string };
      setModelStatus(response.ok && result.models ? result.models.map((model) =>
        `${model.model}${model.model === result.configured ? ' (configured)' : ''}: ${model.available ? 'available' : model.reason ?? 'unavailable'}`).join(' · ')
        : result.error ?? `Model check failed (HTTP ${response.status}).`);
    } catch { setModelStatus('Could not reach the model diagnostic.'); }
    finally { setBusy(false); }
  }
  async function saveSettings() {
    if (!settings || busy) return;
    setBusy(true);
    const { error } = await getSupabase().from('real_english_generation_settings').update({
      ai_generation_enabled: settings.ai_generation_enabled,
      source_import_enabled: settings.source_import_enabled,
      daily_generation_target: settings.daily_generation_target,
      maximum_daily_requests: settings.maximum_daily_requests,
      maximum_output_tokens: settings.maximum_output_tokens,
      enabled_topics: settings.enabled_topics,
      enabled_difficulty_levels: settings.enabled_difficulty_levels,
      updated_at: new Date().toISOString(),
    }).eq('id', true).select('id').single();
    setMessage(error?.message ?? 'Settings saved. Edge secret guards still apply.');
    setBusy(false);
  }
  async function addTopic() {
    if (busy || !newTopicTitle.trim() || !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(newTopicSlug)
      || !newTopicKeyword.trim() || newTopicKeyword.length > 80) { setMessage('Enter a title, URL-safe slug and short search keyword.'); return; }
    setBusy(true);
    const { data, error } = await getSupabase().from('real_english_topics').insert({ title: newTopicTitle.trim(),
      slug: newTopicSlug, search_keyword: newTopicKeyword.trim(), difficulty: newTopicDifficulty,
      description: '', is_active: true }).select('id,slug,title,difficulty,is_active,search_keyword').single();
    if (error) setMessage(error.message);
    else { setTopics((old) => [...old, data as Topic].sort((a, b) => a.title.localeCompare(b.title)));
      setNewTopicTitle(''); setNewTopicSlug(''); setNewTopicKeyword(''); setMessage('Topic added. Enable it in generation settings before requesting drafts.'); }
    setBusy(false);
  }
  return <section className={styles.studio}>
    <header className={styles.header}><div><p className={styles.eyebrow}>✧ ENGLIFY CONTENT STUDIO</p><h2>Real English Studio</h2><p>Generate original lessons, inspect sources, then approve them for learners.</p></div><span className={styles.headerTag}>Human reviewed</span></header>
    <div className={styles.stats} aria-label="Live lesson counts">
      <div><strong>{batch?.success_count ?? counts?.today ?? '—'} / {batch?.target_count ?? settings?.daily_generation_target ?? 5}</strong><span>Generated today / daily target</span></div><div><strong>{batch ? Math.max(0,batch.target_count-batch.success_count) : '—'}</strong><span>Still needed today</span></div><div><strong>{counts?.pending ?? '—'}</strong><span>Pending review</span></div><div><strong>{counts?.approved ?? '—'}</strong><span>Approved</span></div><div><strong>{counts?.published ?? '—'}</strong><span>Published</span></div><div><strong>{batch?.failure_count ?? '—'}</strong><span>Failed jobs</span></div>
    </div>
    <div className={styles.queue}>
      <div className={styles.sectionHead}><div><h3>Review queue</h3><p>AI drafts stay private until an administrator publishes them.</p></div><span>{counts?.pending ?? '—'} pending</span></div>
      {message ? <div role="status" className={styles.notice}>{message}</div> : null}
      <div className={styles.searchRow}><input aria-label="Search lesson title" placeholder="Search lesson titles" value={query} onChange={(event) => { setQuery(event.target.value); setPage(0); }} /><select aria-label="Filter lesson status" value={statusFilter} onChange={(event) => { setStatusFilter(event.target.value); setPage(0); }}><option value="all">All statuses</option>{['pending_review','approved','published','needs_revision','rejected','archived','draft','publish_failed'].map((status) => <option key={status} value={status}>{status.replaceAll('_',' ')}</option>)}</select><select aria-label="Filter CEFR level" value={difficultyFilter} onChange={(event) => { setDifficultyFilter(event.target.value); setPage(0); }}><option value="all">All levels</option>{['A1','A2','B1','B2','C1','C2'].map((level) => <option key={level}>{level}</option>)}</select><select aria-label="Sort lessons" value={sortOrder} onChange={(event) => { setSortOrder(event.target.value as 'newest' | 'oldest'); setPage(0); }}><option value="newest">Newest first</option><option value="oldest">Oldest first</option></select><button type="button" onClick={() => void load()} disabled={loading}>Refresh queue</button></div>
      {loading ? <div className={styles.skeletonList} role="status" aria-label="Loading lessons"><div /><div /><div /></div> : items.length === 0 ?
        <div className={styles.empty}><strong>No lessons in this view</strong><p>{query ? 'Try another search.' : latestJob?.error_message ? `Last generation failed: ${latestJob.error_message}` : 'Check Archived to restore a previous lesson, or generate a new review draft below.'}</p></div> :
        <div className={styles.cards}>{items.map((item) => <article className={styles.lesson} key={item.id}>
          <div className={styles.lessonMeta}><span className={styles.badge}>{item.status.replaceAll('_', ' ')}</span><span>{item.difficulty} · {(Array.isArray(item.real_english_topics) ? item.real_english_topics[0]?.title : item.real_english_topics?.title) || 'General'} · {new Date(item.created_at).toLocaleDateString()}</span></div>
          <small>{item.generation_source === 'hybrid_ai' ? 'Gemini original lesson · Tatoeba attributed source' : 'Editorial lesson'} · {item.real_english_source_references.length} source(s)</small>
           <h4>{item.title}</h4><p>{item.description}</p><button type="button" onClick={() => choose(item)}>{item.status === 'archived' ? 'Inspect or restore →' : 'Review lesson →'}</button>
        </article>)}</div>}
      <div className={styles.pager}><button type="button" disabled={page === 0 || busy} onClick={() => setPage(page - 1)}>Previous</button><span>Page {page + 1}</span><button type="button" disabled={items.length < 15 || busy} onClick={() => setPage(page + 1)}>Next</button></div>
    </div>
     <div className={styles.automation}><div className={styles.sectionHead}><div><h3>Automation</h3><p>Target {settings?.daily_generation_target ?? '—'} reviewable lessons per day. Actual output depends on Free tier quota and valid sources; every lesson needs human review.</p></div><span className={scheduleEnabled ? styles.active : styles.paused}>{scheduleEnabled ? 'Daily at 07:00 ICT' : 'Schedule not active'}</span></div>
      <div className={styles.automationGrid}><div><strong>AI model</strong><p>{modelStatus || 'Availability has not been checked for this key.'}</p><button type="button" disabled={busy} onClick={() => void checkModel()}>Check AI model</button></div><div><strong>Latest generation</strong><p>{latestJob ? `${latestJob.status}${latestJob.error_message ? ` · ${latestJob.error_message}` : ''}` : 'No generation job yet.'}</p><p>Last successful lesson: {latestSuccess ? new Date(latestSuccess).toLocaleString() : 'none recorded'}</p><p>{batch?.latest_error ? `Daily shortfall reason: ${batch.latest_error}` : batch && batch.success_count < batch.target_count ? 'The daily target has not yet been reached.' : ''}</p></div></div>
      <div className={styles.batchActions}><button type="button" disabled={busy || !settings || (batch ? batch.success_count >= batch.target_count : false)} onClick={() => void generateMissing(false)}>Generate next missing lesson</button><button type="button" disabled={busy || !settings} onClick={() => void generateMissing(true)}>Retry failed generation</button><small>One request per click. Server quota and admin authorization still apply.</small></div>
      <details className={styles.history}><summary>View generation history</summary>{history.length || preflightHistory.length ? <ul>{history.map((job) => <li key={job.id}>{new Date(job.created_at).toLocaleString()} · {job.status} · {job.generated_count} stored{job.error_message ? ` · ${job.error_message}` : ''}</li>)}{preflightHistory.map((event) => <li key={event.idempotency_key}>{new Date(event.updated_at).toLocaleString()} · source {event.error_code} · attempt {event.attempt_count}/3 · {event.error_message}</li>)}</ul> : <p>No generation attempts found.</p>}</details>
    </div>
    <div className={styles.generator}><div className={styles.sectionHead}><div><h3>Generate a review draft</h3><p>Select a topic and source keyword. The result is never published automatically.</p></div></div>
      <div className={styles.formGrid}><label>Topic<select value={topicId} onChange={(event) => { const value = event.target.value; setTopicId(value); setKeyword(topics.find((topic) => topic.id === value)?.search_keyword ?? ''); }}><option value="">Choose topic</option>{topics.filter((topic) => topic.is_active && settings?.enabled_topics.includes(topic.slug)).map((topic) => <option key={topic.id} value={topic.id}>{topic.title} ({topic.difficulty})</option>)}</select></label>
        <label>Tatoeba search keyword<input value={keyword} maxLength={80} onChange={(event) => setKeyword(event.target.value)} /></label>
        <label>Daily slot<input type="number" min={0} max={19} value={slot} onChange={(event) => setSlot(Number(event.target.value))} /></label></div>
      <button className={styles.primary} disabled={busy || !topicId || !keyword.trim()} onClick={() => void generate()}>{busy ? 'Working…' : 'Generate review draft'}</button>
      {!topicId || !keyword.trim() ? <p className={styles.hint}>Choose an enabled topic and enter a source keyword to generate.</p> : null}
    </div>
    <details className={styles.details}><summary>Topics and generation settings</summary><div className={styles.detailsBody}>
    <div className="editor"><h3>Add topic</h3><p>Search keywords are sent to Tatoeba. Keep them short and specific.</p>
      <label>Title<input value={newTopicTitle} maxLength={120} onChange={(event) => setNewTopicTitle(event.target.value)} /></label>
      <label>Slug<input value={newTopicSlug} maxLength={80} onChange={(event) => setNewTopicSlug(event.target.value)} /></label>
      <label>Tatoeba keyword<input value={newTopicKeyword} maxLength={80} onChange={(event) => setNewTopicKeyword(event.target.value)} /></label>
      <label>Difficulty<select value={newTopicDifficulty} onChange={(event) => setNewTopicDifficulty(event.target.value)}>
        {['A1','A2','B1','B2','C1','C2'].map((level) => <option key={level}>{level}</option>)}</select></label>
      <button disabled={busy} onClick={() => void addTopic()}>Add topic</button>
    </div>
    {settings ? <div className="editor"><h3>Generation settings</h3>
      <label><input type="checkbox" checked={settings.ai_generation_enabled}
        onChange={(event) => setSettings({ ...settings, ai_generation_enabled: event.target.checked })} /> Enable AI generation</label>
      <label><input type="checkbox" checked={settings.source_import_enabled}
        onChange={(event) => setSettings({ ...settings, source_import_enabled: event.target.checked })} /> Enable Tatoeba import</label>
      <label>Daily draft target<input type="number" min={0} max={20} value={settings.daily_generation_target}
        onChange={(event) => setSettings({ ...settings, daily_generation_target: Number(event.target.value) })} /></label>
      <label>Maximum daily requests<input type="number" min={0} max={20} value={settings.maximum_daily_requests}
        onChange={(event) => setSettings({ ...settings, maximum_daily_requests: Number(event.target.value) })} /></label>
      <label>Maximum output tokens per draft<input type="number" min={128} max={4096} value={settings.maximum_output_tokens}
        onChange={(event) => setSettings({ ...settings, maximum_output_tokens: Number(event.target.value) })} /></label>
      <label>Enabled topics<select multiple value={settings.enabled_topics}
        onChange={(event) => setSettings({ ...settings, enabled_topics: Array.from(event.target.selectedOptions).map((option) => option.value) })}>
        {topics.filter((topic) => topic.is_active).map((topic) => <option key={topic.id} value={topic.slug}>{topic.title}</option>)}</select></label>
      <button disabled={busy} onClick={() => void saveSettings()}>Save settings</button>
    </div> : null}
    </div></details>
     {selected ? <div ref={reviewEditor} className={`editor ${styles.reviewEditor}`}><div className={styles.sectionHead}><div><p className={styles.eyebrow}>EDITORIAL REVIEW · {selected.difficulty}</p><h2>{selected.title}</h2></div><span className={styles.badge}>{selected.status.replaceAll('_',' ')}</span></div>
       <p>Review the expression, bilingual dialogue and source attribution before publication.</p>
       <div className={styles.reviewGrid}><div className={styles.mainColumn}>
       <label>Title<input value={title} disabled={['published','archived'].includes(selected.status)} onChange={(event) => setTitle(event.target.value)} /></label>
       <label>Description<textarea value={description} disabled={['published','archived'].includes(selected.status)} onChange={(event) => setDescription(event.target.value)} /></label>
       <h3>Expressions</h3>{phraseEdits.map((phrase) => <div className={styles.phrase} key={phrase.key}>
         <div className={styles.phraseHead}><strong>{phrase.isActive ? 'Visible expression' : 'Removed from learner view'}</strong><button type="button" disabled={['published','archived'].includes(selected.status)} onClick={() => changePhrase(phrase.key,{ isActive: !phrase.isActive })}>{phrase.isActive ? 'Remove' : 'Restore'}</button></div>
         <label>English expression<input value={phrase.englishText} disabled={['published','archived'].includes(selected.status)} maxLength={500} onChange={(event) => changePhrase(phrase.key,{ englishText: event.target.value })} /></label>
         <label>Vietnamese translation<input value={phrase.vietnameseTranslation} disabled={['published','archived'].includes(selected.status)} maxLength={500} onChange={(event) => changePhrase(phrase.key,{ vietnameseTranslation: event.target.value })} /></label>
         <label>Usage context<textarea rows={3} value={phrase.usageContext} disabled={['published','archived'].includes(selected.status)} maxLength={2000} onChange={(event) => changePhrase(phrase.key,{ usageContext: event.target.value })} /></label>
         <label>Formality<select value={phrase.formality} disabled={['published','archived'].includes(selected.status)} onChange={(event) => changePhrase(phrase.key,{ formality: event.target.value })}>{['informal','neutral','formal'].map((value) => <option key={value}>{value}</option>)}</select></label>
         {selected.real_english_phrases.find((original) => original.id === phrase.id)?.mymemory_candidate_vi ? <small>Unverified MyMemory candidate: {selected.real_english_phrases.find((original) => original.id === phrase.id)?.mymemory_candidate_vi}</small> : null}
       </div>)}
       {!['published','archived'].includes(selected.status) ? <button type="button" onClick={() => setPhraseEdits((old) => [...old,{ key: crypto.randomUUID(), englishText: '', vietnameseTranslation: '', formality: 'neutral', usageContext: '', isActive: true }])}>Add expression</button> : null}
        <h3>Learner preview</h3><div ref={learnerPreview} className={styles.preview}><strong>{title || selected.title}</strong><p>{description || selected.description}</p>{selected.real_english_dialogues.map((dialogue) => <div key={dialogue.id}><h4>{dialogue.title}</h4>{[...dialogue.real_english_dialogue_lines].sort((a,b) => a.sort_order-b.sort_order).map((line) => <p key={line.id}><strong>{line.speaker}:</strong> {line.english_text}<br /><span>{line.vietnamese_translation}</span></p>)}</div>)}</div>
       </div><aside className={styles.sideColumn}><h3>Review checklist</h3><p>Status: {selected.status.replaceAll('_',' ')} · CEFR {selected.difficulty}</p><p>Topic: {(Array.isArray(selected.real_english_topics) ? selected.real_english_topics[0]?.title : selected.real_english_topics?.title) || 'General'}</p><p>Generation: {selected.generation_source === 'hybrid_ai' ? 'Gemini original content' : 'Human editorial'}</p><p>{phraseEdits.filter((phrase) => phrase.isActive).length} active expression(s) · {selected.real_english_dialogues.reduce((count, dialogue) => count + dialogue.real_english_dialogue_lines.length,0)} dialogue lines</p>
      <h3>Source attribution · Tatoeba</h3>{selected.real_english_source_references.map((source) => <div className={styles.source} key={source.id}>
        <p><strong>English:</strong> {source.english_text}</p><p><strong>Vietnamese:</strong> {source.vietnamese_text}</p>
        <p>Contributors: {source.english_contributor || 'not specified'} / {source.vietnamese_contributor || 'not specified'}</p>
        <p>Licenses: {source.english_license || 'unverified'} / {source.vietnamese_license || 'unverified'} · Eligibility: {source.validation_status}</p>
        <p>{source.attribution_text}</p>
        <p><a href={source.source_url} target="_blank" rel="noopener noreferrer">English source ↗</a> · <a href={source.translation_url} target="_blank" rel="noopener noreferrer">Vietnamese source ↗</a></p>
      </div>)}
      <label>Review note<textarea value={note} onChange={(event) => setNote(event.target.value)} /></label>
      <div className="editor-actions">
         <button type="button" onClick={() => learnerPreview.current?.scrollIntoView({ block: 'center', behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })}>Preview learner view</button>
         {!['published','archived'].includes(selected.status) ? <button disabled={busy} onClick={() => void save()}>Save draft</button> : null}
         {['draft','needs_revision','rejected'].includes(selected.status) ? <button disabled={busy} onClick={() => void review('submit')}>Submit for review</button> : null}
         {['in_review','pending_review'].includes(selected.status) ? <><button disabled={busy} onClick={() => void review('approve')}>Approve</button><button className={styles.primary} disabled={busy} onClick={() => void review('approve_publish')}>Approve & publish</button><button disabled={busy || !note.trim()} onClick={() => void review('request_revision')}>Request revision</button><button className="danger-button" disabled={busy || !note.trim()} onClick={() => void review('reject')}>Reject</button></> : null}
         {['approved','publish_failed'].includes(selected.status) ? <button className={styles.primary} disabled={busy} onClick={() => void review('publish')}>Publish</button> : null}
         {selected.status === 'archived' ? <button disabled={busy} onClick={() => void review('restore')}>Restore to review</button> : null}
         {['pending_review','approved','published','needs_revision','rejected','draft','publish_failed'].includes(selected.status) ? <button disabled={busy} onClick={() => void review('archive')}>Archive</button> : null}
       </div></aside></div>
    </div> : null}
  </section>;
}
