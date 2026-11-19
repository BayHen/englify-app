import { useCallback,useEffect,useRef,useState } from 'react';
import { AppState } from 'react-native';
import * as Network from 'expo-network';
import { randomUUID } from 'expo-crypto';
import type { Exercise } from './api';
import { cacheWritingExercises,deleteWritingDraft,getCachedWritingExercise,getWritingDraft,listCachedWritingExercises,
  listWritingDrafts,saveWritingDraft,writingDraftContext,type WritingDraft,type WritingDraftSummary } from './draft-storage';

export type DraftSaveStatus='idle'|'saving'|'saved'|'error';
type Pending={draft:WritingDraft}|null;

export function useWritingDrafts(userId:string|null){
  const [status,setStatus]=useState<DraftSaveStatus>('idle');const [online,setOnline]=useState(true);const [summaries,setSummaries]=useState<WritingDraftSummary[]>([]);
  const current=useRef<{contextKey:string;exerciseId:string;assignmentId:string|null;createdAt:string;revision:number}|null>(null);
  const saving=useRef<Promise<WritingDraft|null>>(Promise.resolve(null));
  const pending=useRef<Pending>(null);const timer=useRef<ReturnType<typeof setTimeout>|null>(null);const loadSequence=useRef(0);const mounted=useRef(true);
  const refresh=useCallback(async()=>{if(!userId)return;const rows=await listWritingDrafts(userId);if(mounted.current)setSummaries(rows);},[userId]);
  const flush=useCallback(()=>{if(timer.current){clearTimeout(timer.current);timer.current=null;}const value=pending.current;if(!value)return saving.current;
    const task=saving.current.then(async()=>{
      try{if(mounted.current)setStatus('saving');const saved=await saveWritingDraft(value.draft);if(pending.current===value)pending.current=null;
        if(mounted.current)setStatus(pending.current?'saving':'saved');await refresh();return saved;
      }catch{if(mounted.current)setStatus('error');return null;}
    });saving.current=task;return task;
  },[refresh]);
  useEffect(()=>{mounted.current=true;current.current=null;pending.current=null;void refresh();const network=Network.addNetworkStateListener(state=>setOnline(Boolean(state.isConnected&&state.isInternetReachable!==false)));
    void Network.getNetworkStateAsync().then(state=>setOnline(Boolean(state.isConnected&&state.isInternetReachable!==false))).catch(()=>setOnline(false));
    const app=AppState.addEventListener('change',state=>{if(state!=='active')void flush();});
    return()=>{mounted.current=false;network.remove();app.remove();void flush();};},[flush,refresh]);
  const activate=useCallback(async(exercise:Exercise,assignmentId:string|null):Promise<WritingDraft|null|undefined>=>{if(!userId)return undefined;await flush();const sequence=++loadSequence.current;
    const contextKey=writingDraftContext(exercise.id,assignmentId);current.current={contextKey,exerciseId:exercise.id,assignmentId,createdAt:new Date().toISOString(),revision:0};pending.current=null;
    await cacheWritingExercises(userId,[exercise]).catch(()=>undefined);const restored=await getWritingDraft(userId,contextKey).catch(()=>null);
    if(sequence!==loadSequence.current||current.current?.contextKey!==contextKey||current.current.revision>0)return undefined;
    current.current={contextKey,exerciseId:exercise.id,assignmentId,createdAt:restored?.createdAt??new Date().toISOString(),revision:restored?.revision??0};setStatus(restored?'saved':'idle');return restored;
  },[flush,userId]);
  const change=useCallback((content:string,selectedTokens:number[])=>{if(!userId||!current.current)return;const now=new Date().toISOString();current.current.revision+=1;
    pending.current={draft:{id:`draft-${randomUUID()}`,userId,contextKey:current.current.contextKey,exerciseId:current.current.exerciseId,
      challengeAssignmentId:current.current.assignmentId,content,selectedTokens,createdAt:current.current.createdAt,updatedAt:now,revision:current.current.revision}};
    setStatus('saving');if(timer.current)clearTimeout(timer.current);timer.current=setTimeout(()=>{void flush();},750);
  },[flush,userId]);
  const discard=useCallback(async(contextKey:string)=>{if(!userId)return;if(current.current?.contextKey===contextKey){pending.current=null;if(timer.current)clearTimeout(timer.current);timer.current=null;
      current.current.createdAt=new Date().toISOString();setStatus('idle');}
    // Queue deletion behind saves already in flight, and before subsequent edits.
    const removal=saving.current.then(async()=>{await deleteWritingDraft(userId,contextKey);await refresh();});
    saving.current=removal.then(()=>null,()=>null);await removal;
  },[refresh,userId]);
  const clearSubmitted=useCallback(async(contextKey:string,revision:number)=>{if(!userId)return;
    // Persist pending edits first; the revision guard keeps anything typed after submit.
    const removal=flush().then(async()=>{await deleteWritingDraft(userId,contextKey,revision);await refresh();});
    saving.current=removal.then(()=>null,()=>null);await removal;
  },[flush,refresh,userId]);
  const submittedRevision=useCallback(()=>current.current?.revision??0,[]);
  const cacheExercises=useCallback((items:Exercise[])=>userId?cacheWritingExercises(userId,items):Promise.resolve(),[userId]);
  const cachedExercises=useCallback(()=>userId?listCachedWritingExercises(userId):Promise.resolve([]),[userId]);
  const cachedExercise=useCallback((exerciseId:string)=>userId?getCachedWritingExercise(userId,exerciseId):Promise.resolve(null),[userId]);
  return{status,online,summaries:summaries.filter(item=>item.userId===userId),activate,change,flush,discard,clearSubmitted,submittedRevision,refresh,
    cacheExercises,cachedExercises,cachedExercise};
}
