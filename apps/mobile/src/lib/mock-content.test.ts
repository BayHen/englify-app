import { describe, expect, it } from 'vitest';
import { getMockContent } from './mock-content';

describe('route content', () => {
  it('provides meaningful cards for each learning route', async () => {
    for (const route of ['home', 'journey', 'explore', 'coach', 'profile'] as const) {
      const content = await getMockContent(route);
      expect(content.title.length).toBeGreaterThan(0);
      expect(content.items.length).toBeGreaterThan(0);
    }
  });
});
