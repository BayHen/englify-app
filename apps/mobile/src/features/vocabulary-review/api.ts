import { getSupabase } from '@/auth/supabase';
import { currentUserId, dataOrThrow } from '@/lib/supabase-query';

export type RecallRating = 1 | 2 | 3 | 4;
export type DueVocabulary = {
  id: string; entry_id: string; term: string; translation: string | null; definition: string;
  ipa: string | null; part_of_speech: string | null; example: string | null; example_vi: string | null;
  next_review_at: string; review_count: number; stability: number; difficulty: number;
};
export type ReviewResult = {
  saved_vocabulary_id: string; rating: RecallRating; next_review_at: string; review_count: number;
  lapse_count: number; stability: number; difficulty: number; algorithm_version: number;
};

export async function listDueVocabulary(limit = 20): Promise<DueVocabulary[]> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_due_vocabulary', { p_limit: limit })) as DueVocabulary[];
}

export async function reviewVocabulary(savedVocabularyId: string, rating: RecallRating, requestId: string): Promise<ReviewResult> {
  await currentUserId();
  return dataOrThrow(await getSupabase().rpc('englify_review_vocabulary', {
    p_saved_vocabulary_id: savedVocabularyId, p_rating: rating, p_request_id: requestId,
  })) as ReviewResult;
}
