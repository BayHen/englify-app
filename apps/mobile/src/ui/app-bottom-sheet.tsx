import type { ReactNode } from 'react';
import { KeyboardAvoidingView, Modal, Platform, Pressable, ScrollView, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppText } from './app-text';
import { useReducedMotion } from './use-reduced-motion';

export type AppBottomSheetProps = {
  visible: boolean;
  title: string;
  onClose: () => void;
  children: ReactNode;
  scrollable?: boolean;
};

export function AppBottomSheet({ visible, title, onClose, children, scrollable = true }: AppBottomSheetProps) {
  const palette = useAppPalette();
  const reduced = useReducedMotion();
  return <Modal visible={visible} transparent animationType={reduced ? 'none' : 'slide'} onRequestClose={onClose}>
    <SafeAreaProvider>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1, justifyContent: 'flex-end' }}>
        <Pressable accessibilityRole="button" accessibilityLabel="Close sheet" onPress={onClose} style={{ position: 'absolute', top: 0, right: 0, bottom: 0, left: 0, backgroundColor: palette.overlay }} />
        <SafeAreaView edges={['bottom']} style={{ backgroundColor: palette.elevated, borderTopLeftRadius: designTokens.radius.xl, borderTopRightRadius: designTokens.radius.xl, maxHeight: '85%' }}>
          <View accessibilityViewIsModal style={{ padding: designTokens.spacing.xl, gap: designTokens.spacing.lg }}>
            <View style={{ width: 42, height: 5, borderRadius: designTokens.radius.pill, backgroundColor: palette.border, alignSelf: 'center' }} />
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}>
              <AppText variant="heading" accessibilityRole="header">{title}</AppText>
              <Pressable accessibilityRole="button" accessibilityLabel="Close sheet" onPress={onClose} hitSlop={12}><AppText tone="primary" variant="label">Close</AppText></Pressable>
            </View>
            {scrollable ? <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={{ gap: designTokens.spacing.md }}>{children}</ScrollView> : <View style={{ minHeight: 0, flexShrink: 1 }}>{children}</View>}
          </View>
        </SafeAreaView>
      </KeyboardAvoidingView>
    </SafeAreaProvider>
  </Modal>;
}
