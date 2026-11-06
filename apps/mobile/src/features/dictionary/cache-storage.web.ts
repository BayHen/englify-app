const memory = new Map<string, string>();

export async function readStorage(key: string): Promise<string | null> {
  return memory.get(key) ?? null;
}
export async function writeStorage(key: string, value: string): Promise<void> {
  memory.set(key, value);
}
