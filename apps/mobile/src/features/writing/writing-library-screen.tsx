import { useCallback, useRef, useState } from 'react';
import { useFocusEffect, useLocalSearchParams, type Href } from 'expo-router';
import { randomUUID } from 'expo-crypto';
import { Alert, View } from 'react-native';
import { designTokens } from '@englify/shared';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppInput, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { WritingAiPanel } from './ai-feedback';
import { DailyWritingPanel } from './daily-writing-panel';
import { useAuth } from '@/auth/provider';
import { listCachedWritingExercises, writingDraftContext, type WritingDraftSummary } from './draft-storage';
import { useWritingDrafts } from './use-writing-drafts';
import { createWritingRevision, getDailyWritingOverview, getWritingAiBundle, getWritingCatalog, getWritingHistory,
  getWritingLevel, getWritingSubmission, getWritingTopics, recommendExercises, requestWritingCoach, requestWritingRewrite,
  setWritingLevel, setWritingTimezone, submitDailyWriting, submitWriting, type CefrLevel, type DailyWritingOverview,
  type DailyWritingSubmitResult, type Exercise, type ExerciseKind, type RewriteMode, type Submission,
  type WritingAiBundle, type WritingTopic } from './api';

const levels: { id: CefrLevel; name: string; description: string }[] = [
  { id: 'A1', name: 'Beginner', description: 'Câu cơ bản và từ vựng quen thuộc.' }, { id: 'A2', name: 'Elementary', description: 'Đoạn văn ngắn về cuộc sống hằng ngày.' },
  { id: 'B1', name: 'Intermediate', description: 'Trải nghiệm, email và ý kiến có lý do.' }, { id: 'B2', name: 'Upper Intermediate', description: 'Lập luận rõ ràng và bài viết có cấu trúc.' },
  { id: 'C1', name: 'Advanced', description: 'Phân tích chính xác và văn phong học thuật.' },
];
const kinds: (ExerciseKind | 'all')[] = ['all','sentence','fill_blank','sentence_order','paragraph','email','opinion','essay'];
const openKinds: ExerciseKind[] = ['paragraph','email','opinion','essay'];
const words = (value: string) => value.trim() ? value.trim().split(/\s+/).length : 0;

