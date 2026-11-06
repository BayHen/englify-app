import type { ReactNode } from 'react';
import { Link, type Href } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useAppPalette } from '@/constants/app-theme';

export function Page({ eyebrow, title, description, children }: { eyebrow: string; title: string; description: string; children: ReactNode }) {
  const palette = useAppPalette();
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: palette.background }} edges={['top', 'bottom']}>
      <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        <View style={styles.content}>
          <Text style={[styles.brand, { color: palette.primary }]}>ENGLIFY QUEST</Text>
          <Text style={[styles.eyebrow, { color: palette.primary }]}>{eyebrow}</Text>
          <Text accessibilityRole="header" style={[styles.title, { color: palette.text }]}>{title}</Text>
          <Text style={[styles.description, { color: palette.muted }]}>{description}</Text>
          <View style={styles.body}>{children}</View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

export function ActionButton({ label, onPress, secondary = false }: { label: string; onPress: () => void; secondary?: boolean }) {
  const palette = useAppPalette();
  return (
    <Pressable accessibilityRole="button" onPress={onPress} style={({ pressed }) => [styles.button, { backgroundColor: secondary ? palette.surface : palette.primary, borderColor: palette.border, opacity: pressed ? 0.78 : 1 }]}>
      <Text style={[styles.buttonLabel, { color: secondary ? palette.text : '#FFFFFF' }]}>{label}</Text>
    </Pressable>
  );
}

export function NavLink({ href, label }: { href: Href; label: string }) {
  const palette = useAppPalette();
  return (
    <Link href={href} asChild>
      <Pressable accessibilityRole="link" style={({ pressed }) => [styles.link, { borderColor: palette.border, backgroundColor: palette.surface, opacity: pressed ? 0.75 : 1 }]}>
        <Text style={[styles.linkLabel, { color: palette.text }]}>{label}</Text>
        <Text style={{ color: palette.primary, fontSize: 18 }}>›</Text>
      </Pressable>
    </Link>
  );
}

const styles = StyleSheet.create({
  scroll: { flexGrow: 1, alignItems: 'center', paddingHorizontal: 20, paddingBottom: 24 },
  content: { width: '100%', maxWidth: 560, paddingTop: 20 },
  brand: { fontSize: 13, letterSpacing: 3, fontWeight: '900', marginBottom: 42 },
  eyebrow: { fontSize: 12, letterSpacing: 2, fontWeight: '800', marginBottom: 10 },
  title: { fontSize: 34, lineHeight: 40, fontWeight: '800', marginBottom: 12 },
  description: { fontSize: 16, lineHeight: 24 },
  body: { gap: 12, marginTop: 32 },
  button: { minHeight: 52, borderRadius: 16, borderWidth: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 16 },
  buttonLabel: { fontSize: 16, fontWeight: '700' },
  link: { minHeight: 56, borderRadius: 16, borderWidth: 1, paddingHorizontal: 18, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  linkLabel: { fontSize: 16, fontWeight: '700' },
});
