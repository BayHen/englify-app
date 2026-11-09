import { router, type Href } from 'expo-router';
import { View } from 'react-native';
import { Page } from '@/components/page';
import { useAuth } from '@/auth/provider';
import { useAppPalette } from '@/constants/app-theme';
import { AppButton, AppText } from '@/ui';
import { SettingsRow } from '@/features/profile/settings-row';

export default function AccountSettings() {
  const { session, signOut } = useAuth();
  const palette = useAppPalette();
  return <Page eyebrow="ACCOUNT" title="Settings" description="Keep your account and learning choices up to date." compact>
    <View style={{ backgroundColor: palette.surface, borderRadius: 20, paddingHorizontal: 16 }}>
      <SettingsRow label="Edit profile" detail="Name, username and bio" onPress={() => router.push('/edit-profile' as Href)} />
      <SettingsRow label="Change avatar" detail="Choose or remove your photo" onPress={() => router.push('/change-avatar' as Href)} />
      <SettingsRow label="Learning preferences" detail="Goal, level, time and language" onPress={() => router.push('/learning-preferences' as Href)} />
      <SettingsRow label="Change password" detail="Keep your account secure" onPress={() => router.push('/change-password' as Href)} />
    </View>
    <View style={{ gap: 4 }}><AppText variant="label">Email address</AppText><AppText tone="muted">{session?.user.email ?? 'Unavailable'}</AppText><AppText variant="caption" tone="muted">Email changes are managed through Supabase account recovery.</AppText></View>
    <AppButton label="Sign out" variant="secondary" onPress={() => { void signOut().finally(() => router.replace('/login')); }} />
  </Page>;
}
