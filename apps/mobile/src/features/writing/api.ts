import { privateRequest } from '@/auth/api';
import { getSupabase } from '@/auth/supabase';

export type Exercise = { id: string; kind: 'sentence' | 'fill_blank' | 'sentence_order' | 'paragraph'; prompt: string; hint: string; tokens: string[] };
export type GrammarMatch = { message: string; offset: number; length: number; replacements: string[] };
export type Feedback = { rule_result: 'matched' | 'needs_revision' | 'self_review'; suggestions: string[]; grammar_status: 'not_requested' | 'available' | 'unavailable'; grammar_matches: GrammarMatch[] };
export type Submission = { id: string; exercise_id: string | null; prompt: string; body: string; created_at: string; feedback: Feedback | null };

async function token(): Promise<string> {
  const { data, error } = await getSupabase().auth.getSession();
  if (error || !data.session) throw new Error('Session expired. Please sign in again.');
  return data.session.access_token;
}
export async function getExercises(): Promise<Exercise[]> { return privateRequest('/writing/exercises', await token()); }
export async function getWritingHistory(): Promise<Submission[]> { return privateRequest('/writing/history', await token()); }
export async function submitWriting(requestId: string, exerciseId: string, body: string, grammarCheck: boolean): Promise<Submission> {
  return privateRequest('/writing/submit', await token(), 'POST', { request_id: requestId, exercise_id: exerciseId, body, grammar_check: grammarCheck });
}
