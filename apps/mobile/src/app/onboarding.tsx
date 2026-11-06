import { router } from 'expo-router';
import { Text, View } from 'react-native';
import { ActionButton, Page } from '@/components/page';
import { useAppPalette } from '@/constants/app-theme';

export default function Onboarding() {
  const palette = useAppPalette();
  return <Page eyebrow="YOUR FIRST STEP" title="Make English part of your day" description="Your plan will adapt as you learn. For now, explore a sample path and see what’s ahead.">
    {['Choose a daily goal', 'Learn with real conversations', 'Review at the right time'].map((step, index) => <View key={step} style={{ backgroundColor: palette.surface, borderRadius: 16, padding: 18, borderColor: palette.border, borderWidth: 1 }}><Text style={{ color: palette.primary, fontWeight: '800' }}>0{index + 1}</Text><Text style={{ color: palette.text, fontSize: 17, fontWeight: '700', marginTop: 5 }}>{step}</Text></View>)}
    <ActionButton label="Explore my dashboard" onPress={() => router.replace('/home')} />
  </Page>;
}
