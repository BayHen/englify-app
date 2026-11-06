import { apiUrl, ApiError } from '@/lib/api';

export type LearningGoal = 'conversation' | 'travel' | 'work' | 'exams';
export type Proficiency = 'beginner' | 'intermediate' | 'advanced';
export type Profile = {
  id: string;
  display_name: string;
  preferences: null | {
    learning_goal: LearningGoal | null;
    initial_proficiency: Proficiency | null;
    daily_goal_minutes: number;
    onboarding_completed_at: string | null;
  };
};
export type OnboardingInput = {
  learning_goal: LearningGoal;
  initial_proficiency: Proficiency;
  daily_goal_minutes: number;
};

export async function privateRequest<T>(path: string, accessToken: string, method = 'GET', body?: unknown): Promise<T> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(apiUrl(path), {
      method,
      headers: { Authorization: `Bearer ${accessToken}`, Accept: 'application/json', ...(body === undefined ? {} : { 'Content-Type': 'application/json' }) },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: controller.signal,
    });
    const envelope: unknown = await response.json();
    if (!response.ok) {
      const message = isErrorEnvelope(envelope) ? envelope.error.message : `Request failed (${response.status})`;
      throw new ApiError(response.status, message);
    }
    if (!isDataEnvelope(envelope)) throw new ApiError(response.status, 'Invalid API response');
    return envelope.data as T;
  } finally { clearTimeout(timeout); }
}

function isDataEnvelope(value: unknown): value is { data: unknown; error: null } {
  return typeof value === 'object' && value !== null && 'data' in value && 'error' in value && value.error === null;
}
function isErrorEnvelope(value: unknown): value is { error: { message: string } } {
  if (typeof value !== 'object' || value === null || !('error' in value)) return false;
  const error = value.error;
  return typeof error === 'object' && error !== null && 'message' in error && typeof error.message === 'string';
}
