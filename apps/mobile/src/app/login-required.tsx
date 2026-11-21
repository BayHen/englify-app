import { router } from 'expo-router';
import { usePendingDestination } from '@/auth/access';
import { Page } from '@/components/page';
import { AppButton, AppText } from '@/ui';

export default function LoginRequired() {
  const destination = usePendingDestination((state) => state.destination);
  return <Page title="Sign in to continue" compact>
    <AppText tone="muted">
      {destination === '/journey' ? 'Create an account to save your Journey and keep your learning progress.'
        : destination === '/practice' ? 'Sign in to practise and track your results.'
        : 'This feature uses your Englify account. You can keep using Dictionary and Translate as a guest.'}
    </AppText>
    <AppButton label="Sign in" onPress={() => router.push('/login')} />
    <AppButton label="Create account" variant="secondary" onPress={() => router.push('/register')} />
    <AppButton label="Cancel" variant="ghost" onPress={() => {
      usePendingDestination.getState().set(null);
      if (router.canGoBack()) router.back();
      else router.replace('/home');
    }} />
  </Page>;
}
