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
  display: { fontSize: designTokens.typography.size.display, lineHeight: designTokens.typography.lineHeight.display, fontWeight: '800' },
  title: { fontSize: designTokens.typography.size.title, lineHeight: designTokens.typography.lineHeight.title, fontWeight: '800' },
  heading: { fontSize: designTokens.typography.size.xl, lineHeight: designTokens.typography.lineHeight.xl, fontWeight: '700' },
  body: { fontSize: designTokens.typography.size.md, lineHeight: designTokens.typography.lineHeight.md },
  label: { fontSize: designTokens.typography.size.sm, lineHeight: designTokens.typography.lineHeight.sm, fontWeight: '700' },
  caption: { fontSize: designTokens.typography.size.xs, lineHeight: designTokens.typography.lineHeight.xs },
};

export function AppText({ children, variant = 'body', tone = 'default', weight, style, ...props }: AppTextProps) {
  const palette = useAppPalette();
  const color = tone === 'default' ? palette.text : tone === 'muted' ? palette.muted : palette[tone];
  return <Text allowFontScaling {...props} style={[typography[variant], { color }, weight && { fontWeight: designTokens.typography.weight[weight] }, style]}>{children}</Text>;
}