export function WritingLibraryScreen() {
  const {exercise:recommendedExerciseId}=useLocalSearchParams<{exercise?:string}>();
  const {profile}=useAuth();const userId=profile?.id??null;
  const {status:draftStatus,online,summaries:savedDrafts,activate:activateDraft,change:changeDraft,flush:flushDraft,
    discard:discardDraft,clearSubmitted,submittedRevision,cacheExercises}=useWritingDrafts(userId);
  const [level,setLevelState]=useState<CefrLevel>('A1'); const [topics,setTopics]=useState<WritingTopic[]>([]);
  const [catalog,setCatalog]=useState<Exercise[]>([]); const [total,setTotal]=useState(0); const [page,setPage]=useState(1);
  const [query,setQuery]=useState(''); const [topicId,setTopicId]=useState<string|null>(null); const [kind,setKind]=useState<ExerciseKind|null>(null);
  const [history,setHistory]=useState<Submission[]>([]); const [recommended,setRecommended]=useState<Exercise[]>([]);
  const [selected,setSelected]=useState<Exercise|null>(null); const [drafts,setDrafts]=useState<Record<string,string>>({}); const [chosen,setChosen]=useState<number[]>([]);
  const [result,setResult]=useState<Submission|null>(null); const [reviewing,setReviewing]=useState<Submission|null>(null);
  const [daily,setDaily]=useState<DailyWritingOverview|null>(null); const [dailyAssignmentId,setDailyAssignmentId]=useState<string|null>(null);
  const [dailyResult,setDailyResult]=useState<DailyWritingSubmitResult|null>(null); const [timezoneDraft,setTimezoneDraft]=useState('Asia/Ho_Chi_Minh');
  const [loading,setLoading]=useState(true); const [busy,setBusy]=useState(''); const [error,setError]=useState('');
  const [aiBundle,setAiBundle]=useState<WritingAiBundle|null>(null); const [aiError,setAiError]=useState(''); const [aiLoading,setAiLoading]=useState(false);
  const [draftNotice,setDraftNotice]=useState('');const requestId=useRef<string|null>(null);
  const activeDraftKey=selected?writingDraftContext(selected.id,dailyAssignmentId):null;const draft=activeDraftKey?drafts[activeDraftKey]??'':'';

  const loadCatalog=useCallback(async (nextLevel:CefrLevel,nextPage=1,nextTopic:string|null=null,nextKind:ExerciseKind|null=null,nextQuery='')=>{
    const value=await getWritingCatalog({level:nextLevel,page:nextPage,pageSize:5,topicId:nextTopic,kind:nextKind,query:nextQuery});
    setCatalog(value.items); setTotal(value.total); setPage(value.page);
  },[]);
  const load=useCallback(async()=>{setLoading(true);setError('');try{
    const [savedLevel,dailyOverview,previous]=await Promise.all([getWritingLevel(),getDailyWritingOverview(),getWritingHistory()]);
    const [topicRows,all]=await Promise.all([getWritingTopics(savedLevel),getWritingCatalog({level:savedLevel,pageSize:50})]);
    setLevelState(savedLevel);setDaily(dailyOverview);setTimezoneDraft(dailyOverview.timezone);setTopics(topicRows);setHistory(previous);setRecommended(recommendExercises(all.items,previous));
    await cacheExercises(dailyOverview.challenge?[...all.items,dailyOverview.challenge]:all.items).catch(()=>undefined);
    const recommendedExercise=all.items.find(item=>item.id===recommendedExerciseId);if(recommendedExercise){const restored=await activateDraft(recommendedExercise,null);if(restored!==undefined){setSelected(recommendedExercise);setDailyAssignmentId(null);const key=writingDraftContext(recommendedExercise.id,null);setDrafts(current=>({...current,[key]:restored?.content??''}));setChosen(restored?.selectedTokens??[]);if(restored)setDraftNotice(`Draft restored from ${new Date(restored.updatedAt).toLocaleString()}.`);}}
    await loadCatalog(savedLevel);
  }catch(cause){const cached=userId?await listCachedWritingExercises(userId).catch(()=>[]):[];if(cached.length>0){setCatalog(cached.slice(0,5));setTotal(cached.length);setRecommended(cached.slice(0,3));setError("You're offline. Cached exercises and local drafts remain available.");}
    else setError(cause instanceof Error?cause.message:'Could not load writing library.');}finally{setLoading(false);}},[activateDraft,cacheExercises,loadCatalog,recommendedExerciseId,userId]);
  useFocusEffect(useCallback(()=>{void load();},[load]));
  useFocusEffect(useCallback(()=>()=>{void flushDraft();},[flushDraft]));
  async function changeLevel(next:CefrLevel){setBusy('level');try{await setWritingLevel(next);setLevelState(next);setTopicId(null);setKind(null);setQuery('');
    const [topicRows,all]=await Promise.all([getWritingTopics(next),getWritingCatalog({level:next,pageSize:50})]);setTopics(topicRows);setRecommended(recommendExercises(all.items,history));await loadCatalog(next);
  }catch(cause){setError(cause instanceof Error?cause.message:'Could not save writing level.');}finally{setBusy('');}}
  async function open(exercise:Exercise,assignmentId:string|null=null){setDraftNotice('');const restored=await activateDraft(exercise,assignmentId);if(restored===undefined)return;setSelected(exercise);setDailyAssignmentId(assignmentId);setDailyResult(null);setChosen(restored?.selectedTokens??[]);setResult(null);setReviewing(null);setAiBundle(null);setAiError('');requestId.current=null;
    const contextKey=writingDraftContext(exercise.id,assignmentId);if(restored){setDrafts(current=>({...current,[contextKey]:restored.content}));setDraftNotice(`Draft restored from ${new Date(restored.updatedAt).toLocaleString()}.`);}else setDrafts(current=>({...current,[contextKey]:''}));}
  function updateDraft(value:string,nextTokens=chosen){if(!selected||!activeDraftKey)return;setDrafts(current=>({...current,[activeDraftKey]:value}));changeDraft(value,nextTokens);requestId.current=null;setResult(null);}
  function choose(index:number){if(!selected||chosen.includes(index))return;const next=[...chosen,index];setChosen(next);updateDraft(next.map(value=>selected.tokens[value]).join(' '),next);}
  async function submit(){if(!selected||!draft.trim()||busy)return;if(!online){setError("You're offline. Your draft is saved on this device; connect to submit.");return;}await flushDraft();const sentRevision=submittedRevision();const sentContext=activeDraftKey;setBusy('submit');setError('');try{requestId.current??=randomUUID();
    if(dailyAssignmentId){const dailySaved=await submitDailyWriting(dailyAssignmentId,requestId.current,draft.trim(),false);setDailyResult(dailySaved);setDaily(dailySaved.overview);setResult(dailySaved.submission);setHistory(current=>[dailySaved.submission,...current.filter(item=>item.id!==dailySaved.submission.id)]);if(dailySaved.completed&&sentContext){await clearSubmitted(sentContext,sentRevision);if(submittedRevision()===sentRevision)setDrafts(current=>({...current,[sentContext]:''}));requestId.current=null;}}
    else{const saved=await submitWriting(requestId.current,selected.id,draft.trim(),false);setResult(saved);setHistory(current=>[saved,...current.filter(item=>item.id!==saved.id)]);if(sentContext)await clearSubmitted(sentContext,sentRevision);if(submittedRevision()===sentRevision&&sentContext)setDrafts(current=>({...current,[sentContext]:''}));requestId.current=null;}
  }catch(cause){setError(cause instanceof Error?cause.message:'Could not submit writing.');}finally{setBusy('');}}
  async function reviewDaily(){if(!daily?.challenge?.completion||busy)return;setBusy('daily-review');try{const saved=await getWritingSubmission(daily.challenge.completion.submission_id);setSelected(daily.challenge);setDailyAssignmentId(null);setReviewing(saved);setResult(null);await loadAi(saved.id);}catch(cause){setError(cause instanceof Error?cause.message:'Could not load Daily Writing feedback.');}finally{setBusy('');}}
  async function saveTimezone(){if(!timezoneDraft.trim()||busy)return;setBusy('timezone');setError('');try{await setWritingTimezone(timezoneDraft.trim());const value=await getDailyWritingOverview();setDaily(value);setTimezoneDraft(value.timezone);}catch(cause){setError(cause instanceof Error?cause.message:'Could not save Writing timezone.');}finally{setBusy('');}}
  function confirmDiscard(item:WritingDraftSummary){Alert.alert('Discard draft?','This removes the unfinished writing from this device. Submitted work is not affected.',[
    {text:'Keep draft',style:'cancel'},{text:'Discard',style:'destructive',onPress:()=>{void discardDraft(item.contextKey).then(()=>{if(activeDraftKey===item.contextKey){setDrafts(current=>({...current,[item.contextKey]:''}));setChosen([]);setDraftNotice('');}});}}]);}
  async function openSavedDraft(item:WritingDraftSummary){if(!item.exercise){setError('The cached exercise details are unavailable. Reconnect and open the Writing library first.');return;}await open(item.exercise,item.challengeAssignmentId);}
  const displayed=reviewing??result; const activeExercise=displayed?([selected,...catalog,...recommended].find(item=>item?.id===displayed.exercise_id)??null):selected;
  async function loadAi(id:string){setAiLoading(true);try{setAiBundle(await getWritingAiBundle(id));setAiError('');}catch(cause){setAiError(cause instanceof Error?cause.message:'Could not load AI history.');}finally{setAiLoading(false);}}
  async function coach(){if(!displayed||busy)return;if(!online){setAiError('Connect to the internet to use AI Coach. Your draft remains saved locally.');return;}setBusy('coach');try{const value=await requestWritingCoach(displayed.id,randomUUID());setAiBundle(current=>({feedback:[value,...(current?.feedback??[])],rewrites:current?.rewrites??[],revisions:current?.revisions??[]}));setAiError('');}catch(cause){setAiError(cause instanceof Error?cause.message:'AI Coach is unavailable.');}finally{setBusy('');}}
  async function rewrite(mode:RewriteMode){if(!displayed||busy)return;if(!online){setAiError('Connect to the internet to use AI Rewrite. Your original writing is unchanged.');return;}setBusy('rewrite');try{const value=await requestWritingRewrite(displayed.id,randomUUID(),mode);setAiBundle(current=>({feedback:current?.feedback??[],rewrites:[value,...(current?.rewrites??[])],revisions:current?.revisions??[]}));setAiError('');}catch(cause){setAiError(cause instanceof Error?cause.message:'AI Rewrite is unavailable.');}finally{setBusy('');}}
  async function saveRevision(text:string,rewriteId:string){if(!displayed||busy)return;setBusy('revision');try{const value=await createWritingRevision(randomUUID(),displayed.id,text,rewriteId,aiBundle?.feedback[0]?.id);setAiBundle(current=>({feedback:current?.feedback??[],rewrites:current?.rewrites??[],revisions:[value,...(current?.revisions??[])]}));}catch(cause){setAiError(cause instanceof Error?cause.message:'Could not save revision.');}finally{setBusy('');}}
  const maxPage=Math.max(1,Math.ceil(total/5));
  const saveLabel=!online?(draftStatus==='saved'?'Offline — saved locally.':draftStatus==='saving'?'Saving locally…':draftStatus==='error'?'Unable to save locally.':'Offline — start writing to save a local draft.'):
    draftStatus==='saving'?'Saving…':draftStatus==='saved'?'Saved on this device.':draftStatus==='error'?'Unable to save.':'Draft will save automatically.';
  return <Page eyebrow="WRITING PRACTICE" title="Writing Practice" description="Improve your English writing step by step.">
    {loading?<LoadingSkeleton lines={6}/>:Boolean(error)&&catalog.length===0?<ErrorState message={error} retry={()=>{void load();}}/>:<>
      {daily&&!selected?<DailyWritingPanel overview={daily} timezoneDraft={timezoneDraft} timezoneBusy={busy==='timezone'} onTimezoneChange={setTimezoneDraft} onSaveTimezone={()=>{void saveTimezone();}} onStart={()=>{if(daily.challenge)open(daily.challenge,daily.challenge.assignment_id);}} onReview={()=>{void reviewDaily();}}/>:null}
      <NavLink href={'/writing-progress' as Href} label="View Writing progress and insights"/>
      {!online?<AppCard tone="reward" style={{gap:designTokens.spacing.xs}}><AppText variant="label">Offline mode</AppText><AppText tone="muted">Previously loaded exercises and drafts remain editable. Submission, AI feedback and XP require a connection.</AppText></AppCard>:null}
      {selected?null:<View style={{gap:designTokens.spacing.sm}}><AppText variant="heading">My drafts</AppText>{savedDrafts.length===0?<EmptyState title="No saved drafts yet" message="Unfinished writing will appear here automatically."/>:savedDrafts.map(item=><AppCard key={item.contextKey} style={{gap:designTokens.spacing.xs}}><AppText variant="label">{item.exercise?.title??'Cached exercise unavailable'}</AppText><AppText tone="muted">{item.exercise?.cefr_level??'—'} · {item.exercise?.topic_title??'General'} · {item.wordCount} words</AppText><AppText numberOfLines={2}>{item.preview||'Empty draft'}</AppText><AppText variant="caption" tone="muted">Edited {new Date(item.updatedAt).toLocaleString()}</AppText><View style={{flexDirection:'row',gap:designTokens.spacing.sm}}><AppButton label="Continue writing" style={{flex:1}} disabled={!item.exercise} onPress={()=>{void openSavedDraft(item);}}/><AppButton label="Discard" style={{flex:1}} variant="secondary" onPress={()=>confirmDiscard(item)}/></View></AppCard>)}</View>}
      {dailyResult?.newly_completed?<AppCard tone="reward" style={{gap:designTokens.spacing.sm}}><AppText variant="title">Daily Writing Completed!</AppText><AppText>You earned {dailyResult.earned_xp} XP.</AppText><AppText tone="muted">Current Writing streak: {dailyResult.overview.streak.current_streak} days.</AppText><AppButton label="View writing feedback" variant="secondary" onPress={()=>setReviewing(dailyResult.submission)}/>{openKinds.includes(selected?.kind??'sentence')?<AppButton label="Improve with AI" onPress={()=>{setReviewing(dailyResult.submission);void loadAi(dailyResult.submission.id);}}/>:null}</AppCard>:null}
      {selected?null:<><View style={{gap:designTokens.spacing.sm}}><AppText variant="heading">Current level</AppText><View style={{flexDirection:'row',flexWrap:'wrap',gap:designTokens.spacing.sm}}>{levels.map(item=><AppButton key={item.id} label={`${item.id} · ${item.name}`} variant={level===item.id?'primary':'secondary'} disabled={busy==='level'} onPress={()=>{void changeLevel(item.id);}}/>)}</View><AppText tone="muted">{levels.find(item=>item.id===level)?.description??''}</AppText></View>
      <View style={{gap:designTokens.spacing.sm}}><AppText variant="heading">Writing topics</AppText>{topics.map(item=><AppCard key={item.id} onPress={()=>{setTopicId(item.id);void loadCatalog(level,1,item.id,kind,query);}} accessibilityLabel={`Open ${item.title}`} style={{gap:designTokens.spacing.xs}}><AppText variant="label">{item.title} · {item.exercise_count}</AppText><AppText tone="muted">{item.description}</AppText></AppCard>)}</View>
      <View style={{gap:designTokens.spacing.sm}}><AppText variant="heading">Recommended for {level}</AppText>{recommended.length>0?recommended.map(item=><ExerciseRow key={item.id} exercise={item} onPress={()=>open(item)}/>):<EmptyState title="No recommendations" message="Choose another level or publish more exercises."/>}</View>
      <View style={{gap:designTokens.spacing.md}}><AppText variant="heading">Other writing exercises</AppText><AppInput label="Search exercises" value={query} onChangeText={setQuery} placeholder="Search title, prompt or instructions"/><AppButton label="Search" onPress={()=>{void loadCatalog(level,1,topicId,kind,query);}}/>
        <View style={{flexDirection:'row',flexWrap:'wrap',gap:designTokens.spacing.sm}}>{kinds.map(value=><AppButton key={value} label={value.replaceAll('_',' ')} size="medium" variant={(value==='all'&&kind===null)||kind===value?'primary':'secondary'} onPress={()=>{const next=value==='all'?null:value;setKind(next);void loadCatalog(level,1,topicId,next,query);}}/>)}</View>
        {topicId?<AppButton label="Clear topic filter" variant="secondary" onPress={()=>{setTopicId(null);void loadCatalog(level,1,null,kind,query);}}/>:null}
        {catalog.length>0?catalog.map(item=><ExerciseRow key={item.id} exercise={item} onPress={()=>open(item)}/>):<EmptyState title="No matching exercises" message="Try another level, topic, type, or search term."/>}
        <View style={{flexDirection:'row',gap:designTokens.spacing.sm}}><AppButton label="Previous" style={{flex:1}} variant="secondary" disabled={page<=1} onPress={()=>{void loadCatalog(level,page-1,topicId,kind,query);}}/><AppButton label={`${page} / ${maxPage}`} style={{flex:1}} variant="ghost" disabled onPress={()=>undefined}/><AppButton label="Next" style={{flex:1}} variant="secondary" disabled={page>=maxPage} onPress={()=>{void loadCatalog(level,page+1,topicId,kind,query);}}/></View>
      </View></>}
      {selected?<AppCard tone="primary" style={{gap:designTokens.spacing.md}}><AppText variant="caption" tone="primary">{selected.cefr_level} · {selected.topic_title??'General'} · {selected.kind.replaceAll('_',' ')}</AppText><AppText variant="heading">{selected.title}</AppText><AppText>{selected.prompt}</AppText>{selected.instructions?<AppText tone="muted">{selected.instructions}</AppText>:null}{selected.hint?<AppText tone="muted">Hint: {selected.hint}</AppText>:null}<AppText variant="caption" tone="muted">{selected.estimated_minutes??'—'} min · {selected.recommended_words?`${words(draft)} / ${selected.recommended_words} recommended words`:`${words(draft)} words`}</AppText>
        {draftNotice?<AppCard tone="reward" style={{gap:designTokens.spacing.sm}}><AppText variant="label">Draft restored</AppText><AppText tone="muted">{draftNotice}</AppText><View style={{flexDirection:'row',gap:designTokens.spacing.sm}}><AppButton label="Continue writing" style={{flex:1}} onPress={()=>setDraftNotice('')}/><AppButton label="Discard draft" style={{flex:1}} variant="secondary" onPress={()=>{const item=savedDrafts.find(value=>value.contextKey===activeDraftKey);if(item)confirmDiscard(item);}}/></View></AppCard>:null}
        <AppText variant="caption" tone={draftStatus==='error'?'error':'muted'} accessibilityRole={draftStatus==='error'?'alert':undefined}>{saveLabel}</AppText>
        {selected.kind==='sentence_order'?<><View style={{flexDirection:'row',flexWrap:'wrap',gap:designTokens.spacing.sm}}>{selected.tokens.map((token,index)=><AppButton key={`${token}-${index}`} label={token} size="medium" variant={chosen.includes(index)?'primary':'secondary'} disabled={chosen.includes(index)} onPress={()=>choose(index)}/>)}</View><AppButton label="Undo last" variant="secondary" disabled={chosen.length===0} onPress={()=>{const next=chosen.slice(0,-1);setChosen(next);updateDraft(next.map(value=>selected.tokens[value]).join(' '),next);}}/><AppButton label="Clear answer" variant="secondary" onPress={()=>{setChosen([]);updateDraft('',[]);}}/></>:<AppInput label="Your writing" value={draft} onChangeText={value=>updateDraft(value,[])} multiline={openKinds.includes(selected.kind)} scrollEnabled textAlignVertical="top" returnKeyType="default" blurOnSubmit={false} style={openKinds.includes(selected.kind)?{minHeight:240,textAlignVertical:'top',paddingTop:designTokens.spacing.lg}:undefined}/>}<AppButton label={online?'Submit writing':'Connect to submit'} loading={busy==='submit'} disabled={!draft.trim()||!online} onPress={()=>{void submit();}}/><AppButton label="Back to Writing library" variant="secondary" onPress={()=>{void flushDraft().then(()=>setSelected(null));}}/></AppCard>:null}
      {Boolean(error)?<ErrorState message={error} retry={()=>{void load();}}/>:null}
      {displayed?<AppCard style={{gap:designTokens.spacing.sm}}><AppText variant="heading">Saved feedback</AppText><AppText>{displayed.body}</AppText><AppText tone="primary">{displayed.feedback?.rule_result?.replaceAll('_',' ')??'No rule feedback'}</AppText>{displayed.feedback?.suggestions.map((item,index)=><AppText key={index}>• {item}</AppText>)}</AppCard>:null}
      {Boolean(displayed) && Boolean(activeExercise) && activeExercise && openKinds.includes(activeExercise.kind)
        ? <WritingAiPanel submission={displayed!} bundle={aiBundle} loading={aiLoading} error={aiError} busyAction={busy} onAnalyze={coach} onRewrite={rewrite} onSaveRevision={saveRevision}/>
        : null}
      {selected?null:<View style={{gap:designTokens.spacing.sm}}><AppText variant="heading">Recent writing</AppText>{history.length>0?history.slice(0,5).map(item=><AppCard key={item.id} onPress={()=>{setReviewing(item);setResult(null);void loadAi(item.id);}} accessibilityLabel={`Review ${item.prompt}`}><AppText variant="label">{item.prompt}</AppText><AppText tone="muted">{new Date(item.created_at).toLocaleString()}</AppText></AppCard>):<EmptyState title="No writing saved yet" message="Complete an exercise to start your history."/>}</View>}
    </>}
    <NavLink href="/home" label="Back to dashboard"/>
  </Page>;
}

function ExerciseRow({exercise,onPress}:{exercise:Exercise;onPress:()=>void}){return <AppCard onPress={onPress} accessibilityLabel={`Open ${exercise.title}`} style={{gap:designTokens.spacing.xs}}><AppText variant="caption" tone="primary">{exercise.cefr_level} · {exercise.kind.replaceAll('_',' ')} · difficulty {exercise.difficulty}</AppText><AppText variant="heading">{exercise.title}</AppText><AppText tone="muted">{exercise.prompt}</AppText></AppCard>;}
