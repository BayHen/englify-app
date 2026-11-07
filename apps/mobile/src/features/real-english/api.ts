import { privateRequest } from '@/auth/api';
import { getSupabase } from '@/auth/supabase';

export type ExpressionKind = 'slang' | 'idiom' | 'phrasal_verb' | 'casual_expression' | 'everyday_conversation' | 'movie_style_dialogue';
export type DialogueLine = { speaker: string; line: string };
export type Expression = { id: string; slug: string; kind: ExpressionKind; expression: string; meaning_vi: string; context_explanation: string; example_en: string; example_vi: string; dialogue: DialogueLine[]; formality: 'informal' | 'neutral' | 'formal'; region_note: string; source_name: string; license_id: string; provenance_note: string; saved: boolean };
export type ContextQuiz = { id: string; expression_id: string; prompt: string; options: { id: string; text: string }[] };
export type QuizResult = { attempt_id: string; question_id: string; is_correct: boolean; correct_option: string; explanation: string; created_at: string };

async function token(): Promise<string> {
  const { data, error } = await getSupabase().auth.getSession();
  if (error || !data.session) throw new Error('Session expired. Please sign in again.');
  return data.session.access_token;
}
export async function searchExpressions(query = '', kind?: ExpressionKind, savedOnly = false): Promise<Expression[]> {
  const params = new URLSearchParams({ q: query, saved_only: String(savedOnly) });
  if (kind) params.set('kind', kind);
  return privateRequest(`/real-english?${params.toString()}`, await token());
}
export async function saveExpression(id: string): Promise<Expression> { return privateRequest(`/real-english/${encodeURIComponent(id)}/save`, await token(), 'POST'); }
export async function unsaveExpression(id: string): Promise<Expression> { return privateRequest(`/real-english/${encodeURIComponent(id)}/save`, await token(), 'DELETE'); }
export async function getContextQuiz(id: string): Promise<ContextQuiz> { return privateRequest(`/real-english/${encodeURIComponent(id)}/quiz`, await token()); }
export async function submitContextQuiz(id: string, requestId: string, option: string): Promise<QuizResult> {
  return privateRequest(`/real-english/${encodeURIComponent(id)}/quiz`, await token(), 'POST', { request_id: requestId, selected_option: option });
}
