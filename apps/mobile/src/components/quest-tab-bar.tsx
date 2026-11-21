import { useLocalSearchParams, usePathname, router } from 'expo-router';
import { designTokens } from '@englify/shared';
import { SymbolView } from 'expo-symbols';
import { Pressable, View } from 'react-native';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from '@/ui';
import { useI18n } from '@/i18n';
import { shouldNavigateToTab, visibleQuestTabs } from './tab-navigation';
import { useAuth } from '@/auth/provider';

const tabBarPaths = new Set(['/home', '/journey', '/explore', '/practice', '/profile', '/dictionary', '/translation', '/real-english', '/speaking', '/writing', '/quiz-arena', '/rewards', '/learning-plan', '/coach']);
export function isQuestRoute(path: string) { return tabBarPaths.has(path) || path.startsWith('/lesson/') || (__DEV__ && path === '/dev/ui-v2-preview'); }

export function QuestTabBar() {
  const path = usePathname();
  const { screen } = useLocalSearchParams<{ screen?: string }>();
  const palette = useAppPalette();
  const { t } = useI18n();
  const { phase } = useAuth();
  if (!isQuestRoute(path)) return null;
  const dictionary = path === '/dictionary' || (__DEV__ && path === '/dev/ui-v2-preview' && screen === 'dictionary');
  const authenticated = phase === 'authenticated';
  const tabs = visibleQuestTabs(authenticated);
  const active = !authenticated ? (dictionary ? '/dictionary' : path) : path === '/dictionary' || path === '/translation' || path === '/real-english' ? '/explore'
    : path === '/speaking' || path === '/writing' || path === '/quiz-arena' ? '/practice'
    : path === '/learning-plan' || path.startsWith('/lesson/') ? '/journey'
    : path === '/rewards' ? '/profile' : path === '/dev/ui-v2-preview' ? (screen === 'journey' ? '/journey' : screen === 'explore' || dictionary ? '/explore' : screen === 'practice' || screen === 'voice' ? '/practice' : screen === 'profile' || screen === 'account-settings' ? '/profile' : '/home') : path;
  return <View style={{ backgroundColor: palette.background, borderTopWidth: 1, borderColor: palette.border }}>
    <View accessibilityRole="tablist" style={{ flexDirection: 'row', alignSelf: 'center', width: '100%', maxWidth: 560, padding: designTokens.spacing.xs }}>
    {tabs.map((tab) => {
      const selected = active === tab.href;
      const label = t(tab.label);
      return <Pressable key={tab.href} accessibilityRole="tab" accessibilityLabel={label} accessibilityState={{ selected }} onPress={() => {
        if (!shouldNavigateToTab(path, tab.href)) return;
        router.replace(tab.href);
      }} style={({ pressed }) => ({ flex: 1, minWidth: 0, minHeight: 54, alignItems: 'center', justifyContent: 'center', gap: designTokens.spacing.xs, paddingVertical: designTokens.spacing.xs, borderRadius: designTokens.radius.md, opacity: pressed ? 0.7 : 1 })}>
        {selected && !dictionary ? <View pointerEvents="none" style={{ position: 'absolute', width: 24, height: 2, top: 0, borderRadius: 1, backgroundColor: palette.primary }} /> : null}
        <View style={{ alignItems: 'center', justifyContent: 'center', minWidth: dictionary ? 48 : 42, minHeight: 28, borderRadius: designTokens.radius.pill, backgroundColor: dictionary && selected ? palette.primarySoft : 'transparent' }}>
          <SymbolView name={tab.icon} size={22} tintColor={selected ? palette.primary : palette.muted} fallback={<AppText>{label.slice(0, 1)}</AppText>} />
        </View>
        <AppText variant="caption"  style={{ color: selected ? palette.primary : palette.muted, textAlign: 'center', fontWeight: selected ? '800' : '600' }}>{label}</AppText>
      </Pressable>;
    })}
    </View>
  </View>;
}
