export function validateAuthInput(email: string, password: string, name?: string): string | null {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return 'Enter a valid email address.';
  if (password.length < 8) return 'Use a password with at least 8 characters.';
  if (name !== undefined && !name.trim()) return 'Enter a display name.';
  return null;
}
