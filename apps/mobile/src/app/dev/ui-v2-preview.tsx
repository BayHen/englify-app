import { Redirect, useLocalSearchParams } from 'expo-router';
import { HomeScreen } from '@/features/home/home-screen';
import { ExploreScreen, PracticeScreen } from '@/features/home/tool-hub';
import { AdventurePath } from '@/features/learning/adventure-path';
import { Page } from '@/components/page';
import { AppText } from '@/ui';
import { VoicePreview } from '@/features/speaking/voice-preview';
import AccountSettings from '@/app/account-settings';
import EditProfile from '@/app/edit-profile';
import ChangeAvatar from '@/app/change-avatar';
import ChangePassword from '@/app/change-password';
import LearningPreferences from '@/app/learning-preferences';
import { ProfileScreen } from '@/features/home/profile-screen';
import type { GamificationOverview } from '@/features/gamification/api';
import type { JourneyCourse } from '@/features/learning/api';

const overview: GamificationOverview = {
  total_xp: 240, level: 3, xp_into_level: 40, xp_for_next_level: 100, available_xp: 120,
  quests: [
    { id: 'preview-quest-1', title: 'Learn useful words', description: 'Explore vocabulary', period: 'daily', progress: 3, target: 10, reward_xp: 20, completed: false },
    { id: 'preview-quest-2', title: 'Complete a lesson', description: 'Keep moving', period: 'daily', progress: 0, target: 1, reward_xp: 30, completed: false },
    { id: 'preview-quest-3', title: 'Practice speaking', description: 'Say it aloud', period: 'daily', progress: 1, target: 1, reward_xp: 15, completed: true },
  ],
  badges: [{ id: 'preview-badge', title: 'First step', description: 'Sample badge', unlocked: true, unlocked_at: null }],
  rewards: [], statistics: { completed_lessons: 1, mastered_lessons: 0, quiz_attempts: 2, correct_answers: 4 },
};
const courses: JourneyCourse[] = [{ id: 'preview-course', title: 'Everyday English', units: [{ id: 'preview-unit', title: 'First conversations', position: 1, lessons: [
  { id: 'preview-lesson-1', title: 'Say hello', objective: 'Greet someone', position: 1, state: 'completed' },
  { id: 'preview-lesson-2', title: 'Keep it going', objective: 'Ask a follow-up question', position: 2, state: 'available' },
] }] }];

export default function UiV2Preview() {
  const { screen } = useLocalSearchParams<{ screen?: string }>();
  if (!__DEV__) return <Redirect href="/login" />;
  if (screen === 'explore') return <ExploreScreen />;
  if (screen === 'voice') return <VoicePreview />;
  if (screen === 'profile') return <ProfileScreen preview={overview} />;
  if (screen === 'account-settings') return <AccountSettings />;
  if (screen === 'edit-profile') return <EditProfile />;
  if (screen === 'change-avatar') return <ChangeAvatar />;
  if (screen === 'change-password') return <ChangePassword />;
  if (screen === 'learning-preferences') return <LearningPreferences />;
  if (screen === 'practice') return <PracticeScreen />;
  if (screen === 'journey') return <Page eyebrow="DESIGN PREVIEW · SAMPLE DATA" title="Your adventure" description="No progress is saved." compact><AppText variant="heading">Everyday English</AppText><AdventurePath unit={courses[0].units[0]} /></Page>;
  return <HomeScreen preview={{ overview, courses }} />;
}
