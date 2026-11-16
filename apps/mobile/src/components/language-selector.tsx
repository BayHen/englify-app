import { Pressable, View } from 'react-native';
import { useAppPalette } from '@/constants/app-theme';
import { useI18n, type InterfaceLanguage } from '@/i18n';
import { AppText } from '@/ui';

export function LanguageSelector({ value, onChange, disabled = false }: { value: InterfaceLanguage; onChange: (value: InterfaceLanguage) => void; disabled?: boolean }) {
  const palette = useAppPalette();
  const { t } = useI18n();
  const options = [['en', t('preferences.language.english')], ['vi', t('preferences.language.vietnamese')]] as const;
  return <View style={{ gap: 9 }}>
    <AppText variant="label">{t('preferences.interfaceLanguage')}</AppText>
    <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
      {options.map(([id, label]) => <Pressable key={id} accessibilityRole="button" accessibilityLabel={label} accessibilityState={{ selected: value === id, disabled }} disabled={disabled} onPress={() => onChange(id)} style={({ pressed }) => ({ minHeight: 44, justifyContent: 'center', borderWidth: 1, borderColor: value === id ? palette.primary : palette.border, borderRadius: 16, paddingHorizontal: 13, paddingVertical: 10, backgroundColor: value === id ? palette.primarySoft : palette.surface, opacity: disabled ? 0.5 : pressed ? 0.7 : 1 })}>
        <AppText variant="label" tone={value === id ? 'primary' : 'default'}>{label}</AppText>
      </Pressable>)}
    </View>
  </View>;
}
