import type { ReactNode } from 'react';
import { Link, type Href } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAppPalette } from '@/constants/app-theme';
import { designTokens } from '@englify/shared';
import { AppButton, AppText } from '@/ui';

export function Page({ eyebrow, title, description, children }: { eyebrow: string; title: string; description: string; children: ReactNode }) {
  const palette = useAppPalette();
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: palette.background }} edges={['top', 'bottom']}>
      <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        <View style={styles.content}>
          <AppText variant="label" tone="primary" style={styles.brand}>ENGLIFY QUEST</AppText>
          <AppText variant="caption" tone="primary" style={styles.eyebrow}>{eyebrow}</AppText>
          <AppText variant="display" accessibilityRole="header" style={styles.title}>{title}</AppText>
          <AppText tone="muted" style={styles.description}>{description}</AppText>
          <View style={styles.body}>{children}</View>
        </View>
      </ScrollView>
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
  content: { width: '100%', maxWidth: 560, paddingTop: 20 },
  brand: { letterSpacing: 3, marginBottom: 42 },
  eyebrow: { letterSpacing: 2, fontWeight: '800', marginBottom: 10 },
  title: { marginBottom: designTokens.spacing.md },
  description: { fontSize: designTokens.typography.size.md, lineHeight: designTokens.typography.lineHeight.md },
  body: { gap: designTokens.spacing.md, marginTop: designTokens.spacing.xxl },
  link: { minHeight: 56, borderRadius: 16, borderWidth: 1, paddingHorizontal: 18, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  linkLabel: { fontSize: designTokens.typography.size.md, flex: 1 },
});
