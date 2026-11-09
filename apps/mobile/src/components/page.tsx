import type { ReactNode } from 'react';
import { Link, usePathname, type Href } from 'expo-router';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { SymbolView } from 'expo-symbols';
import { useAppPalette } from '@/constants/app-theme';
import { designTokens } from '@englify/shared';
import { AppButton, AppText } from '@/ui';
import { isQuestRoute, QuestTabBar } from './quest-tab-bar';
import { FoxMascot } from './fox-mascot';

const screenIcons = {
  '/dictionary': { ios: 'text.book.closed.fill', android: 'menu_book', web: 'menu_book' },
  '/translation': { ios: 'arrow.left.arrow.right', android: 'translate', web: 'translate' },
  '/real-english': { ios: 'bubble.left.and.bubble.right.fill', android: 'forum', web: 'forum' },
  '/speaking': { ios: 'mic.fill', android: 'mic', web: 'mic' },
  '/writing': { ios: 'pencil.line', android: 'edit', web: 'edit' },
  '/quiz-arena': { ios: 'checkmark.circle.fill', android: 'quiz', web: 'quiz' },
  '/rewards': { ios: 'star.fill', android: 'star', web: 'star' },
  '/profile': { ios: 'person.crop.circle.fill', android: 'account_circle', web: 'account_circle' },
  '/learning-plan': { ios: 'calendar', android: 'calendar_month', web: 'calendar_month' },
  '/coach': { ios: 'sparkles', android: 'auto_awesome', web: 'auto_awesome' },
} as const;

export function Page({ eyebrow, title, description, children, compact = false, headerAccessory }: { eyebrow: string; title: string; description: string; children: ReactNode; compact?: boolean; headerAccessory?: ReactNode }) {
  const palette = useAppPalette();
  const path = usePathname();
  const condensed = compact || isQuestRoute(path);
  const symbol = screenIcons[path as keyof typeof screenIcons];
  const accessory = headerAccessory ?? (symbol ? <View style={{ width: 56, height: 56, borderRadius: 19, backgroundColor: palette.primarySoft, alignItems: 'center', justifyContent: 'center' }}><SymbolView name={symbol} size={28} tintColor={palette.primary} /></View> : ['/login', '/register', '/onboarding'].includes(path) ? <FoxMascot size={62} /> : null);
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: palette.background }} edges={['top', 'bottom']}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>
      <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        <View style={styles.content}>
          {!condensed ? <AppText variant="label" tone="primary" style={styles.brand}>ENGLIFY QUEST</AppText> : null}
          <AppText variant="caption" tone="primary" style={styles.eyebrow}>{eyebrow}</AppText>
          <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: designTokens.spacing.md }}><AppText variant={condensed ? 'title' : 'display'} accessibilityRole="header" style={[styles.title, { flexShrink: 1 }]}>{title}</AppText>{accessory}</View>
          {description ? <AppText tone="muted" style={styles.description}>{description}</AppText> : null}
          <View style={[styles.body, condensed && { marginTop: designTokens.spacing.lg }]}>{children}</View>
        </View>
      </ScrollView>
      </KeyboardAvoidingView>
      <QuestTabBar />
    </SafeAreaView>
  );
}

export function ActionButton({ label, onPress, secondary = false }: { label: string; onPress: () => void; secondary?: boolean }) {
  return <AppButton label={label} onPress={onPress} variant={secondary ? 'secondary' : 'primary'} size="large" />;
}

export function NavLink({ href, label }: { href: Href; label: string }) {
  const palette = useAppPalette();
  return (
    <Link href={href} asChild>
      <Pressable accessibilityRole="link" style={({ pressed }) => [styles.link, { borderColor: palette.border, backgroundColor: palette.surface, opacity: pressed ? 0.75 : 1 }]}>
        <AppText variant="label" style={styles.linkLabel}>{label}</AppText>
        <Text style={{ color: palette.primary, fontSize: 18 }}>›</Text>
      </Pressable>
    </Link>
  );
}

const styles = StyleSheet.create({
  scroll: { flexGrow: 1, alignItems: 'center', paddingHorizontal: designTokens.spacing.lg, paddingBottom: designTokens.spacing.xl },
  content: { width: '100%', maxWidth: 560, paddingTop: designTokens.spacing.md },
  brand: { letterSpacing: 3, marginBottom: designTokens.spacing.xl },
  eyebrow: { letterSpacing: 2, fontWeight: '800', marginBottom: 10 },
  title: { marginBottom: designTokens.spacing.md },
  description: { fontSize: designTokens.typography.size.md, lineHeight: designTokens.typography.lineHeight.md },
  body: { gap: designTokens.spacing.md, marginTop: designTokens.spacing.xl },
  link: { minHeight: 56, borderRadius: 16, borderWidth: 1, paddingHorizontal: 18, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  linkLabel: { fontSize: designTokens.typography.size.md, flex: 1 },
});
