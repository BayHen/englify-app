import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Exercise } from './api';
import type { WritingDraft } from './draft-storage';
import { useWritingDrafts } from './use-writing-drafts';

const storage = vi.hoisted(() => ({ save: vi.fn(), remove: vi.fn(), list: vi.fn() }));
// These tests exercise the hook's async commands and refs, without mounting native UI.
vi.mock('react', () => ({ useCallback: (fn: unknown) => fn, useEffect: () => undefined,
  useRef: (value: unknown) => ({ current: value }), useState: (value: unknown) => [value, vi.fn()] }));
vi.mock('expo-network', () => ({}));
vi.mock('expo-crypto', () => ({ randomUUID: () => 'draft-id' }));
vi.mock('./draft-storage', () => ({
  writingDraftContext: (exercise: string) => `exercise:${exercise}`,
  cacheWritingExercises: async () => undefined, getWritingDraft: async () => null,
  saveWritingDraft: storage.save, deleteWritingDraft: storage.remove, listWritingDrafts: storage.list,
}));
const exercise = { id: 'one' } as Exercise;
beforeEach(() => { vi.useFakeTimers(); storage.save.mockReset().mockImplementation(async value => value);
  storage.remove.mockReset().mockResolvedValue(undefined); storage.list.mockReset().mockResolvedValue([]); });

afterEach(() => { vi.clearAllTimers(); vi.useRealTimers(); });

function deferred<T>() { let resolve!: (value: T) => void;
  const promise = new Promise<T>(done => { resolve = done; }); return { promise, resolve }; }

describe('Writing autosave commands', () => {
  it('continues autosaving after discarding the active draft', async () => {
    const drafts = useWritingDrafts('learner'); await drafts.activate(exercise, null);
    drafts.change('Old draft', []); await drafts.discard('exercise:one');
    drafts.change('New draft after discard', []); await drafts.flush();
    expect(storage.save).toHaveBeenLastCalledWith(expect.objectContaining({ content: 'New draft after discard' }));
  });
  it('flushes pending content before deleting the submitted revision', async () => {
    const drafts = useWritingDrafts('learner'); await drafts.activate(exercise, null);
    drafts.change('Submitted response', []); await drafts.clearSubmitted('exercise:one', 1);
    expect(storage.save).toHaveBeenCalled();
    expect(storage.save.mock.invocationCallOrder[0]).toBeLessThan(storage.remove.mock.invocationCallOrder[0]);
    await vi.runAllTimersAsync(); expect(storage.save).toHaveBeenCalledTimes(1);
  });
  it('waits for an in-flight save before discarding it', async () => {
    const saving = deferred<WritingDraft>(); storage.save.mockReturnValueOnce(saving.promise);
    const drafts = useWritingDrafts('learner'); await drafts.activate(exercise, null);
    drafts.change('Old content', []); const flush = drafts.flush();
    await Promise.resolve(); const discarded = drafts.discard('exercise:one');
    await Promise.resolve(); expect(storage.remove).not.toHaveBeenCalled();
    saving.resolve(storage.save.mock.calls[0][0]); await flush; await discarded;
    expect(storage.remove).toHaveBeenCalledWith('learner', 'exercise:one');
  });
  it('keeps newer edits when a submitted revision is cleared', async () => {
    let persisted: WritingDraft | null = null;
    storage.save.mockImplementation(async (value: WritingDraft) => { persisted = value; return value; });
    storage.remove.mockImplementation(async (_user: string, _context: string, revision: number) => {
      if (persisted && persisted.revision <= revision) persisted = null;
    });
    const drafts = useWritingDrafts('learner'); await drafts.activate(exercise, null);
    drafts.change('Submitted text', []); await drafts.flush(); const sent = drafts.submittedRevision();
    drafts.change('Newer unsent text', []); await drafts.clearSubmitted('exercise:one', sent);
    expect(persisted).toMatchObject({ content: 'Newer unsent text', revision: 2 });
  });

});
