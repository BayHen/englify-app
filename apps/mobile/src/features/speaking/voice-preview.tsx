import { useState } from 'react';
import { Page } from '@/components/page';
import { AppText } from '@/ui';
import { ReferenceVoiceSelector, VoicePickerSheet } from './voice-picker';
import type { SpeechVoice } from './speech-provider';

const sampleVoices: SpeechVoice[] = [
  { id: 'sample-us', name: 'Sample US voice', language: 'en-US', locale: 'en-US' },
  { id: 'sample-uk', name: 'Sample UK voice', language: 'en-GB', locale: 'en-GB' },
  { id: 'sample-au', name: 'Sample Australia voice', language: 'en-AU', locale: 'en-AU' },
  { id: 'sample-ca', name: 'Sample Canada voice', language: 'en-CA', locale: 'en-CA' },
];

export function VoicePreview() {
  const [selected, setSelected] = useState(sampleVoices[0]);
  const [open, setOpen] = useState(false);
  return <Page eyebrow="DESIGN PREVIEW · SAMPLE VOICES" title="Speaking voice" description="This preview does not use installed device voices or play audio." compact>
    <AppText variant="heading">Reference voice</AppText>
    <ReferenceVoiceSelector voice={selected} loading={false} disabled={false} onPress={() => setOpen(true)} />
    <VoicePickerSheet visible={open} voices={sampleVoices} selectedId={selected.id} loading={false} error="" emptyMessage="No sample voices" onSelect={(voice) => { setSelected(voice); setOpen(false); }} onClose={() => setOpen(false)} onRetry={() => setOpen(false)} />
  </Page>;
}
