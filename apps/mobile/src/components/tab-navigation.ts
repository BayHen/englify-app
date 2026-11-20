export function shouldNavigateToTab(currentPath: string, targetPath: string): boolean {
  return currentPath !== targetPath;
}
