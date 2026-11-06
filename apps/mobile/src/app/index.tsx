import { Redirect } from 'expo-router';
import { useAuth } from '@/auth/provider';
export default function Index() {
  const { session, profile } = useAuth();
  return <Redirect href={!session ? '/login' : profile?.preferences?.onboarding_completed_at ? '/home' : '/onboarding'} />;
}
