import { useCallback, useState } from 'react';
import { router, useFocusEffect, type Href } from 'expo-router';
import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { Page, NavLink } from '@/components/page';
import { useAppPalette } from '@/constants/app-theme';
import { AppButton, AppCard, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { getWritingAnalytics, getWritingAnalyticsHistory, type AnalyticsRange, type WritingAnalyticsHistory,
  type CefrLevel, type ExerciseKind, type WritingCefrProgress, type WritingMistake, type WritingProgressSummary, type WritingRecommendation,
  type WritingReport, type WritingScoreAnalytics, type WritingTopicProgress, type WritingActivity } from './api';

type Dashboard = { summary:WritingProgressSummary; activity:WritingActivity; scores:WritingScoreAnalytics; mistakes:WritingMistake[];
  cefr:WritingCefrProgress[]; topics:WritingTopicProgress[]; recommendations:WritingRecommendation[]; weekly:WritingReport; monthly:WritingReport };
const ranges:AnalyticsRange[]=['7d','30d','90d','all'];
const labelRange=(range:AnalyticsRange)=>range==='all'?'All time':range.toUpperCase();

export function WritingProgressScreen(){
  const palette=useAppPalette(); const [range,setRange]=useState<AnalyticsRange>('30d'); const [data,setData]=useState<Dashboard|null>(null);
  const [history,setHistory]=useState<WritingAnalyticsHistory|null>(null); const [page,setPage]=useState(1); const [aiStatus,setAiStatus]=useState<'all'|'scored'|'unscored'>('all');
  const [historyLevel,setHistoryLevel]=useState<CefrLevel|null>(null); const [historyKind,setHistoryKind]=useState<ExerciseKind|null>(null);
  const [historyTopic,setHistoryTopic]=useState<string|null>(null);
  const [loading,setLoading]=useState(true); const [error,setError]=useState('');
  const load=useCallback(async(nextRange=range,nextPage=page,nextStatus=aiStatus)=>{setLoading(true);setError('');try{
    const [dashboard,historyRows]=await Promise.all([getWritingAnalytics(nextRange),getWritingAnalyticsHistory({range:nextRange,page:nextPage,pageSize:5,aiStatus:nextStatus,level:historyLevel,kind:historyKind,topicId:historyTopic})]);
    setData(dashboard);setHistory(historyRows);
  }catch(cause){setError(cause instanceof Error?cause.message:'Could not load Writing progress.');}finally{setLoading(false);}},[range,page,aiStatus,historyLevel,historyKind,historyTopic]);
  useFocusEffect(useCallback(()=>{void load();},[load]));
  function changeRange(next:AnalyticsRange){setRange(next);setPage(1);void load(next,1,aiStatus);}
  function changeStatus(next:'all'|'scored'|'unscored'){setAiStatus(next);setPage(1);void load(range,1,next);}
  const maxActivity=Math.max(1,...(data?.activity.items.map(item=>item.words)??[1])); const maxPage=Math.max(1,Math.ceil((history?.total??0)/5));
  return <Page eyebrow="WRITING INSIGHTS" title="Your writing progress" description="Stats come from your saved submissions. AI scores are guidance, not teacher grades.">
    <View style={{flexDirection:'row',flexWrap:'wrap',gap:designTokens.spacing.sm}}>{ranges.map(item=><AppButton key={item} label={labelRange(item)} size="medium" variant={range===item?'primary':'secondary'} onPress={()=>changeRange(item)}/>)}</View>
    {loading && data===null?<LoadingSkeleton lines={8}/>:error && data===null?<ErrorState message={error} retry={()=>{void load();}}/>:data?<>
      <View style={{flexDirection:'row',flexWrap:'wrap',gap:designTokens.spacing.sm}}>
        <Metric label="Words" value={data.summary.total_words}/><Metric label="Practice days" value={data.summary.practice_days}/>
        <Metric label="Current streak" value={`${data.summary.current_streak} days`}/><Metric label="AI samples" value={data.summary.ai_score_samples}/>
      </View>
      <AppCard style={{gap:designTokens.spacing.md}}><AppText variant="heading">Writing activity</AppText>
        {data.activity.items.length===0?<EmptyState title="No activity yet" message="Complete a Writing exercise to start this chart."/>:<View accessible accessibilityLabel={`Writing activity for ${labelRange(range)}`} style={{height:150,flexDirection:'row',alignItems:'flex-end',gap:6}}>{data.activity.items.slice(-30).map(item=><View key={item.date} style={{flex:1,minWidth:4,height:`${Math.max(8,item.words/maxActivity*100)}%`,borderRadius:6,backgroundColor:palette.primary}} accessibilityLabel={`${item.date}: ${item.words} words`}/>)}</View>}
        <AppText tone="muted">Bars show saved words per active day; missing days are not fabricated.</AppText>
      </AppCard>
      <AppCard style={{gap:designTokens.spacing.md}}><AppText variant="heading">AI score trend</AppText>
        {data.scores.trends.length===0?<EmptyState title="No AI feedback yet" message="Request AI Coach feedback on an eligible open-writing submission."/>:<View style={{gap:designTokens.spacing.sm}}>{data.scores.trends.slice(-8).map(point=><View key={point.submission_id} style={{gap:4}}><View style={{flexDirection:'row',justifyContent:'space-between'}}><AppText variant="caption">{point.date} · {point.cefr_level??'Level unavailable'}</AppText><AppText variant="label">{point.overall_score}/100</AppText></View><View style={{height:9,borderRadius:8,backgroundColor:palette.primarySoft}}><View style={{height:9,width:`${point.overall_score}%`,borderRadius:8,backgroundColor:palette.primary}}/></View></View>)}</View>}
        <AppText tone="muted">{data.summary.ai_trend_reliable?'Trend uses at least 3 scored submissions.':'Trend is preliminary until at least 3 submissions are scored.'}</AppText>
      </AppCard>
      <ProgressList title="CEFR progress" rows={data.cefr.map(item=>({id:item.cefr_level,title:item.cefr_level,detail:`${item.distinct_exercises}/${item.available_exercises} exercises · ${item.submissions} submissions`,score:item.average_ai_score}))}/>
      <ProgressList title="Topic progress" rows={data.topics.map(item=>({id:item.topic_id,title:item.title,detail:`${item.distinct_exercises}/${item.available_exercises} exercises · ${item.submissions} submissions`,score:item.average_ai_score}))}/>
      <AppCard style={{gap:designTokens.spacing.md}}><AppText variant="heading">Common feedback themes</AppText>{data.mistakes.length===0?<AppText tone="muted">No structured AI error data in this range.</AppText>:data.mistakes.slice(0,5).map(item=><View key={item.category} style={{flexDirection:'row',justifyContent:'space-between',gap:designTokens.spacing.sm}}><AppText>{item.category.replaceAll('_',' ')}</AppText><AppText variant="label">{item.issue_count}</AppText></View>)}<AppText tone="muted">Only explicit structured AI feedback is counted; this does not diagnose every mistake.</AppText></AppCard>
      <AppCard tone="primary" style={{gap:designTokens.spacing.md}}><AppText variant="heading">Next practice</AppText>{data.recommendations.length===0?<AppText tone="muted">No recommendation is available for the current level.</AppText>:data.recommendations.map(item=><View key={item.exercise.id} style={{gap:designTokens.spacing.xs}}><AppText variant="label">{item.title}</AppText><AppText tone="muted">{item.explanation_vi}</AppText><AppButton label={`Open ${item.exercise.title}`} variant="secondary" onPress={()=>router.push({pathname:'/writing',params:{exercise:item.exercise.id}} as Href)}/></View>)}</AppCard>
      <ReportCard report={data.weekly}/><ReportCard report={data.monthly}/>
      <AppCard style={{gap:designTokens.spacing.md}}><AppText variant="heading">Writing history</AppText><View style={{flexDirection:'row',flexWrap:'wrap',gap:designTokens.spacing.sm}}>{(['all','scored','unscored'] as const).map(item=><AppButton key={item} label={item} size="medium" variant={aiStatus===item?'primary':'secondary'} onPress={()=>changeStatus(item)}/>)}</View>
        <AppText variant="label">CEFR</AppText><View style={{flexDirection:'row',flexWrap:'wrap',gap:designTokens.spacing.sm}}>{([null,'A1','A2','B1','B2','C1'] as const).map(item=><AppButton key={item??'all'} label={item??'All'} size="medium" variant={historyLevel===item?'primary':'secondary'} onPress={()=>{setHistoryLevel(item);setPage(1);}}/>)}</View>
        <AppText variant="label">Exercise type</AppText><View style={{flexDirection:'row',flexWrap:'wrap',gap:designTokens.spacing.sm}}>{([null,'sentence','fill_blank','sentence_order','paragraph','email','opinion','essay'] as const).map(item=><AppButton key={item??'all'} label={(item??'All').replaceAll('_',' ')} size="medium" variant={historyKind===item?'primary':'secondary'} onPress={()=>{setHistoryKind(item);setPage(1);}}/>)}</View>
        <AppText variant="label">Topic</AppText><View style={{flexDirection:'row',flexWrap:'wrap',gap:designTokens.spacing.sm}}><AppButton label="All" size="medium" variant={historyTopic===null?'primary':'secondary'} onPress={()=>{setHistoryTopic(null);setPage(1);}}/>{data.topics.map(item=><AppButton key={item.topic_id} label={item.title} size="medium" variant={historyTopic===item.topic_id?'primary':'secondary'} onPress={()=>{setHistoryTopic(item.topic_id);setPage(1);}}/>)}</View>
        {history?.items.length?history.items.map(item=><AppCard key={item.id} tone={item.qualifies?'primary':'surface'} onPress={()=>router.push({pathname:'/writing-progress/[id]',params:{id:item.id}} as unknown as Href)} accessibilityLabel={`Open ${item.exercise_title}`} style={{gap:4}}><AppText variant="label">{item.exercise_title}</AppText><AppText tone="muted">{new Date(item.created_at).toLocaleDateString()} · {item.word_count} words · {item.overall_score===null?'Not AI scored':`${item.overall_score}/100`}</AppText></AppCard>):<EmptyState title="No submissions" message="Try another time range or feedback filter."/>}
        <View style={{flexDirection:'row',gap:designTokens.spacing.sm}}><AppButton label="Previous" style={{flex:1}} variant="secondary" disabled={page<=1} onPress={()=>{const next=page-1;setPage(next);void load(range,next,aiStatus);}}/><AppButton label={`${page} / ${maxPage}`} style={{flex:1}} variant="ghost" disabled onPress={()=>undefined}/><AppButton label="Next" style={{flex:1}} variant="secondary" disabled={page>=maxPage} onPress={()=>{const next=page+1;setPage(next);void load(range,next,aiStatus);}}/></View>
      </AppCard>
      {error?<ErrorState message={error} retry={()=>{void load();}}/>:null}
    </>:null}
    <NavLink href={'/writing' as Href} label="Back to Writing practice"/>
  </Page>;
}

function Metric({label,value}:{label:string;value:string|number}){return <AppCard style={{minWidth:150,flex:1,gap:4}}><AppText variant="title" tone="primary">{String(value)}</AppText><AppText tone="muted">{label}</AppText></AppCard>;}
function ProgressList({title,rows}:{title:string;rows:{id:string;title:string;detail:string;score:number|null}[]}){return <AppCard style={{gap:designTokens.spacing.md}}><AppText variant="heading">{title}</AppText>{rows.length===0?<AppText tone="muted">No progress data yet.</AppText>:rows.map(item=><View key={item.id} style={{gap:2}}><View style={{flexDirection:'row',justifyContent:'space-between',gap:8}}><AppText variant="label">{item.title}</AppText><AppText tone="primary">{item.score===null?'—':`${item.score}/100`}</AppText></View><AppText tone="muted">{item.detail}</AppText></View>)}</AppCard>;}
function ReportCard({report}:{report:WritingReport}){return <AppCard tone="reward" style={{gap:designTokens.spacing.sm}}><AppText variant="heading">{report.period==='weekly'?'Weekly overview':'Monthly overview'}</AppText><AppText>{report.activity.submissions} submissions · {report.activity.total_words} words</AppText><AppText>{report.daily_challenges.completed} daily challenges · {report.daily_challenges.xp_earned} XP</AppText><AppText tone="muted">AI average: {report.ai_feedback.average_score===null?'Not enough data':`${report.ai_feedback.average_score}/100 (${report.ai_feedback.sample_size} samples)`}</AppText></AppCard>;}
