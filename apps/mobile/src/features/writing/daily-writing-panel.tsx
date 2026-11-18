import { useWindowDimensions, View } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AchievementBadge, AppButton, AppCard, AppInput, AppText, EmptyState } from '@/ui';
import type { DailyWritingOverview } from './api';

type Props = {
  overview: DailyWritingOverview;
  timezoneDraft: string;
  timezoneBusy: boolean;
  onTimezoneChange: (value: string) => void;
  onSaveTimezone: () => void;
  onStart: () => void;
  onReview: () => void;
};

const dateLabel = (value: string) => {
  const parsed = new Date(`${value.slice(0, 10)}T12:00:00Z`);
  return Number.isNaN(parsed.valueOf()) ? value : parsed.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' });
};

export function DailyWritingPanel({ overview, timezoneDraft, timezoneBusy, onTimezoneChange,
  onSaveTimezone, onStart, onReview }: Props) {
  const palette = useAppPalette();
  const { width: windowWidth } = useWindowDimensions();
  const milestoneBasis = windowWidth < 320 ? '100%' : '40%';
  const challenge = overview.challenge;
  return <View style={{ gap: designTokens.spacing.lg }}>
    <AppCard tone="reward" style={{ gap: designTokens.spacing.md }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', gap: designTokens.spacing.md, alignItems: 'flex-start' }}>
        <View style={{ flex: 1, gap: designTokens.spacing.xs }}>
          <AppText variant="caption" tone="primary">DAILY WRITING · {dateLabel(overview.local_date)}</AppText>
          <AppText variant="title">Today&apos;s challenge</AppText>
          <AppText tone="muted">{overview.selected_cefr_level} · {overview.streak.current_streak} day streak</AppText>
        </View>
        <View accessible accessibilityLabel={`${overview.streak.current_streak} day Writing streak`}
          style={{ minWidth: 70, padding: designTokens.spacing.sm, borderRadius: designTokens.radius.lg,
            backgroundColor: palette.surface, alignItems: 'center' }}>
          <AppText variant="title">{overview.streak.current_streak}</AppText>
          <AppText variant="caption" tone="muted">streak</AppText>
        </View>
      </View>
      {challenge ? <View style={{ gap: designTokens.spacing.sm }}>
        <AppText variant="heading">{challenge.title}</AppText>
        <AppText tone="muted">{challenge.topic ?? 'General'} · {challenge.cefr_level} · {challenge.estimated_minutes ?? '—'} min</AppText>
        <AppText>{challenge.prompt}</AppText>
        <AppText variant="label" tone="primary">Reward confirmed by server: {challenge.xp_reward} XP</AppText>
        <AppButton label={challenge.completed ? 'View completed feedback' : 'Start writing'}
          variant={challenge.completed ? 'secondary' : 'primary'} onPress={challenge.completed ? onReview : onStart}/>
      </View> : overview.enabled
        ? <EmptyState title="No challenge available" message="No published Writing exercise is available for the supported CEFR levels."/>
        : <EmptyState title="Daily Writing is paused" message="You can still use the Writing exercise library below."/>}
    </AppCard>

    <AppCard style={{ gap: designTokens.spacing.md }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', gap: designTokens.spacing.md }}>
        <View style={{ flex: 1 }}><AppText variant="heading">Writing calendar</AppText><AppText tone="muted">Completed and missed days use your server timezone.</AppText></View>
        <AppText variant="label">Best {overview.streak.longest_streak}</AppText>
      </View>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: designTokens.spacing.sm }}>
        {overview.calendar.map((day) => {
          const backgroundColor = day.status === 'completed' ? palette.success : day.status === 'missed'
            ? palette.error : day.status === 'today' ? palette.primary : palette.border;
          const color = ['completed','missed','today'].includes(day.status) ? palette.primaryOn : palette.muted;
          return <View key={day.date} accessible accessibilityLabel={`${dateLabel(day.date)}, ${day.status}`}
            style={{ width: 48, minHeight: 52, borderRadius: designTokens.radius.md, backgroundColor,
              justifyContent: 'center', alignItems: 'center', padding: designTokens.spacing.xs }}>
            <AppText variant="caption" style={{ color }}>{day.date.slice(8,10)}</AppText>
            <AppText variant="caption" style={{ color }}>{day.status === 'completed' ? 'Done' : day.status === 'missed' ? 'Miss' : day.status === 'today' ? 'Today' : '—'}</AppText>
          </View>;
        })}
      </View>
      <AppText variant="caption" tone="muted">A streak stays active through today when yesterday was completed. Future days are never marked missed.</AppText>
    </AppCard>

    <AppCard style={{ gap: designTokens.spacing.md }}>
      <AppText variant="heading">Writing milestones</AppText>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: designTokens.spacing.lg }}>
        {overview.milestones.map((milestone) => <View key={milestone.id} style={{ flexGrow: 1, flexShrink: 1, flexBasis: milestoneBasis, gap: designTokens.spacing.xs }}>
          <AchievementBadge title={milestone.title} description={milestone.description} unlocked={milestone.unlocked} style={{ width: '100%' }}/>
          <AppText variant="caption" tone="muted" style={{ textAlign: 'center' }}>{milestone.progress}/{milestone.target}</AppText>
        </View>)}
      </View>
    </AppCard>

    <AppCard style={{ gap: designTokens.spacing.sm }}>
      <AppText variant="heading">Writing timezone</AppText>
      <AppText tone="muted">Current: {overview.timezone}. A change after your first assignment takes effect at the next midnight in the current timezone.</AppText>
      <AppInput label="IANA timezone" value={timezoneDraft} onChangeText={onTimezoneChange} placeholder="Asia/Ho_Chi_Minh" autoCapitalize="none"/>
      <AppButton label="Save timezone" variant="secondary" loading={timezoneBusy} disabled={!timezoneDraft.trim()} onPress={onSaveTimezone}/>
    </AppCard>
  </View>;
}
