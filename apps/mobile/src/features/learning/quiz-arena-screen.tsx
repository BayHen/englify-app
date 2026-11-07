import { useEffect, useState } from 'react';
import { router, type Href } from 'expo-router';
import { Page, NavLink } from '@/components/page';
import { AppCard, AppText, EmptyState, ErrorState, LoadingSkeleton } from '@/ui';
import { getJourney, type JourneyLesson } from './api';

export function QuizArenaScreen() {
  const [lessons, setLessons] = useState<JourneyLesson[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  useEffect(() => {
    void getJourney().then((courses) => setLessons(courses.flatMap((course) => course.units.flatMap((unit) => unit.lessons)).filter((lesson) => lesson.state !== 'locked')))
      .catch((cause) => setError(cause instanceof Error ? cause.message : 'Could not load quizzes'))
      .finally(() => setLoading(false));
  }, []);
  return <Page eyebrow="QUIZ ARENA" title="Practice arena" description="Choose an unlocked lesson. The server checks answers and saves each attempt.">
    {loading ? <LoadingSkeleton /> : error ? <ErrorState message={error} /> : lessons.length ? lessons.map((lesson) => <AppCard key={lesson.id} onPress={() => router.push(`/lesson/${lesson.id}` as Href)} accessibilityLabel={`Open ${lesson.title}`} style={{ gap: 5 }}><AppText variant="heading">{lesson.title}</AppText><AppText tone="muted">{lesson.objective}</AppText><AppText variant="caption" tone="primary">{lesson.state.replace('_', ' ').toUpperCase()}</AppText></AppCard>) : <EmptyState title="No unlocked quizzes" message="Open the Journey Map and start your first lesson." />}
    <AppCard><AppText variant="caption" tone="muted">XP is awarded by the backend once per completed lesson. Replays improve mastery without duplicate rewards.</AppText></AppCard>
    <NavLink href="/journey" label="Open Journey Map" />
  </Page>;
}
