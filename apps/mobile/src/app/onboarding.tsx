import { router } from 'expo-router';
import { View } from 'react-native';
import { Page } from '@/components/page';
import { AppButton, AppCard, AppText } from '@/ui';

export default function Onboarding() {
  return <Page eyebrow="YOUR FIRST STEP" title="Make English part of your day" description="Your plan will adapt as you learn. For now, explore a sample path and see what’s ahead.">
    <AppCard tone="primary"><AppText variant="label" tone="primary">ONBOARDING PREVIEW</AppText><AppText tone="muted">These steps introduce the demo experience. Your choices are not saved.</AppText></AppCard>
    {[
      ['Choose a daily goal', 'Start with one small action that fits your day.'],
      ['Learn with real conversations', 'Explore expressions used in everyday life.'],
      ['Review at the right time', 'See how a lesson path could grow your confidence.'],
    ].map(([step, detail], index) => <AppCard key={step} style={{ flexDirection: 'row', alignItems: 'center', gap: 16 }}><AppText variant="heading" tone="primary">0{index + 1}</AppText><View style={{ flex: 1 }}><AppText variant="label">{step}</AppText><AppText tone="muted">{detail}</AppText></View></AppCard>)}
    <AppButton label="Explore sample dashboard" onPress={() => router.replace('/home')} size="large" />
  </Page>;
}
