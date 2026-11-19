import { beforeEach,describe,expect,it,vi } from 'vitest';
import { answerRanked,finalizeRanked,getLeaderboard,getRanked,getRankedHistory,getRankedProfile,startRanked } from './ranked-api';
const state=vi.hoisted(()=>({client:null as unknown}));
vi.mock('@/auth/supabase',()=>({getSupabase:()=>state.client}));
const auth={getSession:async()=>({data:{session:{user:{id:'learner'}}},error:null})};
const envelope={server_now:'2026-11-18T00:00:00Z',match:{id:'match',expires_at:'2026-11-18T00:02:00Z'},cefr_level:'B1',current_question:null,last_answer:null,review:null};
beforeEach(()=>{state.client=null;});
describe('Ranked API integrity',()=>{
 it('starts using only an idempotency key, never client rules or rating',async()=>{const rpc=vi.fn().mockResolvedValue({data:envelope,error:null,status:200});state.client={auth,rpc};const value=await startRanked('stable');expect(rpc).toHaveBeenCalledWith('englify_ranked_start',{p_request_id:'stable'});expect(value.match.id).toBe('match');});
 it('submits only the current answer identity and body',async()=>{const rpc=vi.fn().mockResolvedValue({data:envelope,error:null,status:200});state.client={auth,rpc};await answerRanked('match','question','stable','choice');expect(rpc).toHaveBeenCalledWith('englify_ranked_answer',{p_match_id:'match',p_question_id:'question',p_request_id:'stable',p_answer:'choice'});});
 it('restores and finalizes without accepting score or rating fields',async()=>{const rpc=vi.fn().mockResolvedValue({data:envelope,error:null,status:200});state.client={auth,rpc};await getRanked('match');await finalizeRanked('match');await finalizeRanked('match',true);expect(rpc.mock.calls).toEqual([['englify_ranked_session',{p_match_id:'match'}],['englify_ranked_finalize',{p_match_id:'match',p_abandon:false}],['englify_ranked_finalize',{p_match_id:'match',p_abandon:true}]]);});
 it('uses owner/public projections for profile, history and boards',async()=>{const rpc=vi.fn().mockResolvedValue({data:{},error:null,status:200});state.client={auth,rpc};await getRankedProfile();await getRankedHistory(2);await getLeaderboard('weekly',3);expect(rpc.mock.calls).toEqual([['englify_ranked_me'],['englify_ranked_history',{p_page:2}],['englify_ranked_leaderboard',{p_scope:'weekly',p_page:3,p_season_id:null}]]);});
 it('retries an uncertain answer with the exact same request',async()=>{const rpc=vi.fn().mockResolvedValueOnce({data:null,error:{message:'timeout'},status:0}).mockResolvedValueOnce({data:envelope,error:null,status:200});state.client={auth,rpc};await expect(answerRanked('match','q','stable','answer')).rejects.toThrow();await answerRanked('match','q','stable','answer');expect(rpc.mock.calls[0]).toEqual(rpc.mock.calls[1]);});
});
