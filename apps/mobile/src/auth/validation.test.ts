import { describe, expect, it } from 'vitest';
import { validateAuthFields, validateAuthInput } from './validation';

describe('email authentication form', () => {
  it('rejects invalid login input before any network request', () => {
    expect(validateAuthInput('fg', 'password123')).toMatch(/email/);
    expect(validateAuthInput('learner@example.com', 'short')).toMatch(/password/);
  });
  it('requires a display name only for registration', () => {
    expect(validateAuthInput('learner@example.com', 'password123')).toBeNull();
    expect(validateAuthInput('learner@example.com', 'password123', '  ')).toMatch(/display name/);
    expect(validateAuthInput('learner@example.com', 'password123', 'Learner')).toBeNull();
  });
  it('shows registration errors beside the affected fields', () => {
    expect(validateAuthFields({ name: ' ', email: 'bad', password: 'short', confirm: 'different' })).toEqual({
      name: 'Enter a display name.', email: 'Enter a valid email address.', password: 'Use at least 8 characters.', confirm: 'Passwords do not match.',
    });
    expect(validateAuthFields({ name: 'Learner', email: 'learner@example.com', password: 'password123', confirm: 'password123' })).toEqual({});
  });
});
