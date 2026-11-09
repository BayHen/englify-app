import { useEffect, useState } from 'react';
import { Image, View } from 'react-native';
import { AppText } from '@/ui';
import { useAppPalette } from '@/constants/app-theme';
import { avatarSignedUrl } from './avatar';

export function ProfileAvatar({ name, path, preview, size = 60 }: { name: string; path?: string | null; preview?: string | null; size?: number }) {
  const palette = useAppPalette();
  const [signed, setSigned] = useState<{ path: string; url: string } | null>(null);
  useEffect(() => {
    let active = true;
    if (path && !preview) void avatarSignedUrl(path).then((value) => { if (active && value) setSigned({ path, url: value }); }).catch(() => undefined);
    return () => { active = false; };
  }, [path, preview]);
  const url = signed && signed.path === path ? signed.url : null;
  return <View accessibilityLabel={`${name}'s avatar`} style={{ width: size, height: size, borderRadius: size / 2, overflow: 'hidden', alignItems: 'center', justifyContent: 'center', backgroundColor: palette.reward }}>
    {preview || url ? <Image source={{ uri: preview || url || '' }} style={{ width: size, height: size }} accessibilityLabel={`${name}'s photo`} /> : <AppText variant="heading" style={{ color: palette.rewardOn }}>{name.slice(0, 1).toUpperCase()}</AppText>}
  </View>;
}
