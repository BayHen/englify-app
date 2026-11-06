export type Destination = '/home' | '/journey' | '/explore' | '/dictionary' | '/translation' | '/real-english' | '/speaking' | '/writing' | '/quiz-arena' | '/rewards' | '/profile' | '/coach';
export type FeatureLink = { title: string; detail: string; href: Destination; icon: string };
export const featureLinks: FeatureLink[] = [
  { title: 'Journey map', detail: 'Follow a sample lesson path', href: '/journey', icon: '◇' },
  { title: 'Dictionary', detail: 'Search a small offline word set', href: '/dictionary', icon: 'Aa' },
  { title: 'Translation', detail: 'Try curated phrase pairs', href: '/translation', icon: '↔' },
  { title: 'Real English', detail: 'Idioms and everyday expressions', href: '/real-english', icon: '✦' },
  { title: 'Speaking', detail: 'Read and practice sample prompts', href: '/speaking', icon: '◉' },
  { title: 'Writing', detail: 'Draft and check a short response', href: '/writing', icon: '✎' },
  { title: 'Quiz Arena', detail: 'Play a local sample quiz', href: '/quiz-arena', icon: '★' },
  { title: 'Rewards', detail: 'Preview badges and prizes', href: '/rewards', icon: '✧' },
];
export type WordEntry = { word: string; pronunciation: string; meaning: string; example: string; category: string };
export const words: WordEntry[] = [
  { word: 'curious', pronunciation: '/ˈkjʊriəs/', meaning: 'tò mò', example: 'I am curious about this story.', category: 'adjective' },
  { word: 'journey', pronunciation: '/ˈdʒɜːrni/', meaning: 'hành trình', example: 'Every journey starts with one step.', category: 'noun' },
  { word: 'practice', pronunciation: '/ˈpræktɪs/', meaning: 'luyện tập', example: 'I practice English every day.', category: 'verb' },
  { word: 'reward', pronunciation: '/rɪˈwɔːrd/', meaning: 'phần thưởng', example: 'A new badge is a fun reward.', category: 'noun' },
];
export const searchWords = (query: string): WordEntry[] => words.filter((entry) => `${entry.word} ${entry.meaning} ${entry.category}`.toLocaleLowerCase().includes(query.trim().toLocaleLowerCase()));
export type Phrase = { english: string; vietnamese: string; note: string; category: 'conversation' | 'idiom' | 'phrasal verb' };
export const phrases: Phrase[] = [
  { english: 'How is it going?', vietnamese: 'Dạo này thế nào?', note: 'A casual way to greet someone.', category: 'conversation' },
  { english: 'Break the ice', vietnamese: 'Phá tan sự ngượng ngùng', note: 'Start a conversation in a relaxed way.', category: 'idiom' },
  { english: 'Figure out', vietnamese: 'Tìm ra, hiểu ra', note: 'Understand or solve something.', category: 'phrasal verb' },
  { english: 'See you soon!', vietnamese: 'Hẹn sớm gặp lại!', note: 'A friendly goodbye.', category: 'conversation' },
];
export const translateSample = (input: string): Phrase | undefined => phrases.find((phrase) => [phrase.english, phrase.vietnamese].some((value) => value.toLocaleLowerCase().replace(/[.!?]/g, '').trim() === input.toLocaleLowerCase().replace(/[.!?]/g, '').trim()));
export type Lesson = { title: string; detail: string; status: 'completed' | 'available' | 'locked' };
export const lessons: Lesson[] = [
  { title: 'Say hello', detail: 'Greetings and introductions', status: 'completed' },
  { title: 'Keep it going', detail: 'Simple follow-up questions', status: 'available' },
  { title: 'Tell your story', detail: 'Talk about your day', status: 'locked' },
  { title: 'Make a plan', detail: 'Future plans and invitations', status: 'locked' },
];
export type QuizQuestion = { prompt: string; options: readonly string[]; answer: number; explanation: string };
export const quizQuestions: QuizQuestion[] = [
  { prompt: 'What does “curious” mean?', options: ['Tò mò', 'Mệt mỏi', 'Nhanh chóng'], answer: 0, explanation: 'Curious means wanting to know or learn.' },
  { prompt: 'Choose a friendly greeting.', options: ['How is it going?', 'Close the door.', 'I have a pen.'], answer: 0, explanation: 'How is it going? is a casual greeting.' },
  { prompt: '“Figure out” means…', options: ['Give up', 'Understand or solve', 'Travel far'], answer: 1, explanation: 'To figure something out is to understand or solve it.' },
];
export type Reward = { title: string; detail: string; xp: number };
export const rewards: Reward[] = [
  { title: 'Starlight frame', detail: 'A playful profile frame preview', xp: 120 },
  { title: 'Explorer theme', detail: 'A sample visual theme preview', xp: 240 },
];
export const badges = [
  { title: 'First step', description: 'Finish a first sample lesson', unlocked: true },
  { title: 'Word finder', description: 'Explore new vocabulary', unlocked: false },
  { title: 'Bright speaker', description: 'Keep practicing aloud', unlocked: false },
] as const;
export const writingPrompts = [
  'Write two sentences about your favorite place.',
  'Describe a small goal for this week.',
  'Introduce yourself to a new friend.',
] as const;
export function checkDraft(draft: string): string[] {
  const trimmed = draft.trim();
  if (!trimmed) return [];
  const checks: string[] = [];
  if (trimmed.split(/\s+/).length >= 8) checks.push('At least 8 words');
  if (/^[A-Z]/.test(trimmed)) checks.push('Starts with a capital letter');
  if (/[.!?]$/.test(trimmed)) checks.push('Ends with punctuation');
  return checks;
}
