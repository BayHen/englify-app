export function validateAuthInput(email: string, password: string, name?: string): string | null {
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return 'Enter a valid email address.';
  if (password.length < 8) return 'Use a password with at least 8 characters.';
  if (name !== undefined && !name.trim()) return 'Enter a display name.';
  return null;
}

export function validateAuthFields(input: { email: string; password: string; name?: string; confirm?: string }) {
  const errors: { name?: string; email?: string; password?: string; confirm?: string } = {};
  if (input.name !== undefined && !input.name.trim()) errors.name = 'Enter a display name.';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email.trim())) errors.email = 'Enter a valid email address.';
  if (input.password.length < 8) errors.password = 'Use at least 8 characters.';
  if (input.confirm !== undefined && input.password !== input.confirm) errors.confirm = 'Passwords do not match.';
  return errors;
}
