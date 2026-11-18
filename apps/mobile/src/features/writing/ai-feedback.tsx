import { useState } from 'react';
import * as Clipboard from 'expo-clipboard';
import { View } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppButton, AppCard, AppInput, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import type { RewriteMode, Submission, WritingAiBundle, WritingAiFeedback, WritingAiRewrite } from './api';

const modes: { value: RewriteMode; label: string }[] = [
  { value: 'grammar', label: 'Grammar correction' }, { value: 'natural', label: 'Natural English' },
  { value: 'vocabulary', label: 'Better vocabulary' }, { value: 'formal', label: 'Formal English' },
  { value: 'simple', label: 'Simple English' },
];

function ScoreRow({ label, value }: { label: string; value: number }) {
  const palette = useAppPalette();
  return <View style={{ gap: designTokens.spacing.xs }}>
    <View style={{ flexDirection: 'row', justifyContent: 'space-between', gap: designTokens.spacing.md }}>
      <AppText variant="label">{label}</AppText><AppText variant="label" tone="primary">{value}/100</AppText>
    </View>
    <View style={{ height: 7, borderRadius: designTokens.radius.pill, overflow: 'hidden', backgroundColor: palette.border }}>
      <View style={{ width: `${value}%`, height: '100%', backgroundColor: palette.primary }} />
    </View>
  </View>;
}

function FeedbackDetails({ feedback }: { feedback: WritingAiFeedback }) {
  const palette = useAppPalette();
  return <View style={{ gap: designTokens.spacing.lg }}>
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: designTokens.spacing.lg }}>
      <View style={{ width: 76, height: 76, borderRadius: 38, alignItems: 'center', justifyContent: 'center', backgroundColor: palette.primarySoft }}>
        <AppText variant="title" tone="primary">{feedback.overall_score}</AppText>
      </View>
      <View style={{ flex: 1, gap: designTokens.spacing.xs }}><AppText variant="heading">Estimated writing score</AppText>
        <AppText tone="muted">This is AI guidance, not an official CEFR or IELTS result.</AppText></View>
    </View>
    <AppText>{feedback.assessment_vi}</AppText>
    <View style={{ gap: designTokens.spacing.md }}>
      <ScoreRow label="Grammar" value={feedback.grammar_score} /><ScoreRow label="Vocabulary" value={feedback.vocabulary_score} />
      <ScoreRow label="Sentence structure" value={feedback.sentence_structure_score} /><ScoreRow label="Coherence" value={feedback.coherence_score} />
      <ScoreRow label="Task relevance" value={feedback.task_score} />
    </View>
    <View style={{ gap: designTokens.spacing.xs }}><AppText variant="heading">Strengths</AppText>
      {feedback.strengths.map((item, index) => <AppText key={`strength-${index}`}>• {item}</AppText>)}</View>
    <View style={{ gap: designTokens.spacing.xs }}><AppText variant="heading">Areas to improve</AppText>
      {feedback.improvements.map((item, index) => <AppText key={`improvement-${index}`}>• {item}</AppText>)}</View>
    {feedback.errors.length > 0 ? <View style={{ gap: designTokens.spacing.md }}><AppText variant="heading">Detailed analysis</AppText>
      {feedback.errors.map((item, index) => <View key={`${item.type}-${index}`} style={{ gap: designTokens.spacing.xs, paddingTop: designTokens.spacing.md, borderTopWidth: 1, borderTopColor: palette.border }}>
        <AppText variant="caption" tone="primary">{item.type.replaceAll('_', ' ').toUpperCase()}</AppText>
        <AppText variant="label">Original</AppText><AppText tone="error">{item.original}</AppText>
        <AppText variant="label">Suggestion</AppText><AppText tone="success">{item.corrected}</AppText>
        <AppText variant="label">Explanation</AppText><AppText>{item.explanation_vi}</AppText>
      </View>)}</View> : null}
    <View style={{ gap: designTokens.spacing.xs }}><AppText variant="heading">Recommended next steps</AppText>
      {feedback.next_steps.map((item, index) => <AppText key={`next-${index}`}>• {item}</AppText>)}</View>
  </View>;
}

