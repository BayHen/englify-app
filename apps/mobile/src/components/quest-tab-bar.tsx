import { useLocalSearchParams, usePathname, router, type Href } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, View } from 'react-native';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from '@/ui';

const tabs = [
  { label: 'Home', href: '/home', icon: { ios: 'house.fill', android: 'home', web: 'home' } },
  { label: 'Journey', href: '/journey', icon: { ios: 'map.fill', android: 'map', web: 'map' } },
  { label: 'Explore', href: '/explore', icon: { ios: 'safari.fill', android: 'explore', web: 'explore' } },
  { label: 'Practice', href: '/practice', icon: { ios: 'pencil.circle.fill', android: 'edit', web: 'edit' } },
  { label: 'Profile', href: '/profile', icon: { ios: 'person.crop.circle.fill', android: 'account_circle', web: 'account_circle' } },
] as const;
const protectedPaths = new Set(['/home', '/journey', '/explore', '/practice', '/profile', '/dictionary', '/translation', '/real-english', '/speaking', '/writing', '/quiz-arena', '/rewards', '/learning-plan', '/coach']);
export function isQuestRoute(path: string) { return protectedPaths.has(path) || path.startsWith('/lesson/') || (__DEV__ && path === '/dev/ui-v2-preview'); }

export function QuestTabBar() {
  const path = usePathname();
  const { screen } = useLocalSearchParams<{ screen?: string }>();
  const palette = useAppPalette();
  if (!isQuestRoute(path)) return null;
  const active = path === '/dictionary' || path === '/translation' || path === '/real-english' ? '/explore'
    : path === '/speaking' || path === '/writing' || path === '/quiz-arena' ? '/practice'
    : path === '/learning-plan' || path.startsWith('/lesson/') ? '/journey'
    : path === '/rewards' ? '/profile' : path === '/dev/ui-v2-preview' ? (screen === 'journey' ? '/journey' : screen === 'explore' ? '/explore' : screen === 'practice' ? '/practice' : '/home') : path;
  return <View accessibilityRole="tablist" style={{ flexDirection: 'row', backgroundColor: palette.surface, borderTopWidth: 1, borderColor: palette.border, paddingTop: 8, paddingBottom: 4, paddingHorizontal: 8 }}>
    {tabs.map((tab) => {
      const selected = active === tab.href;
      return <Pressable key={tab.href} accessibilityRole="tab" accessibilityLabel={tab.label} accessibilityState={{ selected }} onPress={() => router.replace(tab.href as Href)} style={({ pressed }) => ({ flex: 1, minHeight: 54, alignItems: 'center', justifyContent: 'center', gap: 2, borderRadius: 16, backgroundColor: selected ? palette.primarySoft : 'transparent', opacity: pressed ? 0.7 : 1 })}>
        <SymbolView name={tab.icon} size={22} tintColor={selected ? palette.primary : palette.muted} fallback={<AppText>{tab.label.slice(0, 1)}</AppText>} />
        <AppText variant="caption" style={{ color: selected ? palette.primary : palette.muted, fontWeight: selected ? '800' : '600', fontSize: 11 }}>{tab.label}</AppText>
      </Pressable>;
    })}
  </View>;
}
