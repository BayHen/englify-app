export type PracticeHistory = { completed: number; recordings: Record<string, string>; completedTakes: Record<string, string> };

export function completeTake(history: PracticeHistory, promptId: string, uri: string): PracticeHistory {
  if (history.completedTakes[promptId] === uri) return history;
  return { ...history, completed: history.completed + 1, completedTakes: { ...history.completedTakes, [promptId]: uri } };
}
