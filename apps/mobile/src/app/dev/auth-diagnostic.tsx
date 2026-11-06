import { useState } from 'react';
import { Redirect } from 'expo-router';
import { Page, NavLink } from '@/components/page';
import { AppButton, AppCard, AppText, LoadingSkeleton } from '@/ui';
import { runAuthDiagnostic, type Check } from '@/auth/diagnostic';

export default function AuthDiagnostic() {
  const [checks, setChecks] = useState<Check[]>([]);
  const [busy, setBusy] = useState(false);
  if (!__DEV__) return <Redirect href="/login" />;
  async function run() {
    setBusy(true);
    try { setChecks(await runAuthDiagnostic()); }
    finally { setBusy(false); }
  }
  return <Page eyebrow="DEVELOPMENT ONLY" title="Supabase diagnostic" description="Checks public configuration and reachable services. No credentials or tokens are displayed.">
    <AppButton label="Run connection checks" onPress={() => { void run(); }} loading={busy} />
    {busy && <LoadingSkeleton />}
    {checks.map((item) => <AppCard key={item.label} style={{ gap: 5 }}><AppText variant="label" tone={item.status === 'failed' ? 'error' : item.status === 'passed' ? 'success' : 'muted'}>{item.label}: {item.status}</AppText><AppText tone="muted">{item.detail}</AppText></AppCard>)}
    <NavLink href="/login" label="Back to sign in" />
  </Page>;
}
