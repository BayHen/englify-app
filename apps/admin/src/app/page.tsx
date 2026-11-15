'use client';

import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { adminRequest, getSupabase } from '@/lib/client';
import { HybridRealEnglishPanel, HybridRealEnglishSetup } from './hybrid-real-english-panel';
import { PublishedRealEnglishLibrary } from './published-real-english-library';

const hybridReady = process.env.NEXT_PUBLIC_REAL_ENGLISH_HYBRID_ENABLED === 'true';

type Row = Record<string, unknown> & { id: string; is_published?: boolean };
type Catalog = { items: Row[]; total: number; page: number; page_size: number };
type Section = 'dashboard' | 'vocabulary' | 'courses' | 'units' | 'lessons' | 'lesson-items' | 'quiz-questions' | 'quiz-options' | 'real-english' | 'hybrid-real-english' | 'badges' | 'analytics' | 'publishing' | 'audit';
const nav: { id: Section; label: string; group: string }[] = [
  { id: 'dashboard', label: 'Dashboard', group: 'Overview' },
  { id: 'vocabulary', label: 'Vocabulary', group: 'Content' },
  { id: 'courses', label: 'Courses', group: 'Content' },
  { id: 'units', label: 'Units', group: 'Content' },
  { id: 'lessons', label: 'Lesson builder', group: 'Content' },
  { id: 'lesson-items', label: 'Lesson items', group: 'Content' },
  { id: 'quiz-questions', label: 'Quiz builder', group: 'Content' },
  { id: 'quiz-options', label: 'Quiz options', group: 'Content' },
  { id: 'real-english', label: 'Real English', group: 'Content' },
  { id: 'hybrid-real-english', label: 'AI lesson review', group: 'Content' },
  { id: 'badges', label: 'Badge rules', group: 'Content' },
  { id: 'analytics', label: 'Learning analytics', group: 'Operations' },
  { id: 'publishing', label: 'Publishing', group: 'Operations' },
  { id: 'audit', label: 'Audit log', group: 'Operations' },
];
const choices: Record<string, string[]> = { formality: ['informal', 'neutral', 'formal'], metric: ['completed_lessons', 'total_xp'] };
const kinds: Record<string, string[]> = {
  'lesson-items': ['reading', 'tip'],
  'quiz-questions': ['multiple_choice', 'fill_blank', 'matching', 'listening', 'grammar'],
  'real-english': ['slang', 'idiom', 'phrasal_verb', 'casual_expression', 'everyday_conversation', 'movie_style_dialogue'],
};
const sectionDescriptions: Record<Section, string> = {
  dashboard: 'A live overview of published learning content.',
  vocabulary: 'Build and maintain the English and Vietnamese word library.',
  courses: 'Organize the path learners follow.',
  units: 'Group related lessons into clear milestones.',
  lessons: 'Create and review the lessons learners will see.',
  'lesson-items': 'Shape the reading and practice inside each lesson.',
  'quiz-questions': 'Write questions that check understanding.',
  'quiz-options': 'Manage the possible answers for each question.',
  'real-english': 'Curate everyday expressions and authentic examples.',
  'hybrid-real-english': 'Review AI drafts and their source attribution.',
  badges: 'Configure achievements and reward milestones.',
  analytics: 'Read aggregate learning activity without exposing learners.',
  publishing: 'Review drafts before they appear in the app.',
  audit: 'See recent content changes and their actors.',
};
const content = (section: Section) => !['dashboard', 'analytics', 'publishing', 'audit', 'hybrid-real-english'].includes(section);
const format = (value: unknown) => typeof value === 'object' && value !== null ? JSON.stringify(value) : String(value ?? '');

