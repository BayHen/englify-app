export type FeatureKey = 'home' | 'journey' | 'explore' | 'coach' | 'profile';
export type FeatureContent = {
  eyebrow: string;
  title: string;
  description: string;
  items: readonly { title: string; detail: string }[];
};

export const mockContent: Record<FeatureKey, FeatureContent> = {
  home: { eyebrow: 'YOUR DAILY QUEST', title: 'A little English, every day', description: 'Build your rhythm with one short lesson and a real-world phrase.', items: [
    { title: 'Today’s mission', detail: 'Practice 5 useful phrases · 10 min' },
    { title: 'Quick review', detail: '3 flashcards ready for you' },
    { title: 'Streak preview', detail: 'Your first day starts now' },
  ] },
  journey: { eyebrow: 'LEARNING PATH', title: 'Your journey starts here', description: 'Follow a simple path from everyday greetings to confident conversations.', items: [
    { title: '01 · First hello', detail: 'Greetings and introductions' },
    { title: '02 · At the café', detail: 'Order with confidence' },
    { title: '03 · Around town', detail: 'Ask for directions' },
  ] },
  explore: { eyebrow: 'REAL ENGLISH', title: 'Explore beyond the textbook', description: 'Discover the words and phrases people actually use.', items: [
    { title: 'Slang spotlight', detail: '“No worries” · It’s okay' },
    { title: 'Idiom of the day', detail: '“Break the ice” · Start a conversation' },
    { title: 'Phrasal verbs', detail: '“Look up” · Search for information' },
  ] },
  coach: { eyebrow: 'PRACTICE SPACE', title: 'Meet your AI Coach', description: 'A guided practice area is being prepared. Start with these offline prompts.', items: [
    { title: 'Speak', detail: 'Introduce yourself in two sentences' },
    { title: 'Write', detail: 'Describe your ideal weekend' },
    { title: 'Reflect', detail: 'What new phrase did you use today?' },
  ] },
  profile: { eyebrow: 'YOUR SPACE', title: 'Make it yours', description: 'Your learning preferences and progress will live here.', items: [
    { title: 'Learning goal', detail: '10 minutes a day · sample setting' },
    { title: 'Current level', detail: 'Beginner · sample setting' },
  ] },
};

export async function getMockContent(key: FeatureKey): Promise<FeatureContent> {
  return mockContent[key];
}
