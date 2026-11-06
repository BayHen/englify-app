import { useEffect, useState } from 'react';
import { router, type Href } from 'expo-router';
import { Animated, Pressable, View } from 'react-native';
import { Page, NavLink } from '@/components/page';
import { useAppPalette } from '@/constants/app-theme';
import { useAppStore, type ThemeMode } from '@/state/app-store';
import { AchievementBadge, AppBottomSheet, AppButton, AppCard, AppInput, AppModal, AppText, EmptyState, LessonNode, QuestCard, RewardCard, XPProgressBar } from '@/ui';
import { useReducedMotion } from '@/ui/use-reduced-motion';
import { useAuth } from '@/auth/provider';
import { badges, checkDraft, featureLinks, lessons, phrases, quizQuestions, rewards, searchWords, translateSample, writingPrompts, type FeatureLink, type Lesson, type Phrase, type Reward } from './data';

function DemoNotice({ children = 'Sample content · Progress is for illustration only.' }: { children?: string }) {
  return <AppCard tone="primary" style={{ padding: 14 }}><AppText variant="caption" tone="primary">{children}</AppText></AppCard>;
}
function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return <View style={{ gap: 12 }}><AppText variant="heading" accessibilityRole="header">{title}</AppText>{children}</View>;
}
function FeatureTile({ item }: { item: FeatureLink }) {
  const palette = useAppPalette();
  return <AppCard onPress={() => router.push(item.href as Href)} accessibilityLabel={`Open ${item.title}`} style={{ flexDirection: 'row', alignItems: 'center', gap: 16, padding: 16 }}>
    <View style={{ width: 48, height: 48, borderRadius: 16, backgroundColor: palette.primarySoft, alignItems: 'center', justifyContent: 'center' }}><AppText variant="heading" tone="primary">{item.icon}</AppText></View>
    <View style={{ flex: 1 }}><AppText variant="label">{item.title}</AppText><AppText variant="caption" tone="muted">{item.detail}</AppText></View><AppText tone="primary">›</AppText>
  </AppCard>;
}
function FeatureGrid({ links }: { links: FeatureLink[] }) { return <View style={{ gap: 10 }}>{links.map((item) => <FeatureTile key={item.href} item={item} />)}</View>; }
function Shell({ eyebrow, title, description, children }: { eyebrow: string; title: string; description: string; children: React.ReactNode }) {
  return <Page eyebrow={eyebrow} title={title} description={description}><DemoNotice />{children}<NavLink href="/home" label="Back to dashboard" /></Page>;
}
function Choice({ label, selected, onPress }: { label: string; selected: boolean; onPress: () => void }) {
  const palette = useAppPalette();
  return <Pressable accessibilityRole="button" accessibilityState={{ selected }} accessibilityLabel={label} onPress={onPress} style={{ borderWidth: 1.5, borderColor: selected ? palette.primary : palette.border, backgroundColor: selected ? palette.primarySoft : palette.surface, borderRadius: 16, padding: 15, minHeight: 52, justifyContent: 'center' }}><AppText weight={selected ? 'bold' : 'regular'}>{label}</AppText></Pressable>;
}

