export class ApiError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
    this.name = 'ApiError';
  }
}

export function apiUrl(path: string, base = process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:8000/api/v1'): string {
  return `${base.replace(/\/+$/, '')}/${path.replace(/^\/+/, '')}`;
}

export async function getJson<T>(path: string, validate: (value: unknown) => value is T): Promise<T> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(apiUrl(path), { headers: { Accept: 'application/json' }, signal: controller.signal });
    if (!response.ok) throw new ApiError(response.status, `API request failed (${response.status})`);
    const data: unknown = await response.json();
    if (!validate(data)) throw new ApiError(response.status, 'Invalid API response');
    return data;
  } finally {
    clearTimeout(timer);
  }
}

export type HealthResponse = { data: { status: 'ok' }; error: null };
export function isHealthResponse(value: unknown): value is HealthResponse {
  if (typeof value !== 'object' || value === null || !('data' in value) || !('error' in value)) return false;
  const data = value.data;
  return value.error === null && typeof data === 'object' && data !== null && 'status' in data && data.status === 'ok';
}
export const getHealth = () => getJson('/health', isHealthResponse);
