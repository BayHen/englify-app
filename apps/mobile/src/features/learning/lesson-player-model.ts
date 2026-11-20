import type { LessonBlock } from './api';

export function initialBlockIndex(blocks: LessonBlock[], resumeBlockId?: string | null): number {
  const found = resumeBlockId ? blocks.findIndex((block) => block.id === resumeBlockId) : -1;
  return found >= 0 ? found : 0;
}
