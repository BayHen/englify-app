import { describe, expect, it } from 'vitest';
import { validateAuthInput } from './validation';

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
});