function RewriteComparison({ rewrite, onSaveRevision, saving }: { rewrite: WritingAiRewrite;
  onSaveRevision: (text: string, rewriteId: string) => Promise<void>; saving: boolean }) {
  const [view, setView] = useState<'original' | 'improved'>('improved');
  const [revision, setRevision] = useState(rewrite.improved_text);
  const [editing, setEditing] = useState(false);
  return <View style={{ gap: designTokens.spacing.md }}>
    <View style={{ flexDirection: 'row', gap: designTokens.spacing.sm }}>
      <AppButton label="View original" variant={view === 'original' ? 'primary' : 'secondary'} style={{ flex: 1 }} onPress={() => setView('original')} />
      <AppButton label="View improved" variant={view === 'improved' ? 'primary' : 'secondary'} style={{ flex: 1 }} onPress={() => setView('improved')} />
    </View>
    <AppText variant="caption" tone="primary">AI-GENERATED SUGGESTION · {rewrite.mode.replaceAll('_', ' ').toUpperCase()}</AppText>
    <AppText>{view === 'original' ? rewrite.original_text : rewrite.improved_text}</AppText>
    <AppButton label="Copy improved writing" variant="secondary" onPress={() => { void Clipboard.setStringAsync(rewrite.improved_text); }} />
    <View style={{ gap: designTokens.spacing.xs }}><AppText variant="heading">Key changes</AppText>
      {rewrite.key_changes.map((item, index) => <AppText key={`change-${index}`}>• {item}</AppText>)}
      {rewrite.explanations_vi.map((item, index) => <AppText key={`explanation-${index}`} tone="muted">• {item}</AppText>)}</View>
    {editing ? <View style={{ gap: designTokens.spacing.md }}>
      <AppInput label="Your revision" value={revision} onChangeText={setRevision} multiline style={{ minHeight: 160, textAlignVertical: 'top' }} />
      <AppButton label="Save revision" loading={saving} disabled={!revision.trim()} onPress={() => { void onSaveRevision(revision.trim(), rewrite.id); }} />
    </View> : <AppButton label="Revise writing" onPress={() => setEditing(true)} />}
  </View>;
}

export function WritingAiPanel({ submission, bundle, loading, error, busyAction, onAnalyze, onRewrite, onSaveRevision }:
  { submission: Submission; bundle: WritingAiBundle | null; loading: boolean; error: string; busyAction: string;
    onAnalyze: () => Promise<void>; onRewrite: (mode: RewriteMode) => Promise<void>;
    onSaveRevision: (text: string, rewriteId: string) => Promise<void> }) {
  const [mode, setMode] = useState<RewriteMode>('grammar');
  const feedback = bundle?.feedback[0]; const rewrite = bundle?.rewrites[0];
  return <AppCard tone="primary" style={{ gap: designTokens.spacing.lg }}>
    <View style={{ gap: designTokens.spacing.xs }}><AppText variant="heading">AI Writing Coach</AppText>
      <AppText tone="muted">AI suggestions are estimates. Your original writing stays unchanged.</AppText></View>
    {loading ? <LoadingSkeleton lines={4} /> : error ? <ErrorState message={error} retry={() => { void onAnalyze(); }} /> : <>
      {feedback ? <FeedbackDetails feedback={feedback} /> : <EmptyState title="No AI feedback yet" message="Request an analysis after reviewing your saved original writing." />}
      <AppButton label="Improve with AI" loading={busyAction === 'coach'} disabled={Boolean(busyAction)} onPress={() => { void onAnalyze(); }} />
      <View style={{ gap: designTokens.spacing.sm }}><AppText variant="heading">AI Rewrite</AppText><AppText tone="muted">Choose one mode. Nothing replaces your original automatically.</AppText>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: designTokens.spacing.sm }}>{modes.map((item) => <AppButton key={item.value}
          label={item.label} size="medium" variant={mode === item.value ? 'primary' : 'secondary'} onPress={() => setMode(item.value)} />)}</View>
        <AppButton label="Generate improved version" loading={busyAction === 'rewrite'} disabled={Boolean(busyAction)} onPress={() => { void onRewrite(mode); }} />
      </View>
      {rewrite ? <RewriteComparison key={rewrite.id} rewrite={rewrite} saving={busyAction === 'revision'} onSaveRevision={onSaveRevision} /> : null}
      {bundle && bundle.revisions.length > 0 ? <View style={{ gap: designTokens.spacing.sm }}><AppText variant="heading">Revision history</AppText>
        {bundle.revisions.map((item) => <View key={item.id} style={{ gap: designTokens.spacing.xs }}><AppText variant="label">Revision {item.revision_number}</AppText>
          <AppText tone="muted">{new Date(item.created_at).toLocaleString()}</AppText><AppText>{item.revised_text}</AppText></View>)}</View> : null}
    </>}
  </AppCard>;
}
