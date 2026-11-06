import { NavLink, Page } from '@/components/page';
import { AppText, LoadingSkeleton } from '@/ui';
import { useAuth } from '@/auth/provider';
export default function AuthCallback() {
  const { loading, callbackError } = useAuth();
  return <Page eyebrow="VERIFYING LINK" title="Email confirmation" description="Completing your email link securely.">
    {loading ? <LoadingSkeleton /> : <AppText tone={callbackError ? 'error' : 'muted'}>{callbackError ?? 'You can return to sign in if this page does not advance.'}</AppText>}
    <NavLink href="/login" label="Back to sign in" />
  </Page>;
}
