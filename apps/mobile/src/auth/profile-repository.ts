import { getSupabase } from './supabase';
import { ApiError } from '@/lib/api';
import { currentUserId, dataOrThrow, errorOrThrow } from '@/lib/supabase-query';
import type { OnboardingInput, PreferenceChanges, Profile, ProfileChanges } from './api';

type ProfileRow = Omit<Profile, 'preferences'>;
type PreferencesRow = NonNullable<Profile['preferences']>;

async function ownedId(expected?: string): Promise<string> {
  const id = await currentUserId();
  if (expected && id !== expected) throw new ApiError(401, 'Session changed. Please sign in again.');
  return id;
}

export async function readProfile(expectedUserId?: string): Promise<Profile> {
  const userId = await ownedId(expectedUserId);
  const client = getSupabase();
  const profile = dataOrThrow<ProfileRow>(await client.from('profiles')
    .select('id,display_name,username,bio,avatar_url').eq('id', userId).maybeSingle());
  const preferenceResult = await client.from('user_preferences')
    .select('learning_goal,initial_proficiency,daily_goal_minutes,onboarding_completed_at,current_cefr,preferred_accent,interface_language')
    .eq('user_id', userId).maybeSingle();
  errorOrThrow(preferenceResult);
  const preferences = preferenceResult.data as PreferencesRow | null;
  return { ...profile, preferences };
}

export async function completeOnboarding(input: OnboardingInput): Promise<Profile> {
  await ownedId();
  if (!['conversation', 'travel', 'work', 'exams'].includes(input.learning_goal)
      || !['beginner', 'intermediate', 'advanced'].includes(input.initial_proficiency)
      || !Number.isInteger(input.daily_goal_minutes) || input.daily_goal_minutes < 1 || input.daily_goal_minutes > 180) {
    throw new ApiError(422, 'Invalid onboarding preferences.');
  }
  errorOrThrow(await getSupabase().rpc('englify_save_onboarding', {
    p_learning_goal: input.learning_goal,
    p_initial_proficiency: input.initial_proficiency,
    p_daily_goal_minutes: input.daily_goal_minutes,
  }));
  return readProfile();
}

export async function updateOwnProfile(input: ProfileChanges): Promise<Profile> {
  const userId = await ownedId();
  const changes: ProfileChanges = { ...input };
  if ('display_name' in changes) {
    const name = changes.display_name?.trim() ?? '';
    if (!name || name.length > 50) throw new ApiError(422, 'Display name must contain 1-50 characters.');
    changes.display_name = name;
  }
  if (typeof changes.username === 'string') {
    changes.username = changes.username.trim().toLowerCase();
    if (!/^[a-z0-9_]{3,30}$/.test(changes.username)) throw new ApiError(422, 'Username must contain 3-30 lowercase letters, numbers or underscores.');
  }
  if (typeof changes.bio === 'string') {
    changes.bio = changes.bio.trim() || null;
    if (changes.bio && changes.bio.length > 160) throw new ApiError(422, 'Bio must contain at most 160 characters.');
  }
  if (changes.avatar_url !== undefined && changes.avatar_url !== null &&
      (!changes.avatar_url.startsWith(`${userId}/`) || !changes.avatar_url.endsWith('.jpg') || changes.avatar_url.length > 150)) {
    throw new ApiError(422, 'Avatar must be an owned JPEG storage path.');
  }
  if (Object.keys(changes).length) {
    dataOrThrow<{ id: string }>(await getSupabase().from('profiles')
      .update(changes).eq('id', userId).select('id').maybeSingle());
  }
  return readProfile();
}

export async function updateOwnPreferences(input: PreferenceChanges): Promise<Profile> {
  const userId = await ownedId();
  const changes: PreferenceChanges & { initial_proficiency?: 'beginner' | 'intermediate' | 'advanced' } = { ...input };
  if ('daily_goal_minutes' in changes && (!Number.isInteger(changes.daily_goal_minutes) || (changes.daily_goal_minutes ?? 0) < 1 || (changes.daily_goal_minutes ?? 0) > 180)) {
    throw new ApiError(422, 'Daily study duration must be between 1 and 180 minutes.');
  }
  for (const field of ['learning_goal', 'daily_goal_minutes', 'preferred_accent', 'interface_language'] as const) {
    if (field in changes && changes[field] === null) throw new ApiError(422, `${field} cannot be null.`);
  }
  if (changes.current_cefr) {
    changes.initial_proficiency = ['A1', 'A2'].includes(changes.current_cefr) ? 'beginner'
      : ['B1', 'B2'].includes(changes.current_cefr) ? 'intermediate' : 'advanced';
  }
  if (Object.keys(changes).length) {
    const result = await getSupabase().from('user_preferences')
      .update(changes).eq('user_id', userId).select('user_id').maybeSingle();
    if (!result.error && result.data === null) throw new ApiError(409, 'Complete onboarding before editing preferences.');
    errorOrThrow(result);
  }
  return readProfile();
}
