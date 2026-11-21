const memory = new Map<string, string>();

export async function readStorage(key: string): Promise<string | null> {
  if (typeof window === 'undefined') return null;
  try { return window.localStorage.getItem(key); }
  catch { return memory.get(key) ?? null; }
}
export async function writeStorage(key: string, value: string): Promise<void> {
  if (typeof window === 'undefined') return;
  try { window.localStorage.setItem(key, value); }
  catch { memory.set(key, value); }
}
