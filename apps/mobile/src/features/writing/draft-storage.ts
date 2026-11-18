import * as SQLite from 'expo-sqlite';
import type { Exercise } from './api';

export type WritingDraft = { id:string; userId:string; contextKey:string; exerciseId:string; challengeAssignmentId:string|null;
  content:string; selectedTokens:number[]; createdAt:string; updatedAt:string; revision:number };
export type WritingDraftSummary = Omit<WritingDraft,'content'|'selectedTokens'> & { preview:string; wordCount:number;
  exercise:Exercise|null };

let database:Promise<SQLite.SQLiteDatabase>|null=null;
const words=(value:string)=>value.trim()?value.trim().split(/\s+/).length:0;
export const writingDraftContext=(exerciseId:string,assignmentId:string|null)=>assignmentId?`daily:${assignmentId}`:`exercise:${exerciseId}`;

async function db(){database??=(async()=>{const handle=await SQLite.openDatabaseAsync('englify-writing.db');
  const version=(await handle.getFirstAsync<{user_version:number}>('PRAGMA user_version'))?.user_version??0;
  if(version<1){await handle.execAsync(`PRAGMA journal_mode=WAL;
    CREATE TABLE IF NOT EXISTS writing_drafts (
      id TEXT PRIMARY KEY,user_id TEXT NOT NULL,context_key TEXT NOT NULL,exercise_id TEXT NOT NULL,
      challenge_assignment_id TEXT,content TEXT NOT NULL,selected_tokens TEXT NOT NULL DEFAULT '[]',
      word_count INTEGER NOT NULL DEFAULT 0,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,revision INTEGER NOT NULL,
      UNIQUE(user_id,context_key));
    CREATE INDEX IF NOT EXISTS writing_drafts_user_updated ON writing_drafts(user_id,updated_at DESC);
    CREATE TABLE IF NOT EXISTS writing_exercise_cache (
      user_id TEXT NOT NULL,exercise_id TEXT NOT NULL,value TEXT NOT NULL,updated_at TEXT NOT NULL,
      PRIMARY KEY(user_id,exercise_id));
    PRAGMA user_version=1;`);}
  return handle;})();return database;}
function rowDraft(row:{id:string;user_id:string;context_key:string;exercise_id:string;challenge_assignment_id:string|null;content:string;
  selected_tokens:string;created_at:string;updated_at:string;revision:number}):WritingDraft{return{id:row.id,userId:row.user_id,
  contextKey:row.context_key,exerciseId:row.exercise_id,challengeAssignmentId:row.challenge_assignment_id,content:row.content,
  selectedTokens:parseTokens(row.selected_tokens),createdAt:row.created_at,updatedAt:row.updated_at,revision:row.revision};}
function parseTokens(value:string){try{const parsed=JSON.parse(value);return Array.isArray(parsed)?parsed.filter(item=>Number.isInteger(item)):[];}catch{return [];}}
export async function getWritingDraft(userId:string,contextKey:string):Promise<WritingDraft|null>{const row=await(await db()).getFirstAsync<any>(
  'SELECT * FROM writing_drafts WHERE user_id=? AND context_key=?',userId,contextKey);return row?rowDraft(row):null;}
export async function saveWritingDraft(value:WritingDraft):Promise<WritingDraft>{const handle=await db();await handle.runAsync(
  `INSERT INTO writing_drafts(id,user_id,context_key,exercise_id,challenge_assignment_id,content,selected_tokens,word_count,created_at,updated_at,revision)
   VALUES(?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(user_id,context_key) DO UPDATE SET
   id=excluded.id,exercise_id=excluded.exercise_id,challenge_assignment_id=excluded.challenge_assignment_id,
   content=excluded.content,selected_tokens=excluded.selected_tokens,word_count=excluded.word_count,
   updated_at=excluded.updated_at,revision=excluded.revision WHERE excluded.revision>writing_drafts.revision`,
  value.id,value.userId,value.contextKey,value.exerciseId,value.challengeAssignmentId,value.content,JSON.stringify(value.selectedTokens),
  words(value.content),value.createdAt,value.updatedAt,value.revision);return(await getWritingDraft(value.userId,value.contextKey))!;}
export async function deleteWritingDraft(userId:string,contextKey:string,maxRevision?:number){const handle=await db();if(maxRevision===undefined)
  await handle.runAsync('DELETE FROM writing_drafts WHERE user_id=? AND context_key=?',userId,contextKey);
  else await handle.runAsync('DELETE FROM writing_drafts WHERE user_id=? AND context_key=? AND revision<=?',userId,contextKey,maxRevision);}
export async function listWritingDrafts(userId:string):Promise<WritingDraftSummary[]>{const rows=await(await db()).getAllAsync<any>(
  `SELECT d.id,d.user_id,d.context_key,d.exercise_id,d.challenge_assignment_id,d.word_count,d.created_at,d.updated_at,d.revision,
   substr(d.content,1,160) preview,c.value exercise_value FROM writing_drafts d LEFT JOIN writing_exercise_cache c
   ON c.user_id=d.user_id AND c.exercise_id=d.exercise_id WHERE d.user_id=? ORDER BY d.updated_at DESC LIMIT 100`,userId);
  return rows.map(row=>({id:row.id,userId:row.user_id,contextKey:row.context_key,exerciseId:row.exercise_id,
    challengeAssignmentId:row.challenge_assignment_id,preview:row.preview,wordCount:row.word_count,createdAt:row.created_at,
    updatedAt:row.updated_at,revision:row.revision,exercise:parseExercise(row.exercise_value)}));}
function parseExercise(value:string|null):Exercise|null{if(!value)return null;try{return JSON.parse(value) as Exercise;}catch{return null;}}
export async function cacheWritingExercises(userId:string,exercises:Exercise[]){const handle=await db();await handle.withTransactionAsync(async()=>{
  for(const exercise of exercises)await handle.runAsync(`INSERT INTO writing_exercise_cache(user_id,exercise_id,value,updated_at) VALUES(?,?,?,?)
    ON CONFLICT(user_id,exercise_id) DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at`,userId,exercise.id,JSON.stringify(exercise),new Date().toISOString());});}
export async function getCachedWritingExercise(userId:string,exerciseId:string):Promise<Exercise|null>{const row=await(await db()).getFirstAsync<{value:string}>(
  'SELECT value FROM writing_exercise_cache WHERE user_id=? AND exercise_id=?',userId,exerciseId);return parseExercise(row?.value??null);}
export async function listCachedWritingExercises(userId:string):Promise<Exercise[]>{const rows=await(await db()).getAllAsync<{value:string}>(
  'SELECT value FROM writing_exercise_cache WHERE user_id=? ORDER BY updated_at DESC LIMIT 100',userId);return rows.map(row=>parseExercise(row.value)).filter((item):item is Exercise=>item!==null);}