export function HomeScreen() {
  const name = useAppStore((state) => state.displayName);
  return <Shell eyebrow="YOUR QUEST BEGINS" title={`Hello${name ? `, ${name}` : ', explorer'}!`} description="Choose a small step and enjoy learning English today.">
    <AppCard tone="primary" style={{ gap: 14 }}><AppText variant="heading">Sample adventurer · Level 2</AppText><XPProgressBar value={68} max={100} label="Sample XP toward level 3" /><AppText variant="caption" tone="muted">This level and XP are illustrative; no progress is saved.</AppText></AppCard>
    <Section title="Daily quest preview"><QuestCard title="Learn three expressions" description="Explore everyday English phrases." rewardXp={25} progress={1} target={3} onPress={() => router.push('/real-english' as Href)} /></Section>
    <Section title="Pick your next adventure"><FeatureGrid links={featureLinks} /></Section>
    <Section title="Badge preview"><View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-around' }}>{badges.map((badge) => <AchievementBadge key={badge.title} {...badge} />)}</View></Section>
    <FeatureGrid links={[{ title: 'Profile', detail: 'Theme and demo account', href: '/profile', icon: '◉' }, { title: 'AI Coach preview', detail: 'Guided speaking and writing', href: '/coach', icon: '✧' }]} />
  </Shell>;
}
export function JourneyScreen() {
  const [selected, setSelected] = useState<Lesson | null>(null);
  return <Shell eyebrow="YOUR PATH" title="Journey map" description="Preview a gentle path from greetings to real conversations.">
    <Section title="Chapter 1 · Everyday conversation"><AppCard style={{ gap: 10 }}>{lessons.map((lesson, index) => <LessonNode key={lesson.title} title={lesson.title} order={index + 1} status={lesson.status} onPress={() => setSelected(lesson)} />)}</AppCard></Section>
    <AppCard tone="reward"><AppText variant="heading">Next: Keep it going</AppText><AppText tone="muted">Practice a friendly follow-up question, then try the sample quiz.</AppText><AppButton label="Play sample quiz" onPress={() => router.push('/quiz-arena' as Href)} /></AppCard>
    <AppBottomSheet visible={!!selected} title={selected?.title ?? 'Lesson'} onClose={() => setSelected(null)}><AppText>{selected?.detail}</AppText><AppText tone="muted">Lesson completion is a sample state. Practice activities do not award XP.</AppText><AppButton label="Practice speaking" onPress={() => { setSelected(null); router.push('/speaking' as Href); }} /></AppBottomSheet>
  </Shell>;
}
export function ExploreScreen() { return <Shell eyebrow="EXPLORE" title="Find your words" description="Browse a small offline collection of words and expressions."><Section title="Language tools"><FeatureGrid links={featureLinks.slice(1, 4)} /></Section><Section title="Practice room"><FeatureGrid links={featureLinks.slice(4, 7)} /></Section></Shell>; }
export function CoachScreen() { return <Shell eyebrow="GUIDED PRACTICE" title="Coach preview" description="Choose a prompt and practice at your own pace. AI feedback is not connected yet."><Section title="Try a practice mode"><FeatureGrid links={featureLinks.slice(4, 6)} /></Section><AppCard tone="primary"><AppText variant="heading">A practice idea for today</AppText><AppText>Describe a place you enjoy visiting. Say it aloud, then write two sentences.</AppText></AppCard></Shell>; }
export function DictionaryScreen() {
  const [query, setQuery] = useState('');
  const results = searchWords(query);
  return <Shell eyebrow="WORD LAB" title="Dictionary" description="Search a curated English–Vietnamese sample word list."><AppInput label="Search words or meanings" placeholder="Try curious or tò mò" value={query} onChangeText={setQuery} autoCapitalize="none" />
    <Section title={`${results.length} sample ${results.length === 1 ? 'word' : 'words'}`}>{results.length ? results.map((entry) => <AppCard key={entry.word} style={{ gap: 6 }}><AppText variant="heading">{entry.word} <AppText variant="caption" tone="muted">{entry.pronunciation}</AppText></AppText><AppText tone="primary">{entry.category} · {entry.meaning}</AppText><AppText>{entry.example}</AppText></AppCard>) : <EmptyState title="No sample word found" message="Try curious, journey, practice, or reward. This is a small offline list." actionLabel="Clear search" onAction={() => setQuery('')} />}</Section>
  </Shell>;
}
export function TranslationScreen() {
  const [input, setInput] = useState('');
  const [submitted, setSubmitted] = useState('');
  const phrase = translateSample(submitted);
  const fromEnglish = phrase?.english.toLocaleLowerCase().replace(/[.!?]/g, '').trim() === submitted.toLocaleLowerCase().replace(/[.!?]/g, '').trim();
  return <Shell eyebrow="PHRASE PAIRS" title="Translation" description="Try a curated English–Vietnamese phrase. This is a local lookup, not general translation."><AppInput label="Phrase to look up" placeholder="Try How is it going?" value={input} onChangeText={setInput} /><AppButton label="Find sample translation" onPress={() => setSubmitted(input.trim())} disabled={!input.trim()} />
    {submitted ? phrase ? <AppCard tone="primary" style={{ gap: 8 }}><AppText variant="caption" tone="primary">SAMPLE TRANSLATION</AppText><AppText variant="heading">{fromEnglish ? phrase.vietnamese : phrase.english}</AppText><AppText tone="muted">{phrase.note}</AppText></AppCard> : <EmptyState title="Phrase not in sample set" message="Try one of the phrase suggestions below. No translation service is connected." /> : <EmptyState title="Ready for a phrase?" message="Choose a suggestion or type a phrase from the sample collection." />}
    <Section title="Try these phrases">{phrases.slice(0, 3).map((item) => <Choice key={item.english} label={item.english} selected={input === item.english} onPress={() => { setInput(item.english); setSubmitted(item.english); }} />)}</Section>
  </Shell>;
}
export function RealEnglishScreen() {
  const [category, setCategory] = useState<Phrase['category'] | 'all'>('all');
  const visible = category === 'all' ? phrases : phrases.filter((phrase) => phrase.category === category);
  return <Shell eyebrow="IN THE WILD" title="Real English" description="Meet expressions you might hear in everyday conversations."><Section title="Browse by type"><View style={{ gap: 8 }}>{(['all', 'conversation', 'idiom', 'phrasal verb'] as const).map((item) => <Choice key={item} label={item === 'all' ? 'All expressions' : item} selected={category === item} onPress={() => setCategory(item)} />)}</View></Section>
    <Section title={`${visible.length} sample expressions`}>{visible.length ? visible.map((phrase) => <AppCard key={phrase.english} style={{ gap: 6 }}><AppText variant="caption" tone="primary">{phrase.category.toUpperCase()}</AppText><AppText variant="heading">{phrase.english}</AppText><AppText tone="primary">{phrase.vietnamese}</AppText><AppText tone="muted">{phrase.note}</AppText></AppCard>) : <EmptyState title="No expressions here" message="Try another category." />}</Section>
  </Shell>;
}
const speakingPrompts = ['How is it going?', 'I practice English every day.', 'Every journey starts with one step.'] as const;
export function SpeakingScreen() {
  const [prompt, setPrompt] = useState<string>(speakingPrompts[0]);
  const [stage, setStage] = useState<'ready' | 'practiced'>('ready');
  return <Shell eyebrow="SAY IT OUT LOUD" title="Speaking" description="Read a sample line aloud, then reflect on your own practice. Recording and scoring are not connected.">
    <Section title="Choose a line">{speakingPrompts.map((item) => <Choice key={item} label={item} selected={prompt === item} onPress={() => { setPrompt(item); setStage('ready'); }} />)}</Section>
    <AppCard tone="primary" style={{ gap: 12 }}><AppText variant="caption" tone="primary">YOUR PRACTICE LINE</AppText><AppText variant="title">“{prompt}”</AppText><AppText tone="muted">Say it slowly, then once at a natural pace. Notice the rhythm of the sentence.</AppText><AppButton label="I practiced this line" onPress={() => setStage('practiced')} /></AppCard>
    {stage === 'practiced' && <AppCard tone="reward"><AppText variant="heading">Nice practice!</AppText><AppText>Your self-check is local to this screen. No pronunciation score or XP was awarded.</AppText></AppCard>}
  </Shell>;
}
export function WritingScreen() {
  const [prompt, setPrompt] = useState<string>(writingPrompts[0]);
  const [draft, setDraft] = useState('');
  const [checked, setChecked] = useState(false);
  const checks = checkDraft(draft);
  return <Shell eyebrow="WRITE YOUR STORY" title="Writing" description="Draft a short answer and use a simple local checklist. This is not AI grading."><Section title="Choose a prompt">{writingPrompts.map((item) => <Choice key={item} label={item} selected={prompt === item} onPress={() => { setPrompt(item); setChecked(false); }} />)}</Section>
    <AppCard tone="primary"><AppText variant="heading">{prompt}</AppText></AppCard><AppInput label="Your draft" placeholder="Start writing here..." value={draft} onChangeText={(value) => { setDraft(value); setChecked(false); }} multiline style={{ minHeight: 130, textAlignVertical: 'top', paddingVertical: 14 }} hint="Drafts stay on this screen and are not sent anywhere." />
    <AppText variant="caption" tone="muted">{draft.trim() ? draft.trim().split(/\s+/).length : 0} words</AppText><AppButton label="Check my draft" onPress={() => setChecked(true)} disabled={!draft.trim()} />
    {checked ? <AppCard style={{ gap: 8 }}><AppText variant="heading">Writing checklist</AppText>{['At least 8 words', 'Starts with a capital letter', 'Ends with punctuation'].map((item) => <AppText key={item} tone={checks.includes(item) ? 'success' : 'muted'}>{checks.includes(item) ? '✓' : '○'} {item}</AppText>)}<AppText variant="caption" tone="muted">These are simple format checks, not a language assessment.</AppText></AppCard> : !draft && <EmptyState title="Your page is ready" message="Pick a prompt and write a few sentences to see the local checklist." />}
  </Shell>;
}
export function QuizArenaScreen() {
  const [index, setIndex] = useState(0);
  const [selected, setSelected] = useState<number | null>(null);
  const [score, setScore] = useState(0);
  const [finished, setFinished] = useState(false);
  const reduced = useReducedMotion();
  const [scale] = useState(() => new Animated.Value(1));
  const question = quizQuestions[index];
  useEffect(() => { if (finished && !reduced) { Animated.sequence([Animated.timing(scale, { toValue: 1.12, duration: 180, useNativeDriver: true }), Animated.spring(scale, { toValue: 1, useNativeDriver: true })]).start(); } }, [finished, reduced, scale]);
  function next() { if (index + 1 === quizQuestions.length) setFinished(true); else { setIndex(index + 1); setSelected(null); } }
  function reset() { setIndex(0); setSelected(null); setScore(0); setFinished(false); }
  return <Shell eyebrow="PLAY TO LEARN" title="Quiz Arena" description="Answer three local sample questions. Scores and rewards are not saved."><XPProgressBar value={index + (selected === null ? 0 : 1)} max={quizQuestions.length} label="Sample quiz progress" />
    <AppCard tone="primary" style={{ gap: 14 }}><AppText variant="caption" tone="primary">QUESTION {index + 1} OF {quizQuestions.length}</AppText><AppText variant="heading">{question.prompt}</AppText>{question.options.map((option, optionIndex) => <Choice key={option} label={option} selected={selected === optionIndex} onPress={() => { if (selected === null) { setSelected(optionIndex); if (optionIndex === question.answer) setScore(score + 1); } }} />)}</AppCard>
    {selected !== null && <AppCard tone={selected === question.answer ? 'reward' : 'surface'} style={{ gap: 8 }}><AppText variant="heading" tone={selected === question.answer ? 'success' : 'error'}>{selected === question.answer ? 'Correct!' : 'Good try'}</AppText><AppText>{question.explanation}</AppText><AppButton label={index + 1 === quizQuestions.length ? 'See sample result' : 'Next question'} onPress={next} /></AppCard>}
    <AppModal visible={finished} title="Sample quiz complete" onClose={() => setFinished(false)}><Animated.View style={{ transform: [{ scale }] }}><AppText variant="display" tone="reward" style={{ textAlign: 'center' }}>★</AppText></Animated.View><AppText variant="heading" style={{ textAlign: 'center' }}>{score} / {quizQuestions.length} correct</AppText><AppText tone="muted" style={{ textAlign: 'center' }}>A sample reward moment. No XP or badge was added to an account.</AppText><AppButton label="Play again" onPress={reset} variant="reward" /></AppModal>
  </Shell>;
}
export function RewardsScreen() {
  const [selected, setSelected] = useState<Reward | null>(null);
  return <Shell eyebrow="TREASURE ROOM" title="Rewards" description="Preview what a future reward collection could feel like."><AppCard tone="reward"><AppText variant="heading">Sample balance · 68 XP</AppText><AppText tone="muted">Illustrative only. Rewards cannot be redeemed.</AppText></AppCard>
    <Section title="Badge collection preview"><View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-around', gap: 14 }}>{badges.map((badge) => <AchievementBadge key={badge.title} {...badge} />)}</View></Section>
    <Section title="Reward previews">{rewards.map((reward) => <RewardCard key={reward.title} title={reward.title} description={reward.detail} costXp={reward.xp} onPress={() => setSelected(reward)} />)}</Section>
    <AppModal visible={!!selected} title={selected?.title ?? 'Reward'} onClose={() => setSelected(null)}><AppText>{selected?.detail}</AppText><AppText tone="muted">Preview only · {selected?.xp} sample XP. No purchase or redemption is available.</AppText></AppModal>
  </Shell>;
}
export function ProfileScreen() {
  const name = useAppStore((state) => state.displayName);
  const mode = useAppStore((state) => state.themeMode);
  const setMode = useAppStore((state) => state.setThemeMode);
  const { signOut, profile } = useAuth();
  return <Shell eyebrow="YOUR CORNER" title="Profile" description="Your saved learning choices and a preview of future rewards."><AppCard tone="primary"><AppText variant="heading">{name ?? 'Explorer'}</AppText><AppText tone="muted">Saved profile · sample Level 2 · sample 68 XP</AppText>{profile?.preferences && <AppText variant="caption" tone="primary">Goal: {profile.preferences.learning_goal ?? 'not selected'} · Level: {profile.preferences.initial_proficiency ?? 'not selected'} · {profile.preferences.daily_goal_minutes} min/day</AppText>}</AppCard>
    <Section title="Appearance">{(['system', 'light', 'dark'] as ThemeMode[]).map((item) => <Choice key={item} label={`${item[0].toUpperCase()}${item.slice(1)} theme`} selected={mode === item} onPress={() => setMode(item)} />)}</Section>
    <Section title="Badge preview"><View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-around' }}>{badges.map((badge) => <AchievementBadge key={badge.title} {...badge} />)}</View></Section>
    <Section title="More"><FeatureGrid links={[{ title: 'Explore', detail: 'Browse all sample activities', href: '/explore', icon: '◇' }]} /><NavLink href="/dev/showcase" label="UI component showcase" /></Section>
    <AppButton label="Sign out" variant="secondary" onPress={() => { void signOut().finally(() => router.replace('/login')); }} />
  </Shell>;
}
