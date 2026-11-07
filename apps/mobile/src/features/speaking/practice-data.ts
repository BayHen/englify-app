export type PracticePrompt = { id: string; text: string; hint: string };

export const practicePrompts: PracticePrompt[] = [
  { id: 'greeting', text: 'How is it going?', hint: 'A friendly way to ask how someone is doing.' },
  { id: 'routine', text: 'I practice English every day.', hint: 'Say this slowly, then at a natural pace.' },
  { id: 'journey', text: 'Every journey starts with one step.', hint: 'Listen for the rhythm across the whole sentence.' },
];
