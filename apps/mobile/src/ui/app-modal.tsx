import type { ReactNode } from 'react';
import { Modal, Pressable, ScrollView, View } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';
import { AppButton } from './app-button';
import { AppText } from './app-text';
import { useReducedMotion } from './use-reduced-motion';

export type AppModalProps = {
  visible: boolean;
  title: string;
  onClose: () => void;
  children: ReactNode;
};

export function AppModal({ visible, title, onClose, children }: AppModalProps) {
  const palette = useAppPalette();
  const reduced = useReducedMotion();
  return <Modal visible={visible} transparent animationType={reduced ? 'none' : 'fade'} onRequestClose={onClose}>
    <View style={{ flex: 1, justifyContent: 'center', padding: designTokens.spacing.lg }}>
      <Pressable accessibilityRole="button" accessibilityLabel="Close dialog" onPress={onClose} style={{ position: 'absolute', top: 0, right: 0, bottom: 0, left: 0, backgroundColor: palette.overlay }} />
      <View accessibilityViewIsModal style={{ width: '100%', maxWidth: 520, maxHeight: '85%', alignSelf: 'center', borderRadius: designTokens.radius.xl, backgroundColor: palette.elevated, padding: designTokens.spacing.xl, gap: designTokens.spacing.lg }}>
        <AppText variant="heading" accessibilityRole="header">{title}</AppText>
        <ScrollView contentContainerStyle={{ gap: designTokens.spacing.md }}>{children}</ScrollView>
        <AppButton label="Close" onPress={onClose} variant="secondary" />
      </View>
    </View>
  </Modal>;
}
