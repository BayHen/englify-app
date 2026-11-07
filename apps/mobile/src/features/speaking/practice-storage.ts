import Storage from 'expo-sqlite/kv-store';
import type { PracticeHistory } from './practice-history';

const empty = (): PracticeHistory => ({ completed: 0, recordings: {}, completedTakes: {} });
const key = (userId: string) => `speaking-practice:v1:${userId}`;

export async function readPracticeHistory(userId: string): Promise<PracticeHistory> {
  const raw = await Storage.getItem(key(userId));
  if (!raw) return empty();
  try {
    const value: unknown = JSON.parse(raw);
    if (typeof value !== 'object' || value === null || !('completed' in value) || !('recordings' in value)) return empty();
    const history = value as PracticeHistory;
    if (!Number.isSafeInteger(history.completed) || history.completed < 0 || typeof history.recordings !== 'object' || !history.recordings) return empty();
    return { ...history, completedTakes: history.completedTakes ?? {} };
  } catch { return empty(); }
}

export async function writePracticeHistory(userId: string, value: PracticeHistory): Promise<void> {
  await Storage.setItem(key(userId), JSON.stringify(value));
}

