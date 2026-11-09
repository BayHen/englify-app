import { File } from 'expo-file-system';
import { randomUUID } from 'expo-crypto';
import * as ImagePicker from 'expo-image-picker';
import { manipulateAsync, SaveFormat } from 'expo-image-manipulator';
import { Platform } from 'react-native';
import { getSupabase } from '@/auth/supabase';

const BUCKET = 'avatars';
const MAX_BYTES = 2 * 1024 * 1024;

export async function chooseAvatar(): Promise<string | null> {
  if (Platform.OS !== 'web') {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) throw new Error('Photo library permission is required to choose an avatar.');
  }
  const choice = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], allowsEditing: true, aspect: [1, 1], quality: 0.85 });
  if (choice.canceled || !choice.assets[0]) return null;
  const asset = choice.assets[0];
  if (asset.mimeType && !asset.mimeType.startsWith('image/')) throw new Error('Choose an image file.');
  const side = Math.min(asset.width, asset.height);
  if (!side) throw new Error('Could not read the image dimensions.');
  const square = await manipulateAsync(asset.uri, [
    { crop: { originX: Math.floor((asset.width - side) / 2), originY: Math.floor((asset.height - side) / 2), width: side, height: side } },
    { resize: { width: 512, height: 512 } },
  ], { compress: 0.72, format: SaveFormat.JPEG });
  if (new File(square.uri).size > MAX_BYTES) throw new Error('The processed image is too large. Choose another photo.');
  return square.uri;
}

export async function avatarSignedUrl(path: string | null): Promise<string | null> {
  if (!path) return null;
  const { data, error } = await getSupabase().storage.from(BUCKET).createSignedUrl(path, 3600);
  if (error) throw error;
  return data.signedUrl;
}

export async function uploadAvatar(uri: string, userId: string): Promise<string> {
  const file = new File(uri);
  if (file.size > MAX_BYTES) throw new Error('Avatar must be smaller than 2 MB.');
  const path = `${userId}/${randomUUID()}.jpg`;
  const { error } = await getSupabase().storage.from(BUCKET).upload(path, await file.arrayBuffer(), { contentType: 'image/jpeg', upsert: false });
  if (error) throw error;
  return path;
}

export async function removeAvatarObject(path: string): Promise<void> {
  const { error } = await getSupabase().storage.from(BUCKET).remove([path]);
  if (error) throw error;
}
