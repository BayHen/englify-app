import { describe, expect, it } from 'vitest';
import { shouldNavigateToTab, visibleQuestTabs } from './tab-navigation';

it('gives guests four public destinations in order', () => {
  expect(visibleQuestTabs(false).map(({ href }) => href)).toEqual(['/home', '/translation', '/dictionary', '/profile']);
});

it('retains the five member destinations in order', () => {
  expect(visibleQuestTabs(true).map(({ href }) => href)).toEqual(['/home', '/journey', '/explore', '/practice', '/profile']);
});

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
