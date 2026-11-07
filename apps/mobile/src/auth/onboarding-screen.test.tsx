import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it, vi } from 'vitest';
import Onboarding from '../app/onboarding';

vi.mock('expo-router', () => ({ router: { replace: vi.fn() } }));
vi.mock('@/auth/provider', () => ({ useAuth: () => ({ saveOnboarding: vi.fn() }) }));
vi.mock('@/components/page', async () => {
  const { createElement } = await import('react');
  const { View } = await import('react-native');
  return { Page: ({ children }: { children: React.ReactNode }) => createElement(View, null, children) };
});
vi.mock('@/ui', async () => {
  const { createElement } = await import('react');
  const { View, Text } = await import('react-native');
  return {
    AppText: ({ children }: { children: React.ReactNode }) => createElement(Text, null, children),
    AppCard: ({ children }: { children: React.ReactNode }) => createElement(View, null, children),
    AppButton: ({ label }: { label: string }) => createElement(View, null, createElement(Text, null, label)),
  };
});

describe('onboarding screen', () => {
  it('renders its initial state without a text node directly in a View', () => {
    const html = renderToStaticMarkup(<Onboarding />);
    expect(html).toContain('What brings you here?');
    expect(html).toContain('Save my learning plan');
  });
});
