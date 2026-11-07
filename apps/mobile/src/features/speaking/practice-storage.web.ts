import type { PracticeHistory } from './practice-history';

const key = (userId: string) => `speaking-practice:v1:${userId}`;
const empty = (): PracticeHistory => ({ completed: 0, recordings: {}, completedTakes: {} });

export async function readPracticeHistory(userId: string): Promise<PracticeHistory> {
  try {
    const raw = globalThis.localStorage?.getItem(key(userId));
    if (!raw) return empty();
    const value: unknown = JSON.parse(raw);
    if (typeof value !== 'object' || value === null || !('completed' in value)) return empty();
    const history = value as PracticeHistory;
    if (!Number.isSafeInteger(history.completed) || history.completed < 0) return empty();
    return { completed: history.completed, recordings: {}, completedTakes: history.completedTakes ?? {} };
  } catch { return empty(); }
}

export async function writePracticeHistory(userId: string, value: PracticeHistory): Promise<void> {
  globalThis.localStorage?.setItem(key(userId), JSON.stringify({ ...value, recordings: {} }));
}
