import type { Exercise } from './api';
import type { WritingDraft, WritingDraftSummary } from './draft-storage';

const memory=new Map<string,string>();
const words=(value:string)=>value.trim()?value.trim().split(/\s+/).length:0;
export const writingDraftContext=(exerciseId:string,assignmentId:string|null)=>assignmentId?`daily:${assignmentId}`:`exercise:${exerciseId}`;
function read(key:string){try{return globalThis.localStorage?.getItem(key)??memory.get(key)??null;}catch{return memory.get(key)??null;}}
function write(key:string,value:string){if(!globalThis.localStorage){memory.set(key,value);return;}try{globalThis.localStorage.setItem(key,value);}catch{throw new Error('Local draft storage is unavailable.');}
  if(globalThis.localStorage.getItem(key)!==value)throw new Error('Local draft storage is unavailable.');}
function remove(key:string){memory.delete(key);try{globalThis.localStorage?.removeItem(key);}catch{throw new Error('Local draft storage is unavailable.');}}
const draftKey=(userId:string,contextKey:string)=>`englify:writing:draft:${userId}:${contextKey}`;
const indexKey=(userId:string)=>`englify:writing:draft-index:${userId}`;
const cacheKey=(userId:string,exerciseId:string)=>`englify:writing:exercise:${userId}:${exerciseId}`;
const cacheIndexKey=(userId:string)=>`englify:writing:exercise-index:${userId}`;
function parse<T>(value:string|null):T|null{if(!value)return null;try{return JSON.parse(value) as T;}catch{return null;}}
function ids(userId:string){return parse<string[]>(read(indexKey(userId)))??[];}
export async function getWritingDraft(userId:string,contextKey:string){const value=parse<WritingDraft>(read(draftKey(userId,contextKey)));if(!value)return null;
  if(value.userId!==userId||value.contextKey!==contextKey||!Number.isInteger(value.revision)||typeof value.content!=='string'){remove(draftKey(userId,contextKey));return null;}return value;}
export async function saveWritingDraft(value:WritingDraft){const current=await getWritingDraft(value.userId,value.contextKey);if(current&&current.revision>=value.revision)return current;
  write(draftKey(value.userId,value.contextKey),JSON.stringify(value));const next=[value.contextKey,...ids(value.userId).filter(item=>item!==value.contextKey)];write(indexKey(value.userId),JSON.stringify(next));return value;}
export async function deleteWritingDraft(userId:string,contextKey:string,maxRevision?:number){const current=await getWritingDraft(userId,contextKey);if(!current||maxRevision!==undefined&&current.revision>maxRevision)return;
  remove(draftKey(userId,contextKey));write(indexKey(userId),JSON.stringify(ids(userId).filter(item=>item!==contextKey)));}
export async function listWritingDrafts(userId:string):Promise<WritingDraftSummary[]>{const values=await Promise.all(ids(userId).slice(0,100).map(key=>getWritingDraft(userId,key)));
  return values.filter((item):item is WritingDraft=>item!==null&&item.userId===userId).map(item=>({...item,content:undefined,selectedTokens:undefined,
    preview:item.content.slice(0,160),wordCount:words(item.content),exercise:parse<Exercise>(read(cacheKey(userId,item.exerciseId)))}) as unknown as WritingDraftSummary)
    .sort((a,b)=>b.updatedAt.localeCompare(a.updatedAt));}
export async function cacheWritingExercises(userId:string,exercises:Exercise[]){const known=parse<string[]>(read(cacheIndexKey(userId)))??[];for(const exercise of exercises)write(cacheKey(userId,exercise.id),JSON.stringify(exercise));write(cacheIndexKey(userId),JSON.stringify([...new Set([...known,...exercises.map(item=>item.id)])].slice(-100)));}
export async function getCachedWritingExercise(userId:string,exerciseId:string){return parse<Exercise>(read(cacheKey(userId,exerciseId)));}
export async function listCachedWritingExercises(userId:string){const exerciseIds=parse<string[]>(read(cacheIndexKey(userId)))??[];const values=exerciseIds.map(id=>parse<Exercise>(read(cacheKey(userId,id))));return values.filter((item):item is Exercise=>item!==null);}
