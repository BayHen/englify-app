import { useLocalSearchParams, usePathname, router, type Href } from 'expo-router';
import { SymbolView } from 'expo-symbols';
import { Pressable, View } from 'react-native';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from '@/ui';
import { useI18n, type TranslationKey } from '@/i18n';
import { shouldNavigateToTab } from './tab-navigation';

const tabs = [
  { label: 'nav.home', href: '/home', icon: { ios: 'house.fill', android: 'home', web: 'home' } },
  { label: 'nav.journey', href: '/journey', icon: { ios: 'map.fill', android: 'map', web: 'map' } },
  { label: 'nav.explore', href: '/explore', icon: { ios: 'safari.fill', android: 'explore', web: 'explore' } },
  { label: 'nav.practice', href: '/practice', icon: { ios: 'pencil.circle.fill', android: 'edit', web: 'edit' } },
  { label: 'nav.profile', href: '/profile', icon: { ios: 'person.crop.circle.fill', android: 'account_circle', web: 'account_circle' } },
] as const;
const protectedPaths = new Set(['/home', '/journey', '/explore', '/practice', '/profile', '/dictionary', '/translation', '/real-english', '/speaking', '/writing', '/quiz-arena', '/rewards', '/learning-plan', '/coach']);
export function isQuestRoute(path: string) { return protectedPaths.has(path) || path.startsWith('/lesson/') || (__DEV__ && path === '/dev/ui-v2-preview'); }

export function QuestTabBar() {
  const path = usePathname();
  const { screen } = useLocalSearchParams<{ screen?: string }>();
  const palette = useAppPalette();
  const { t } = useI18n();
  if (!isQuestRoute(path)) return null;
  const active = path === '/dictionary' || path === '/translation' || path === '/real-english' ? '/explore'
    : path === '/speaking' || path === '/writing' || path === '/quiz-arena' ? '/practice'
    : path === '/learning-plan' || path.startsWith('/lesson/') ? '/journey'
    : path === '/rewards' ? '/profile' : path === '/dev/ui-v2-preview' ? (screen === 'journey' ? '/journey' : screen === 'explore' ? '/explore' : screen === 'practice' || screen === 'voice' ? '/practice' : '/home') : path;
  return <View accessibilityRole="tablist" style={{ flexDirection: 'row', backgroundColor: palette.surface, borderTopWidth: 1, borderColor: palette.border, paddingTop: 8, paddingBottom: 4, paddingHorizontal: 8 }}>
    {tabs.map((tab) => {
      const selected = active === tab.href;
      const label = t(tab.label as TranslationKey);
      return <Pressable key={tab.href} accessibilityRole="tab" accessibilityLabel={label} accessibilityState={{ selected }} onPress={() => { if (shouldNavigateToTab(path,tab.href)) router.replace(tab.href as Href); }} style={({ pressed }) => ({ flex: 1, minHeight: 54, alignItems: 'center', justifyContent: 'center', gap: 2, borderRadius: 16, backgroundColor: selected ? palette.primarySoft : 'transparent', opacity: pressed ? 0.7 : 1 })}>
        <SymbolView name={tab.icon} size={22} tintColor={selected ? palette.primary : palette.muted} fallback={<AppText>{label.slice(0, 1)}</AppText>} />
        <AppText variant="caption" numberOfLines={1} adjustsFontSizeToFit style={{ color: selected ? palette.primary : palette.muted, fontWeight: selected ? '800' : '600', fontSize: 11 }}>{label}</AppText>
      </Pressable>;
    })}
  </View>;
}
