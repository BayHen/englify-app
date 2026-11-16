import { ApiError } from '@/lib/api';
import type { TranslationKey } from './keys';

export function preferenceErrorKey(cause: unknown, fallback: TranslationKey): TranslationKey {
  if (!(cause instanceof ApiError)) return fallback;
  if (cause.status === 0) return 'preferences.error.network';
  if (cause.status === 401 || cause.status === 403) return 'preferences.error.auth';
  if (cause.status === 409) return 'preferences.error.conflict';
  if (cause.status === 422) return 'preferences.error.invalid';
  if (cause.status === 429) return 'preferences.error.rateLimit';
  return fallback;
}
