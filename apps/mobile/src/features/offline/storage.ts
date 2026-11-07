import * as SQLite from 'expo-sqlite';
import type { CachedJourney, CachedLesson, OutboxEvent } from './types';
import type { Profile } from '@/auth/api';

let database: Promise<SQLite.SQLiteDatabase> | null = null;
async function db() {
  database ??= (async () => {
    const handle = await SQLite.openDatabaseAsync('englify-offline.db');
    await handle.execAsync(`PRAGMA journal_mode = WAL;
      CREATE TABLE IF NOT EXISTS offline_cache (user_id TEXT NOT NULL, cache_key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY (user_id, cache_key));
      CREATE TABLE IF NOT EXISTS offline_outbox (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, value TEXT NOT NULL);
      CREATE INDEX IF NOT EXISTS offline_outbox_user ON offline_outbox (user_id);`);
    return handle;
  })();
  return database;
}
async function read<T>(userId: string, key: string): Promise<T | null> {
  const row = await (await db()).getFirstAsync<{ value: string }>('SELECT value FROM offline_cache WHERE user_id = ? AND cache_key = ?', userId, key);
  return row ? JSON.parse(row.value) as T : null;
}
async function write(userId: string, key: string, value: unknown): Promise<void> {
  await (await db()).runAsync('INSERT INTO offline_cache (user_id, cache_key, value) VALUES (?, ?, ?) ON CONFLICT(user_id, cache_key) DO UPDATE SET value = excluded.value', userId, key, JSON.stringify(value));
}
export const getCachedJourney = (userId: string) => read<CachedJourney>(userId, 'journey');
export const getCachedProfile = (userId: string) => read<Profile>(userId, 'profile');
export const cacheProfile = (userId: string, value: Profile) => write(userId, 'profile', value);
export const cacheJourney = (userId: string, value: CachedJourney) => write(userId, 'journey', value);
export const getCachedLesson = (userId: string, lessonId: string) => read<CachedLesson>(userId, `lesson:${lessonId}`);
export const cacheLesson = (userId: string, lessonId: string, value: CachedLesson) => write(userId, `lesson:${lessonId}`, value);
export async function queueEvent(value: OutboxEvent): Promise<void> {
  await (await db()).runAsync('INSERT OR IGNORE INTO offline_outbox (id, user_id, value) VALUES (?, ?, ?)', value.id, value.userId, JSON.stringify(value));
}
export async function updateEvent(value: OutboxEvent): Promise<void> {
  await (await db()).runAsync('UPDATE offline_outbox SET value = ? WHERE id = ? AND user_id = ?', JSON.stringify(value), value.id, value.userId);
}
export async function listEvents(userId: string): Promise<OutboxEvent[]> {
  const rows = await (await db()).getAllAsync<{ value: string }>('SELECT value FROM offline_outbox WHERE user_id = ?', userId);
  return rows.map((row) => JSON.parse(row.value) as OutboxEvent).sort((a, b) => a.createdAt.localeCompare(b.createdAt));
}
