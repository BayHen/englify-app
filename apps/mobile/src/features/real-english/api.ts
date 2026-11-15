import { getSupabase } from '@/auth/supabase';
import { ApiError } from '@/lib/api';
import { currentUserId, dataOrThrow, errorOrThrow } from '@/lib/supabase-query';
import { normalizeSearchText } from './library-utils';

export type ExpressionKind = 'slang' | 'idiom' | 'phrasal_verb' | 'casual_expression' | 'everyday_conversation' | 'movie_style_dialogue';
export type DialogueLine = { speaker: string; line: string };
export type Expression = { id: string; slug: string; kind: ExpressionKind; expression: string; meaning_vi: string; context_explanation: string; example_en: string; example_vi: string; dialogue: DialogueLine[]; formality: 'informal' | 'neutral' | 'formal'; region_note: string; source_name: string; license_id: string; provenance_note: string; saved: boolean };
export type ContextQuiz = { id: string; expression_id: string; prompt: string; options: { id: string; text: string }[] };
export type QuizResult = { attempt_id: string; question_id: string; is_correct: boolean; correct_option: string; explanation: string; created_at: string };

const COLUMNS = 'id,slug,kind,expression,meaning_vi,context_explanation,example_en,example_vi,dialogue,formality,region_note,source_name,license_id,provenance_note';
const published = () => getSupabase().from('real_english_expressions').select(COLUMNS).eq('is_published', true).is('archived_at', null);

async function expression(id: string): Promise<Expression> {
  const [row, saved] = await Promise.all([
    published().eq('id', id).maybeSingle(),
    getSupabase().from('saved_expressions').select('id').eq('expression_id', id).maybeSingle(),
  ]);
  errorOrThrow(saved);
  return { ...dataOrThrow(row), saved: !!saved.data } as Expression;
}

export async function searchExpressions(query = '', kind?: ExpressionKind, savedOnly = false): Promise<Expression[]> {
  const userId = await currentUserId();
  const term = query.trim();
  if (term.length > 80) throw new ApiError(422, 'Search term is too long.');
  const saves = dataOrThrow(await getSupabase().from('saved_expressions').select('expression_id').eq('user_id', userId));
  const savedIds = new Set(saves.map((row) => row.expression_id));
  if (savedOnly && !savedIds.size) return [];
  let rows: Record<string, unknown>[];
  if (term) {
    let request = published();
    if (kind) request = request.eq('kind', kind);
    if (savedOnly) request = request.in('id', [...savedIds]);
    const normalizedTerm = normalizeSearchText(term);
    rows = dataOrThrow(await request.order('expression').limit(1000)).filter((row) => normalizeSearchText([
      row.expression, row.meaning_vi, row.context_explanation, row.example_en, row.example_vi,
      row.region_note, JSON.stringify(row.dialogue ?? []),
    ].map((value) => String(value ?? '')).join(' ')).includes(normalizedTerm));
  } else {
    let request = published();
    if (kind) request = request.eq('kind', kind);
    if (savedOnly) request = request.in('id', [...savedIds]);
    rows = dataOrThrow(await request.order('expression').limit(50));
  }
  const unique = new Map(rows.map((row) => [String(row.id), row]));
  return [...unique.values()].sort((a, b) => String(a.expression).localeCompare(String(b.expression)))
    .slice(0, 30).map((row) => ({ ...row, saved: savedIds.has(String(row.id)) })) as Expression[];
}
export async function saveExpression(id: string): Promise<Expression> {
  const userId = await currentUserId();
  await expression(id);
  errorOrThrow(await getSupabase().from('saved_expressions')
    .upsert({ user_id: userId, expression_id: id }, { onConflict: 'user_id,expression_id', ignoreDuplicates: true }));
  return expression(id);
}
export async function unsaveExpression(id: string): Promise<Expression> {
  const userId = await currentUserId();
  await expression(id);
  errorOrThrow(await getSupabase().from('saved_expressions').delete().eq('user_id', userId).eq('expression_id', id));
  return expression(id);
}
export async function getContextQuiz(id: string): Promise<ContextQuiz> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_context_quiz', { p_expression_id: id })) as ContextQuiz;
}
export async function submitContextQuiz(id: string, requestId: string, option: string): Promise<QuizResult> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_submit_context_quiz', {
    p_expression_id: id, p_request_id: requestId, p_selected_option: option,
  })) as QuizResult;
}
