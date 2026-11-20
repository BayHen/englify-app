import { describe, expect, it } from 'vitest';
import { shouldNavigateToTab } from './tab-navigation';

describe('shouldNavigateToTab',()=>{
  it('does not navigate when the active root tab is pressed again',()=>{
    expect(shouldNavigateToTab('/practice','/practice')).toBe(false);
    expect(shouldNavigateToTab('/home','/home')).toBe(false);
  });

  it('navigates when another tab is pressed',()=>{
    expect(shouldNavigateToTab('/practice','/journey')).toBe(true);
  });

  it('returns from a child screen to its tab root',()=>{
    expect(shouldNavigateToTab('/writing','/practice')).toBe(true);
    expect(shouldNavigateToTab('/lesson/example','/journey')).toBe(true);
  });
});