export default function AdminPage() {
  const [access, setAccess] = useState<'loading' | 'guest' | 'checking' | 'admin' | 'denied'>('loading');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [section, setSection] = useState<Section>('dashboard');
  const [schema, setSchema] = useState<Record<string, Record<string, string>>>({});
  const [rows, setRows] = useState<Row[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [query, setQuery] = useState('');
  const [selected, setSelected] = useState<Row | null>(null);
  const [form, setForm] = useState<Record<string, string>>({});
  const [stats, setStats] = useState<Record<string, number>>({});
  const [logs, setLogs] = useState<Row[]>([]);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  const authorize = useCallback(async () => {
    try {
      const { data } = await getSupabase().auth.getSession();
      if (!data.session) { setAccess('guest'); return; }
      setAccess('checking');
      await adminRequest('/me');
      setSchema(await adminRequest('/schema'));
      setAccess('admin');
    } catch (cause) {
      const text = cause instanceof Error ? cause.message : 'Could not check access.';
      setAccess(text.includes('Administrator access') ? 'denied' : 'guest');
      setMessage(text);
    }
  }, []);
  useEffect(() => {
    queueMicrotask(() => { void authorize(); });
    let subscription: { unsubscribe(): void } | undefined;
    try { subscription = getSupabase().auth.onAuthStateChange(() => { setTimeout(() => { void authorize(); }, 0); }).data.subscription; }
    catch { /* authorize displays setup instructions. */ }
    return () => subscription?.unsubscribe();
  }, [authorize]);

  const load = useCallback(async () => {
    if (access !== 'admin') return;
    setLoading(true);
    try {
      if (section === 'hybrid-real-english') {
        // The dedicated panel reads its own RLS-protected lesson list.
      } else if (content(section)) {
        const result = await adminRequest<Catalog>(`/catalog/${section}?q=${encodeURIComponent(query)}&page=${page}&page_size=15`);
        setRows(result.items); setTotal(result.total);
      } else if (section === 'audit') setLogs(await adminRequest('/audit'));
      else setStats(await adminRequest(section === 'publishing' ? '/publishing' : section === 'analytics' ? '/analytics' : '/overview'));
      setMessage('');
    } catch (cause) { setMessage(cause instanceof Error ? cause.message : 'Could not load data.'); }
    finally { setLoading(false); }
  }, [access, section, query, page]);
  useEffect(() => { queueMicrotask(() => { void load(); }); }, [load]);

  async function login(event: FormEvent) {
    event.preventDefault(); setBusy(true); setMessage('');
    try {
      const { error } = await getSupabase().auth.signInWithPassword({ email: email.trim(), password });
      setPassword('');
      if (error) throw error;
      await authorize();
    } catch (cause) { setMessage(cause instanceof Error ? cause.message : 'Sign in failed.'); }
    finally { setBusy(false); }
  }
  async function logout() { await getSupabase().auth.signOut(); setSelected(null); setAccess('guest'); }
  function navigate(next: Section) { setSection(next); setPage(1); setQuery(''); setSelected(null); setForm({}); setMessage(''); }
  async function edit(row: Row) {
    setBusy(true);
    try {
      const item = await adminRequest<Row>(`/catalog/${section}/${row.id}`);
      setSelected(item);
      setForm(Object.fromEntries(Object.keys(schema[section] ?? {}).map((key) => [key, format(item[key])] )));
    } catch (cause) { setMessage(cause instanceof Error ? cause.message : 'Could not open item.'); }
    finally { setBusy(false); }
  }
  function startNew() { setSelected(null); setForm({}); setMessage(''); }
  async function save(event: FormEvent) {
    event.preventDefault(); setBusy(true); setMessage('');
    try {
      const data: Record<string, unknown> = {};
      for (const [name, kind] of Object.entries(schema[section] ?? {})) {
        const raw = form[name]?.trim() ?? '';
        if (!raw && kind !== 'boolean') continue;
        data[name] = kind === 'positive' || kind === 'xp' ? Number(raw) : kind === 'object' || kind === 'array' || kind === 'json' ? JSON.parse(raw) : kind === 'boolean' ? raw === 'true' : raw;
      }
      const item = await adminRequest<Row>(`/catalog/${section}${selected ? `/${selected.id}` : ''}`, { method: selected ? 'PATCH' : 'POST', body: JSON.stringify({ data }) });
      setSelected(item); setMessage(selected ? 'Changes saved.' : 'Draft created. Review before publishing.');
      await load();
    } catch (cause) { setMessage(cause instanceof Error ? cause.message : 'Could not save content.'); }
    finally { setBusy(false); }
  }
  async function change(action: 'publish' | 'unpublish' | 'archive') {
    if (!selected) return;
    if (action === 'archive' && !window.confirm('Archive this item? Learner history stays intact.')) return;
    setBusy(true); setMessage('');
    try {
      if (action === 'archive') await adminRequest(`/catalog/${section}/${selected.id}`, { method: 'DELETE' });
      else setSelected(await adminRequest<Row>(`/catalog/${section}/${selected.id}/publish?published=${action === 'publish'}`, { method: 'POST' }));
      if (action === 'archive') setSelected(null);
      setMessage(action === 'archive' ? 'Item archived.' : action === 'publish' ? 'Content published.' : 'Moved to draft.');
      await load();
    } catch (cause) { setMessage(cause instanceof Error ? cause.message : 'Action failed.'); }
    finally { setBusy(false); }
  }

  if (access === 'loading' || access === 'checking') return <main className="gate"><p className="eyebrow">ENGLIFY QUEST / ADMIN</p><h1>Checking access…</h1></main>;
  if (access !== 'admin') return <main className="gate"><p className="eyebrow">ENGLIFY QUEST / ADMIN</p><h1>Content studio</h1><p>Sign in with an account granted admin access to manage learning content.</p>{access === 'denied' && <div className="notice danger">This account cannot access administration.</div>}{message && <div className="notice">{message}</div>}<form onSubmit={login} className="login-form"><label>Email<input type="email" required autoComplete="username" value={email} onChange={(event) => setEmail(event.target.value)} /></label><label>Password<input type="password" required autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} /></label><button disabled={busy}>{busy ? 'Signing in…' : 'Sign in'}</button></form>{access === 'denied' && <button className="quiet" onClick={() => void logout()}>Sign out</button>}</main>;
  const label = nav.find((item) => item.id === section)?.label ?? section;
  const fields = schema[section] ?? {};
  return <div className="shell"><aside className="sidebar"><div className="brand"><span className="brand-mark">E<span>✦</span></span><div><strong>Englify Quest</strong><small>CONTENT STUDIO</small></div></div><nav>{['Overview', 'Content', 'Operations'].map((group) => <div key={group} className="nav-group"><p>{group}</p>{nav.filter((item) => item.group === group).map((item) => <button key={item.id} className={section === item.id ? 'active' : ''} aria-current={section === item.id ? 'page' : undefined} onClick={() => navigate(item.id)}>{item.label}</button>)}</div>)}</nav><button className="signout" onClick={() => void logout()}>Sign out</button></aside><main className="workspace"><header className="topbar"><div><p className="eyebrow">ADMINISTRATION / {section.toUpperCase()}</p><h1>{label}</h1><p className="section-description">{sectionDescriptions[section]}</p></div><span className="secure-pill">● Admin access</span></header>{message && <div role="status" className="notice">{message}</div>}{loading && <div className="notice">Loading…</div>}
  {section === 'real-english' ? <PublishedRealEnglishLibrary onOpenReview={() => navigate('hybrid-real-english')} /> : null}
  {section !== 'hybrid-real-english' ? <div className="studio-intro"><div><p className="eyebrow">ENGLIFY CONTENT STUDIO</p><h2>{section === 'dashboard' ? 'Your content workspace' : section === 'analytics' ? 'Learning insights' : section === 'publishing' ? 'Publishing overview' : section === 'audit' ? 'Editorial history' : `${label} studio`}</h2><p>{sectionDescriptions[section]}</p></div><span className="studio-mark" aria-hidden="true">E</span></div> : null}
  {section === 'hybrid-real-english' ? hybridReady ? <HybridRealEnglishPanel /> : <HybridRealEnglishSetup /> : content(section) ? <div className="content-grid"><section className="panel"><div className="panel-head"><div><h2>Content library</h2><p>Search, review, and edit {label.toLowerCase()}.</p></div><button onClick={startNew}>+ New draft</button></div><div className="searchbar"><input aria-label={`Search ${label}`} placeholder="Search content…" value={query} onChange={(event) => { setQuery(event.target.value); setPage(1); }} /><span>{total} items</span></div><div className="table-wrap"><table><thead><tr><th>Name</th><th>Status</th><th>Updated</th></tr></thead><tbody>{rows.map((row) => <tr key={row.id} onClick={() => void edit(row)}><td><strong>{format(row.title ?? row.term ?? row.expression ?? row.prompt ?? row.answer_text ?? row.code ?? row.slug ?? row.id)}</strong><small>{format(row.slug ?? row.id).slice(0, 48)}</small></td><td><span className={`status ${row.is_published ? 'published' : 'draft'}`}>{section === 'quiz-options' ? 'Part of question' : row.is_published ? 'Published' : 'Draft'}</span></td><td>{row.updated_at ? new Date(String(row.updated_at)).toLocaleDateString() : '—'}</td></tr>)}</tbody></table>{rows.length === 0 && <p className="empty">No content found. Create a draft to begin.</p>}</div><div className="pager"><button disabled={page === 1} onClick={() => setPage(page - 1)}>Previous</button><span>Page {page} of {Math.max(1, Math.ceil(total / 15))}</span><button disabled={page * 15 >= total} onClick={() => setPage(page + 1)}>Next</button></div></section><section className="panel editor"><div className="panel-head"><div><h2>{selected ? 'Edit content' : 'Create draft'}</h2><p>{selected ? `ID ${selected.id}` : 'Content stays private until published.'}</p></div></div><form onSubmit={save}>{Object.entries(fields).map(([name, kind]) => { const options = name === 'kind' ? kinds[section] : choices[name]; const required = !selected && !['optional', 'object', 'array', 'json', 'xp'].includes(kind); return <label key={name}>{name.replaceAll('_', ' ')}{kind === 'boolean' ? <select value={form[name] ?? 'false'} onChange={(event) => setForm({ ...form, [name]: event.target.value })}><option value="false">No</option><option value="true">Yes</option></select> : options ? <select required={required} value={form[name] ?? ''} onChange={(event) => setForm({ ...form, [name]: event.target.value })}><option value="">Choose…</option>{options.map((option) => <option key={option}>{option}</option>)}</select> : kind === 'object' || kind === 'array' || kind === 'json' || name === 'description' || name === 'context_explanation' ? <textarea required={required} rows={['object', 'array', 'json'].includes(kind) ? 4 : 3} placeholder={kind === 'array' || kind === 'json' ? '[]' : kind === 'object' ? '{}' : ''} value={form[name] ?? ''} onChange={(event) => setForm({ ...form, [name]: event.target.value })} /> : <input required={required} type={kind === 'positive' || kind === 'xp' ? 'number' : name === 'audio_url' ? 'url' : 'text'} min={kind === 'positive' ? 1 : 0} value={form[name] ?? ''} onChange={(event) => setForm({ ...form, [name]: event.target.value })} />}{kind === 'uuid' && <small>Paste the parent item ID.</small>}{name === 'answer' && <small>Fill blank/listening/grammar: JSON array. Matching: JSON object.</small>}</label>; })}<button className="save" disabled={busy}>{busy ? 'Saving…' : selected ? 'Save changes' : 'Create draft'}</button></form>{selected && section !== 'quiz-options' && <div className="editor-actions"><button className="secondary" disabled={busy} onClick={() => void change(selected.is_published ? 'unpublish' : 'publish')}>{selected.is_published ? 'Move to draft' : 'Publish'}</button><button className="danger-button" disabled={busy} onClick={() => void change('archive')}>Archive</button></div>}</section></div> : section === 'audit' ? <section className="panel"><h2>Recent changes</h2><p>Every content write records its actor and action.</p><div className="table-wrap"><table><thead><tr><th>Action</th><th>Resource</th><th>Record</th><th>Time</th></tr></thead><tbody>{logs.map((row) => <tr key={row.id}><td>{format(row.action)}</td><td>{format(row.resource)}</td><td className="mono">{format(row.record_id).slice(0, 18)}…</td><td>{new Date(String(row.created_at)).toLocaleString()}</td></tr>)}</tbody></table></div></section> : <><div className="stat-grid">{Object.entries(stats).map(([name, value]) => <div key={name} className="stat"><span>{name.replaceAll('_', ' ')}</span><strong>{value.toLocaleString()}</strong><small>{section === 'publishing' ? 'Awaiting publication' : section === 'dashboard' ? 'Published content' : 'Stored learning records'}</small></div>)}</div><section className="panel intro-panel"><p className="eyebrow">EDITORIAL WORKFLOW</p><h2>{section === 'publishing' ? 'Review drafts before release' : section === 'analytics' ? 'Learning activity at a glance' : 'Build the next learning moment'}</h2><p>{section === 'publishing' ? 'Open a content module, review a draft, then publish it. Published lessons and vocabulary become available in the mobile API.' : section === 'analytics' ? 'These server counts do not identify individual learners.' : 'Manage original lessons, useful vocabulary, expressions, and achievement rules. Every change is recorded.'}</p><button onClick={() => navigate(section === 'publishing' ? 'lessons' : 'courses')}>{section === 'publishing' ? 'Open lesson drafts' : 'Explore courses'} →</button></section></>}
  </main></div>;
}
