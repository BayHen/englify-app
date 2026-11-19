import { useCallback, useEffect, useRef, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import { AppState, Platform } from 'react-native';
import { randomUUID } from 'expo-crypto';
import type { ArenaAnswer } from './arena-api';
import { answerRanked, finalizeRanked, getRanked, type RankedSnapshot } from './ranked-api';
type Pending={questionId:string;requestId:string;position:number;answer:ArenaAnswer};
export function useRankedSession(id:string){
 const [snapshot,setSnapshot]=useState<RankedSnapshot|null>(null);const [busy,setBusy]=useState(false);const [synced,setSynced]=useState(false);const [visible,setVisible]=useState(true);const [error,setError]=useState('');const [pending,setPending]=useState<Pending|null>(null);
 const alive=useRef(true),focused=useRef(false),visibleRef=useRef(true),epoch=useRef(0),flight=useRef(false);const queued=useRef<(()=>void)|null>(null),pendingRef=useRef<Pending|null>(null);
 const run=useCallback(async(op:()=>Promise<RankedSnapshot>)=>{if(flight.current||!alive.current)return null;flight.current=true;const started=epoch.current;setBusy(true);setError('');try{const value=await op();if(!alive.current)return null;setSnapshot(value);setSynced(started===epoch.current&&visibleRef.current);if(pendingRef.current&&(value.match.answered_count>=pendingRef.current.position||value.match.status!=='active')){pendingRef.current=null;setPending(null);}return value;}catch(cause){if(alive.current)setError(cause instanceof Error?cause.message:'Could not synchronize Ranked Arena.');return null;}finally{flight.current=false;if(alive.current){setBusy(false);const next=queued.current;queued.current=null;next?.();}}},[]);
 const refresh=useCallback(function sync(){if(!alive.current||!visibleRef.current)return;setSynced(false);if(flight.current){queued.current=sync;return;}void run(()=>getRanked(id));},[id,run]);
 useEffect(()=>{alive.current=true;const update=()=>{const foreground=focused.current&&(AppState.currentState==='active'||AppState.currentState===null)&&(Platform.OS!=='web'||typeof document==='undefined'||document.visibilityState!=='hidden');epoch.current+=1;visibleRef.current=foreground;setVisible(foreground);setSynced(false);if(foreground)refresh();};const sub=AppState.addEventListener('change',update);if(Platform.OS==='web'&&typeof document!=='undefined')document.addEventListener('visibilitychange',update);return()=>{alive.current=false;epoch.current+=1;sub.remove();if(Platform.OS==='web'&&typeof document!=='undefined')document.removeEventListener('visibilitychange',update);};},[refresh]);
 useFocusEffect(useCallback(()=>{focused.current=true;epoch.current+=1;visibleRef.current=(AppState.currentState==='active'||AppState.currentState===null)&&(Platform.OS!=='web'||typeof document==='undefined'||document.visibilityState!=='hidden');setVisible(visibleRef.current);refresh();return()=>{focused.current=false;visibleRef.current=false;epoch.current+=1;setVisible(false);setSynced(false);};},[refresh]));
 const submit=useCallback((questionId:string,position:number,answer:ArenaAnswer)=>{if(!visibleRef.current||!synced||flight.current)return Promise.resolve(null);const request=pendingRef.current??{questionId,requestId:randomUUID(),position,answer};pendingRef.current=request;setPending(request);return run(()=>answerRanked(id,request.questionId,request.requestId,request.answer));},[id,run,synced]);
 const finish=useCallback((abandon=false)=>run(()=>finalizeRanked(id,abandon)),[id,run]);return{snapshot,busy,synced,visible,error,pending,refresh,submit,finish};
}

