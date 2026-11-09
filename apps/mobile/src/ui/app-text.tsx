import type { ReactNode } from 'react';
import { Text, type TextProps, type TextStyle } from 'react-native';
import { designTokens } from '@englify/shared';
import { useAppPalette } from '@/constants/app-theme';

export type TextVariant = 'display' | 'title' | 'heading' | 'body' | 'label' | 'caption';
export type TextTone = 'default' | 'muted' | 'primary' | 'reward' | 'success' | 'error';

export type AppTextProps = TextProps & {
  children: ReactNode;
  variant?: TextVariant;
  tone?: TextTone;
  weight?: 'regular' | 'medium' | 'semibold' | 'bold' | 'heavy';
};

const typography: Record<TextVariant, TextStyle> = {
  display: { fontSize: designTokens.typography.size.display, lineHeight: designTokens.typography.lineHeight.display, fontFamily: designTokens.typography.family.rounded },
  title: { fontSize: designTokens.typography.size.title, lineHeight: designTokens.typography.lineHeight.title, fontFamily: designTokens.typography.family.rounded },
  heading: { fontSize: designTokens.typography.size.xl, lineHeight: designTokens.typography.lineHeight.xl, fontFamily: designTokens.typography.family.bold },
  body: { fontSize: designTokens.typography.size.md, lineHeight: designTokens.typography.lineHeight.md, fontFamily: designTokens.typography.family.regular },
  label: { fontSize: designTokens.typography.size.sm, lineHeight: designTokens.typography.lineHeight.sm, fontFamily: designTokens.typography.family.bold },
  caption: { fontSize: designTokens.typography.size.xs, lineHeight: designTokens.typography.lineHeight.xs, fontFamily: designTokens.typography.family.semibold },
};

export function AppText({ children, variant = 'body', tone = 'default', weight, style, ...props }: AppTextProps) {
  const palette = useAppPalette();
  const color = tone === 'default' ? palette.text : tone === 'muted' ? palette.muted : palette[tone];
  const fontFamily = weight === 'regular' ? designTokens.typography.family.regular : weight === 'medium' || weight === 'semibold' ? designTokens.typography.family.semibold : weight === 'bold' ? designTokens.typography.family.bold : weight === 'heavy' ? designTokens.typography.family.heavy : undefined;
  return <Text allowFontScaling {...props} style={[typography[variant], { color }, fontFamily && { fontFamily }, style]}>{children}</Text>;
}
