import type { CachedJourney, CachedLesson, OutboxEvent } from './types';
import type { Profile } from '@/auth/api';

const memory = new Map<string, string>();
function get(key: string): string | null {
  try { return globalThis.localStorage?.getItem(key) ?? memory.get(key) ?? null; } catch { return memory.get(key) ?? null; }
}
function set(key: string, value: string): void {
  memory.set(key, value);
  try { globalThis.localStorage?.setItem(key, value); } catch { /* Private browsing can block storage. */ }
}
function key(userId: string, name: string) { return `englify:offline:${userId}:${name}`; }
async function read<T>(userId: string, name: string): Promise<T | null> { const value = get(key(userId, name)); return value ? JSON.parse(value) as T : null; }
async function write(userId: string, name: string, value: unknown): Promise<void> { set(key(userId, name), JSON.stringify(value)); }
export const getCachedJourney = (userId: string) => read<CachedJourney>(userId, 'journey');
export const getCachedProfile = (userId: string) => read<Profile>(userId, 'profile');
export const cacheProfile = (userId: string, value: Profile) => write(userId, 'profile', value);
export const cacheJourney = (userId: string, value: CachedJourney) => write(userId, 'journey', value);
export const getCachedLesson = (userId: string, lessonId: string) => read<CachedLesson>(userId, `lesson:${lessonId}`);
export const cacheLesson = (userId: string, lessonId: string, value: CachedLesson) => write(userId, `lesson:${lessonId}`, value);
export async function queueEvent(value: OutboxEvent): Promise<void> { if (!(await read<OutboxEvent>(value.userId, `event:${value.id}`))) await write(value.userId, `event:${value.id}`, value); const ids = await read<string[]>(value.userId, 'event-ids') ?? []; if (!ids.includes(value.id)) await write(value.userId, 'event-ids', [...ids, value.id]); }
export async function updateEvent(value: OutboxEvent): Promise<void> { await write(value.userId, `event:${value.id}`, value); }
export async function listEvents(userId: string): Promise<OutboxEvent[]> { const ids = await read<string[]>(userId, 'event-ids') ?? []; const events = await Promise.all(ids.map((id) => read<OutboxEvent>(userId, `event:${id}`))); return events.filter((value): value is OutboxEvent => value !== null).sort((a, b) => a.createdAt.localeCompare(b.createdAt)); }
