import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { designTokens } from '@englify/shared';
import { resolvePalette } from '@/constants/app-theme';
import { AchievementBadge } from './achievement-badge';
import { AppButton } from './app-button';
import { AppCard } from './app-card';
import { AppInput } from './app-input';
import { AppText } from './app-text';
import { EmptyState, ErrorState } from './feedback';
import { LessonNode } from './lesson-node';
import { LevelBadge } from './level-badge';
import { QuestCard } from './quest-card';
import { RewardCard } from './reward-card';
import { XPProgressBar, progressRatio } from './xp-progress-bar';

describe('gamified design system', () => {
  it('resolves light and dark palettes with readable surfaces', () => {
    expect(resolvePalette('system', 'light').background).toBe(designTokens.palette.light.background);
    expect(resolvePalette('system', 'dark').background).toBe(designTokens.palette.dark.background);
    expect(resolvePalette('dark', 'light').text).toBe(designTokens.palette.dark.text);
  });

  it('clamps XP progress and renders an accessible bar', () => {
    expect(progressRatio(-5, 100)).toBe(0);
    expect(progressRatio(150, 100)).toBe(1);
    expect(progressRatio(20, 0)).toBe(0);
    const html = renderToStaticMarkup(<XPProgressBar value={25} max={100} label="Level progress" />);
    expect(html).toContain('Level progress');
    expect(html).toContain('25 / 100 XP');
    expect(html).toContain('role="progressbar"');
  });

  it('renders reusable actions, content, and feedback without business defaults', () => {
    const html = renderToStaticMarkup(<>
      <AppText variant="heading">Practice</AppText>
      <AppButton label="Continue" onPress={() => {}} />
      <AppCard><AppText>Card content</AppText></AppCard>
      <AppInput label="Answer" value="hello" onChangeText={() => {}} error="Try again" />
      <EmptyState title="No lessons" message="Come back soon" />
      <ErrorState title="Offline" message="Reconnect" />
    </>);
    for (const label of ['Practice', 'Continue', 'Card content', 'Answer', 'Try again', 'No lessons', 'Offline']) expect(html).toContain(label);
  });

  it('renders game components from supplied values', () => {
    const html = renderToStaticMarkup(<>
      <LevelBadge level={7} title="Explorer" />
      <QuestCard title="Daily quest" description="Two lessons" rewardXp={40} progress={1} target={2} />
      <RewardCard title="Avatar" description="A reward" costXp={80} />
      <LessonNode title="Hello" order={1} status="available" onPress={() => {}} />
      <AchievementBadge title="First step" unlocked />
    </>);
    for (const label of ['Explorer', 'Daily quest', 'Two lessons', '40 XP', 'Avatar', 'Hello', 'First step']) expect(html).toContain(label);
  });

});
