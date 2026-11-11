import { privateRequest } from '@/auth/api';
import { getSupabase } from '@/auth/supabase';
import { currentUserId, dataOrThrow } from '@/lib/supabase-query';

export type Exercise = { id: string; kind: 'sentence' | 'fill_blank' | 'sentence_order' | 'paragraph'; prompt: string; hint: string; tokens: string[] };
export type GrammarMatch = { message: string; offset: number; length: number; replacements: string[] };
export type Feedback = { rule_result: 'matched' | 'needs_revision' | 'self_review'; suggestions: string[]; grammar_status: 'not_requested' | 'available' | 'unavailable'; grammar_matches: GrammarMatch[] };
export type Submission = { id: string; exercise_id: string | null; prompt: string; body: string; created_at: string; feedback: Feedback | null };

async function token(): Promise<string> {
  const { data, error } = await getSupabase().auth.getSession();
  if (error || !data.session) throw new Error('Session expired. Please sign in again.');
  return data.session.access_token;
}
const writingSupabaseEnabled = () => process.env.EXPO_PUBLIC_SUPABASE_WRITING_ENABLED === 'true';

export async function getExercises(): Promise<Exercise[]> {
  if (!writingSupabaseEnabled()) return privateRequest('/writing/exercises', await token());
  await currentUserId();
  return dataOrThrow(await getSupabase().from('writing_exercises').select('id,kind,prompt,hint,tokens')
    .eq('is_published', true).order('kind').order('id')) as Exercise[];
}
export async function getWritingHistory(): Promise<Submission[]> {
  if (!writingSupabaseEnabled()) return privateRequest('/writing/history', await token());
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_writing_history', { p_limit: 30 })) as Submission[];
}
export async function submitWriting(requestId: string, exerciseId: string, body: string, grammarCheck: boolean): Promise<Submission> {
  if (!writingSupabaseEnabled()) return privateRequest('/writing/submit', await token(), 'POST', { request_id: requestId, exercise_id: exerciseId, body, grammar_check: grammarCheck });
  await currentUserId();
  const saved = dataOrThrow(await getSupabase().rpc('englify_submit_writing', {
    p_request_id: requestId, p_exercise_id: exerciseId, p_body: body, p_grammar_check: grammarCheck,
  })) as Submission;
  if (!grammarCheck) return saved;
  try {
    const { data, error } = await getSupabase().functions.invoke<{ status: 'available' | 'unavailable' }>(
      'writing-grammar', { body: { submissionId: saved.id } });
    if (error || data?.status !== 'available') return saved;
    return dataOrThrow(await getSupabase().rpc('englify_writing_submission', { p_submission_id: saved.id })) as Submission;
  } catch { return saved; } // Rule feedback and original text already persist.
}
