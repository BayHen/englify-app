import { useState } from 'react';
import { AppButton, AppModal, AppText } from '@/ui';
import { reportArenaQuestion, type ArenaReportReason } from './arena-api';
const reasons: { value: ArenaReportReason; label: string }[] = [
  { value: 'incorrect_answer', label: 'Incorrect answer' }, { value: 'unclear', label: 'Unclear question' },
  { value: 'grammar_error', label: 'Grammar error' }, { value: 'wrong_cefr', label: 'Wrong CEFR level' },
  { value: 'duplicate', label: 'Duplicate question' }, { value: 'other', label: 'Other issue' },
];
export function QuestionReportButton({ sessionId, questionId }: { sessionId: string; questionId: string }) {
  const [open, setOpen] = useState(false); const [busy, setBusy] = useState(false); const [message, setMessage] = useState('');
  async function submit(reason: ArenaReportReason) { setBusy(true); setMessage(''); try { await reportArenaQuestion(sessionId, questionId, reason); setMessage('Report submitted for Admin review. Your results stay unchanged.'); } catch (cause) { setMessage(cause instanceof Error ? cause.message : 'Could not submit report.'); } finally { setBusy(false); } }
  return <><AppButton label="Report question" size="medium" variant="ghost" onPress={() => setOpen(true)} /><AppModal visible={open} title="Report this question" onClose={() => { if (!busy) setOpen(false); }}>{reasons.map(reason => <AppButton key={reason.value} label={reason.label} disabled={busy} variant="secondary" onPress={() => { void submit(reason.value); }} />)}{Boolean(message) ? <AppText tone="muted">{message}</AppText> : null}<AppButton label="Close" variant="ghost" disabled={busy} onPress={() => setOpen(false)} /></AppModal></>;
}
