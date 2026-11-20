import { router, type Href } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';
import { Page } from '@/components/page';
import { useAuth } from '@/auth/provider';
import { useAppPalette } from '@/constants/app-theme';
import { AppButton, AppText } from '@/ui';
import { SettingsRow } from '@/features/profile/settings-row';
import { LanguageSelector } from '@/components/language-selector';
import { translate, useI18n } from '@/i18n';
import { preferenceErrorKey } from '@/i18n/errors';

export default function AccountSettings() {
  const { session, signOut, savePreferences } = useAuth();
  const { language, setLanguage, t } = useI18n();
  const palette = useAppPalette();
  const [languageBusy, setLanguageBusy] = useState(false);
  const [languageError, setLanguageError] = useState('');
  async function changeLanguage(next: 'en' | 'vi') {
    if (languageBusy || next === language) return;
    setLanguage(next); setLanguageBusy(true); setLanguageError('');
    try { await savePreferences({ interface_language: next }); }
    catch (cause) { setLanguageError(translate(next, preferenceErrorKey(cause, 'preferences.error.save'))); }
    finally { setLanguageBusy(false); }
  }
  return <Page eyebrow={t('settings.eyebrow')} title={t('settings.title')} description={t('settings.description')} compact>
    <AppText variant="heading" accessibilityRole="header">{t('settings.editProfile')}</AppText>
    <View style={{ backgroundColor: palette.surface, borderRadius: 20, paddingHorizontal: 16 }}>
      <SettingsRow label={t('settings.editProfile')} detail={t('settings.editProfileDetail')} onPress={() => router.push('/edit-profile' as Href)} />
      <SettingsRow label={t('settings.changeAvatar')} detail={t('settings.changeAvatarDetail')} onPress={() => router.push('/change-avatar' as Href)} />
      <SettingsRow label={t('settings.learningPreferences')} detail={t('settings.learningPreferencesDetail')} onPress={() => router.push('/learning-preferences' as Href)} />
    </View>
    <View style={{ gap: 8 }}><AppText variant="heading">{t('settings.language')}</AppText><AppText tone="muted">{t('settings.languageDetail')}</AppText><LanguageSelector value={language} disabled={languageBusy} onChange={(next) => { void changeLanguage(next); }} />{languageError ? <AppText tone="error" accessibilityRole="alert">{languageError}</AppText> : null}</View>
    <View style={{ gap: 4 }}><AppText variant="label">{t('settings.email')}</AppText><AppText tone="muted">{session?.user.email ?? t('settings.emailUnavailable')}</AppText><AppText variant="caption" tone="muted">{t('settings.emailDetail')}</AppText></View>
    <View style={{ backgroundColor: palette.surface, borderRadius: 20, paddingHorizontal: 16 }}>
      <SettingsRow label={t('settings.changePassword')} detail={t('settings.changePasswordDetail')} onPress={() => router.push('/change-password' as Href)} />
    </View>
    <AppButton label={t('settings.signOut')} variant="secondary" onPress={() => { void signOut().finally(() => router.replace('/login')); }} />
  </Page>;
}
