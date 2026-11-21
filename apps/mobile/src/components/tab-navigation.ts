const memberTabs = [
  { label: 'nav.home', href: '/home', icon: { ios: 'house.fill', android: 'home', web: 'home' } },
  { label: 'nav.journey', href: '/journey', icon: { ios: 'map.fill', android: 'map', web: 'map' } },
  { label: 'nav.explore', href: '/explore', icon: { ios: 'safari.fill', android: 'explore', web: 'explore' } },
  { label: 'nav.practice', href: '/practice', icon: { ios: 'pencil.circle.fill', android: 'edit', web: 'edit' } },
  { label: 'nav.profile', href: '/profile', icon: { ios: 'person.crop.circle.fill', android: 'account_circle', web: 'account_circle' } },
] as const;

const guestTabs = [
  memberTabs[0],
  { label: 'nav.translate', href: '/translation', icon: { ios: 'character.bubble', android: 'translate', web: 'translate' } },
  { label: 'nav.voca', href: '/dictionary', icon: { ios: 'book', android: 'menu_book', web: 'menu_book' } },
  memberTabs[4],
] as const;

export function visibleQuestTabs(authenticated: boolean) {
  return authenticated ? memberTabs : guestTabs;
}

export function shouldNavigateToTab(currentPath: string, targetPath: string): boolean {
  return currentPath !== targetPath;
}
