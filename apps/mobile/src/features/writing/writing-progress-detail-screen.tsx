import { useCallback, useState } from 'react';
import { useFocusEffect, useLocalSearchParams, type Href } from 'expo-router';
import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { Page, NavLink } from '@/components/page';
import { AppCard, AppText, ErrorState, LoadingSkeleton } from '@/ui';
import { getWritingAiBundle, getWritingAnalyticsDetail, type WritingAiBundle, type WritingAnalyticsDetail } from './api';

export function WritingProgressDetailScreen(){const {id}=useLocalSearchParams<{id:string}>();const [detail,setDetail]=useState<WritingAnalyticsDetail|null>(null);const [bundle,setBundle]=useState<WritingAiBundle|null>(null);const [error,setError]=useState('');const [loading,setLoading]=useState(true);
  const load=useCallback(async()=>{if(!id)return;setLoading(true);setError('');try{const [row,ai]=await Promise.all([getWritingAnalyticsDetail(id),getWritingAiBundle(id)]);setDetail(row);setBundle(ai);}catch(cause){setError(cause instanceof Error?cause.message:'Could not load submission.');}finally{setLoading(false);}},[id]);
  useFocusEffect(useCallback(()=>{void load();},[load])); const latest=bundle?.feedback[0]??null;
  return <Page eyebrow="WRITING HISTORY" title={detail?.exercise_title??'Submission detail'} description="Original work and feedback are kept separately.">{loading?<LoadingSkeleton lines={7}/>:error?<ErrorState message={error} retry={()=>{void load();}}/>:detail?<>
    <AppCard style={{gap:designTokens.spacing.sm}}><AppText variant="caption" tone="primary">{detail.cefr_level??'Level unavailable'} · {detail.kind?.replaceAll('_',' ')??'Legacy submission'} · {detail.word_count} words</AppText><AppText variant="heading">Original submission</AppText><AppText tone="muted">{detail.prompt}</AppText><AppText>{detail.body}</AppText></AppCard>
    <AppCard style={{gap:designTokens.spacing.sm}}><AppText variant="heading">Rule feedback</AppText><AppText>{detail.rule_feedback?.rule_result.replaceAll('_',' ')??'No rule feedback saved'}</AppText>{detail.rule_feedback?.suggestions.map((item,index)=><AppText key={index}>• {item}</AppText>)}</AppCard>
    <AppCard tone="primary" style={{gap:designTokens.spacing.sm}}><AppText variant="heading">Latest AI guidance</AppText>{latest?<><AppText variant="title">{latest.overall_score}/100</AppText><AppText>{latest.assessment_vi}</AppText><AppText tone="muted">Grammar {latest.grammar_score} · Vocabulary {latest.vocabulary_score} · Coherence {latest.coherence_score} · Task {latest.task_score}</AppText></>:<AppText tone="muted">This submission has not been evaluated by AI.</AppText>}</AppCard>
    <AppCard style={{gap:designTokens.spacing.sm}}><AppText variant="heading">Revision history</AppText>{bundle?.revisions.length?bundle.revisions.map(item=><View key={item.id} style={{gap:2}}><AppText variant="label">Revision {item.revision_number}</AppText><AppText>{item.revised_text}</AppText></View>):<AppText tone="muted">No saved revisions.</AppText>}</AppCard>
  </>:null}<NavLink href={'/writing-progress' as Href} label="Back to Writing progress"/></Page>;
}
