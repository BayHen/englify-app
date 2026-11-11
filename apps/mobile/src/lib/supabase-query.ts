import { getSupabase } from '@/auth/supabase';
import { ApiError } from './api';

export async function currentUserId(): Promise<string> {
  const { data, error } = await getSupabase().auth.getSession();
  if (error) throw new ApiError(0, 'Could not restore your session. Check your connection and try again.');
  if (!data.session) throw new ApiError(401, 'Session expired. Please sign in again.');
  return data.session.user.id;
}

export function dataOrThrow<T>(result: { data: T | null; error: { message: string } | null; status: number }): T {
  errorOrThrow(result);
  if (result.data === null) throw new ApiError(404, 'Record not found.');
  return result.data;
}

export function errorOrThrow(result: { error: { message: string } | null; status: number }): void {
  if (result.error) {
    const status = result.status || 0;
    throw new ApiError(status, status === 0 ? 'Cannot reach Supabase. Check your connection and try again.' : result.error.message);
  }
}
