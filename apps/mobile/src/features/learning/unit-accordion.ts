export function toggleExpandedUnit(currentUnitId: string | null, pressedUnitId: string): string | null {
  return currentUnitId === pressedUnitId ? null : pressedUnitId;
}

