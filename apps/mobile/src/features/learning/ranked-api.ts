import { getSupabase } from '@/auth/supabase';
import { currentUserId, dataOrThrow } from '@/lib/supabase-query';
import type { ArenaAnswer, ArenaQuestion, ArenaReview } from './arena-api';
import { captureServerClock, type ServerClock } from './time-attack-clock';

export type ArenaTier = 'bronze'|'silver'|'gold'|'platinum'|'diamond';
export type RankedMatch = {
  id: string; season_id: string; ruleset_version: number; status: 'active'|'completed'|'expired'|'abandoned'|'invalid';
  completion_reason: 'all_questions'|'time_expired'|'no_lives'|'abandoned'|'invalid'|null;
  question_count: number; time_limit_seconds: number; initial_lives: number; remaining_lives: number;
  answered_count: number; correct_count: number; combo: number; max_combo: number; score: number;
  rating_before: number|null; rating_after: number|null; rating_change: number|null; started_at: string; expires_at: string;
  question_started_at: string|null; completed_at: string|null; duration_ms: number|null; suspicious: boolean;
  cefr_level: string; current_question: ArenaQuestion|null;
  last_answer: { question_id:string; position:number; correct:boolean; combo:number; points:number; speed_bonus:number }|null;
  review: (ArenaReview & { points:number })[]|null;
};
export type RankedSnapshot = { match: RankedMatch; clock: ServerClock };
type RankedEnvelope = { server_now:string; match: Omit<RankedMatch,'cefr_level'|'current_question'|'last_answer'|'review'>; cefr_level:string; current_question:ArenaQuestion|null; last_answer:RankedMatch['last_answer']; review:RankedMatch['review'] };
export type RankedProfile = { rating:number; peak_rating:number; matches_played:number; tier:ArenaTier; peak_tier:ArenaTier; next_tier_rating:number|null;
  season:{id:string;code:string;title:string;ruleset_version:number;status:string;starts_at:string;ends_at:string}|null;
  recent_changes:{rating_before:number;rating_after:number;rating_change:number;reason:string;created_at:string}[] };
export type RankedHistory = { page:number; total:number; items:(Pick<RankedMatch,'id'|'season_id'|'ruleset_version'|'status'|'completion_reason'|'score'|'correct_count'|'answered_count'|'question_count'|'max_combo'|'rating_before'|'rating_after'|'rating_change'|'started_at'|'completed_at'> & {season_title:string})[] };
export type Leaderboard = { scope:'weekly'|'season';page:number;page_size:number;total:number;starts_at:string;ends_at:string;season_id:string;my_position:number|null;items:{position:number;display_name:string;tier:ArenaTier;rating:number;score:number;correct:number;questions:number;matches:number;is_me:boolean}[] };

async function snapshot(name:string,args:Record<string,unknown>):Promise<RankedSnapshot>{
  await currentUserId(); const sent=performance.now(); const raw=dataOrThrow(await getSupabase().rpc(name,args)) as RankedEnvelope;
  const match={...raw.match,cefr_level:raw.cefr_level,current_question:raw.current_question,last_answer:raw.last_answer,review:raw.review};
  return {match,clock:captureServerClock(match.expires_at,raw.server_now,sent,performance.now())};
}
export const startRanked=(requestId:string)=>snapshot('englify_ranked_start',{p_request_id:requestId});
export const getRanked=(id:string)=>snapshot('englify_ranked_session',{p_match_id:id});
export const answerRanked=(id:string,questionId:string,requestId:string,answer:ArenaAnswer)=>snapshot('englify_ranked_answer',{p_match_id:id,p_question_id:questionId,p_request_id:requestId,p_answer:answer});
export const finalizeRanked=(id:string,abandon=false)=>snapshot('englify_ranked_finalize',{p_match_id:id,p_abandon:abandon});
export async function getRankedProfile(){await currentUserId();return dataOrThrow(await getSupabase().rpc('englify_ranked_me')) as RankedProfile;}
export async function getRankedHistory(page=1){await currentUserId();return dataOrThrow(await getSupabase().rpc('englify_ranked_history',{p_page:page})) as RankedHistory;}
export async function getLeaderboard(scope:'weekly'|'season',page=1,seasonId?:string){await currentUserId();return dataOrThrow(await getSupabase().rpc('englify_ranked_leaderboard',{p_scope:scope,p_page:page,p_season_id:seasonId??null})) as Leaderboard;}

