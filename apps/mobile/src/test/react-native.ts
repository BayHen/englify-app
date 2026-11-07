import { Children, createElement, type ReactNode } from 'react';

type StubProps = {
  children?: ReactNode;
  accessibilityLabel?: string;
  accessibilityRole?: string;
  accessibilityValue?: { now?: number; min?: number; max?: number };
  disabled?: boolean;
  value?: string;
};

function domProps(props: StubProps) {
  return {
    'aria-label': props.accessibilityLabel,
    'aria-valuenow': props.accessibilityValue?.now,
    'aria-valuemin': props.accessibilityValue?.min,
    'aria-valuemax': props.accessibilityValue?.max,
    role: props.accessibilityRole,
    disabled: props.disabled,
  };
}

export function View(props: StubProps) {
  if (Children.toArray(props.children).some((child) => typeof child === 'string' || typeof child === 'number')) {
    throw new Error('A text node cannot be a child of a View');
  }
  return createElement('div', domProps(props), props.children);
}
export function Text(props: StubProps) { return createElement('span', domProps(props), props.children); }
export function Pressable(props: StubProps) { return createElement('button', domProps(props), props.children); }
export function TextInput(props: StubProps) { return createElement('input', { ...domProps(props), value: props.value, readOnly: true }); }
export const Platform = { OS: 'web' };
export const useColorScheme = () => 'light';
export const StyleSheet = { create: <T>(styles: T) => styles };
export const AccessibilityInfo = { isReduceMotionEnabled: async () => true, addEventListener: () => ({ remove: () => {} }) };
export const Animated = { Value: class { setValue() {} }, View, loop: () => ({ start() {}, stop() {} }), sequence: () => ({}), timing: () => ({}) };
