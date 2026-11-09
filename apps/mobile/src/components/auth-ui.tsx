import { useState, type ComponentProps, type ReactNode } from 'react';
import { Link, type Href } from 'expo-router';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, TextInput, View, type TextInputProps } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { SymbolView } from 'expo-symbols';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from '@/ui';

const space = designTokens.spacing;

export function AuthScreenLayout({ title, subtitle, children, footer }: { title: string; subtitle: string; children: ReactNode; footer?: ReactNode }) {
  const palette = useAppPalette();
  return <SafeAreaView edges={['top', 'bottom']} style={{ flex: 1, backgroundColor: palette.background }}>
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={{ flexGrow: 1, alignItems: 'center', paddingHorizontal: space.xl, paddingTop: space.xl, paddingBottom: space.xl }}>
        <View style={{ width: '100%', maxWidth: 440, flexGrow: 1 }}>
          <AuthBrandHeader />
          <View style={{ marginTop: space.xxxl, gap: space.sm }}><AppText variant="title" accessibilityRole="header" style={{ fontFamily: designTokens.typography.family.heavy }}>{title}</AppText><AppText tone="muted" style={{ maxWidth: 360 }}>{subtitle}</AppText></View>
          <View style={{ marginTop: space.xxl, gap: space.xl }}>{children}</View>
          {footer ? <View style={{ marginTop: space.xxl, paddingBottom: space.md }}>{footer}</View> : null}
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  </SafeAreaView>;
}

export function AuthBrandHeader() {
  const palette = useAppPalette();
  return <View style={{ flexDirection: 'row', alignItems: 'center', gap: space.sm }}><View style={{ width: 34, height: 34, borderRadius: 11, backgroundColor: palette.primary, alignItems: 'center', justifyContent: 'center' }}><AppText variant="label" style={{ color: palette.primaryOn }}>E</AppText></View><AppText variant="label" style={{ letterSpacing: 0.3 }}>Englify Quest</AppText></View>;
}

export function AuthTextInput({ label, error, hint, right, style, ...props }: TextInputProps & { label: string; error?: string; hint?: string; right?: ReactNode }) {
  const palette = useAppPalette();
  const [focused, setFocused] = useState(false);
  return <View style={{ gap: space.sm }}><AppText variant="label">{label}</AppText><View style={{ minHeight: 54, flexDirection: 'row', alignItems: 'center', borderRadius: designTokens.radius.md, borderWidth: focused ? 2 : 1, borderColor: error ? palette.error : focused ? palette.primary : palette.border, backgroundColor: palette.input }}><TextInput {...props} accessibilityLabel={label} accessibilityHint={error || hint} placeholderTextColor={palette.muted} onFocus={(event) => { setFocused(true); props.onFocus?.(event); }} onBlur={(event) => { setFocused(false); props.onBlur?.(event); }} style={[{ flex: 1, minWidth: 0, minHeight: 52, paddingHorizontal: space.lg, color: palette.text, fontFamily: designTokens.typography.family.regular, fontSize: designTokens.typography.size.md }, style]} />{right}</View>{error ? <AppText variant="caption" tone="error" accessibilityRole="alert">{error}</AppText> : hint ? <AppText variant="caption" tone="muted">{hint}</AppText> : null}</View>;
}

export function AuthPasswordInput({ label = 'Password', visible, onToggle, ...props }: Omit<ComponentProps<typeof AuthTextInput>, 'right' | 'secureTextEntry' | 'label'> & { label?: string; visible: boolean; onToggle: () => void }) {
  const palette = useAppPalette();
  return <AuthTextInput {...props} label={label} secureTextEntry={!visible} right={<Pressable accessibilityRole="button" accessibilityLabel={visible ? `Hide ${label.toLowerCase()}` : `Show ${label.toLowerCase()}`} onPress={onToggle} style={({ pressed }) => ({ width: 52, minHeight: 52, alignItems: 'center', justifyContent: 'center', opacity: pressed ? 0.65 : 1 })}><SymbolView name={{ ios: visible ? 'eye.slash' : 'eye', android: visible ? 'visibility_off' : 'visibility', web: visible ? 'visibility_off' : 'visibility' }} size={21} tintColor={palette.muted} /></Pressable>} />;
}

export function AuthPrimaryButton({ label, onPress, busy = false, disabled = false }: { label: string; onPress: () => void; busy?: boolean; disabled?: boolean }) {
  const palette = useAppPalette();
  return <Pressable accessibilityRole="button" accessibilityLabel={label} accessibilityState={{ disabled: busy || disabled, busy }} disabled={busy || disabled} onPress={onPress} style={({ pressed }) => ({ minHeight: 54, borderRadius: designTokens.radius.md, backgroundColor: palette.primary, justifyContent: 'center', alignItems: 'center', opacity: disabled ? 0.55 : pressed ? 0.82 : 1 })}><AppText variant="label" style={{ color: palette.primaryOn, fontSize: designTokens.typography.size.md }}>{busy ? 'Please wait…' : label}</AppText></Pressable>;
}

export function AuthInlineLink({ href, label, prefix }: { href: Href; label: string; prefix?: string }) {
  return <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'center', alignItems: 'center', gap: 4 }}>{prefix ? <AppText tone="muted">{prefix}</AppText> : null}<Link href={href} asChild><Pressable accessibilityRole="link" style={({ pressed }) => ({ minHeight: 44, justifyContent: 'center', opacity: pressed ? 0.65 : 1 })}><AppText variant="label" tone="primary">{label}</AppText></Pressable></Link></View>;
}

export function AuthFeedbackMessage({ message, tone = 'error' }: { message: string; tone?: 'error' | 'success' | 'muted' }) {
  const palette = useAppPalette();
  return <View accessibilityRole={tone === 'error' ? 'alert' : undefined} style={{ padding: space.md, borderRadius: designTokens.radius.md, backgroundColor: tone === 'error' ? palette.rewardSoft : palette.mintSoft }}><AppText tone={tone}>{message}</AppText></View>;
}
