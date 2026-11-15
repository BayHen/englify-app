import { describe, expect, it, vi } from 'vitest';
import { supabaseAdminRequest } from '../../admin/src/lib/supabase-admin';
import type { SupabaseClient } from '@supabase/supabase-js';

function client(admin: boolean, from = vi.fn()) {
  return { auth: { getSession: vi.fn(async () => ({
    data: { session: { user: { id: 'admin-user' } } }, error: null,
  })) }, rpc: vi.fn(async (name: string) => ({ data: name === 'englify_is_admin' ? admin : { courses: 2 }, error: null })), from } as unknown as SupabaseClient;
}

describe('Supabase Admin adapter', () => {
  it('rejects a normal learner before any content query or write', async () => {
    const from = vi.fn();
    const ordinary = client(false, from);
    await expect(supabaseAdminRequest(ordinary, '/catalog/courses', { method: 'POST', body: JSON.stringify({ data: { title: 'Blocked' } }) }))
      .rejects.toThrow('Administrator access required');
    expect(from).not.toHaveBeenCalled();
  });
  it('provides role, editor schema and server-owned metrics to an admin', async () => {
    const admin = client(true);
    await expect(supabaseAdminRequest(admin, '/me')).resolves.toEqual({ user_id: 'admin-user', role: 'admin' });
    await expect(supabaseAdminRequest<Record<string, unknown>>(admin, '/schema')).resolves.toHaveProperty('quiz-questions.answer', 'json');
    await expect(supabaseAdminRequest(admin, '/overview')).resolves.toEqual({ courses: 2 });
    expect(admin.rpc).toHaveBeenCalledWith('englify_admin_metrics', { p_view: 'overview' });
  });
  it('creates a draft and publishes through database policies and triggers', async () => {
    const inserted = vi.fn(async () => ({ data: null, error: null }));
    const updated = vi.fn(() => ({ eq: vi.fn(async () => ({ data: null, error: null })) }));
    const selected = vi.fn(() => ({ eq: vi.fn(() => ({ maybeSingle: vi.fn(async () => ({
      data: { id: 'course-1', title: 'Course', is_published: false }, error: null,
    })) })) }));
    const from = vi.fn(() => ({ insert: inserted, update: updated, select: selected }));
    const admin = client(true, from);
    vi.stubGlobal('crypto', { randomUUID: () => 'course-1' });
    try {
      await expect(supabaseAdminRequest(admin, '/catalog/courses', {
        method: 'POST', body: JSON.stringify({ data: { slug: 'course', title: 'Course', level: 1 } }),
      })).resolves.toMatchObject({ id: 'course-1' });
      expect(inserted).toHaveBeenCalledWith({ id: 'course-1', slug: 'course', title: 'Course', level: 1 });
      await expect(supabaseAdminRequest(admin, '/catalog/courses/course-1/publish?published=true', { method: 'POST' }))
        .resolves.toMatchObject({ id: 'course-1' });
      expect(updated).toHaveBeenCalledWith({ is_published: true });
    } finally { vi.unstubAllGlobals(); }
  });
});
