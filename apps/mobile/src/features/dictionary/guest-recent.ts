import { create } from 'zustand';

export const useGuestRecent = create<{
  words: string[];
  add: (query: string) => void;
  remove: (query: string) => void;
  clear: () => void;
}>((set) => ({
  words: [],
  add: (query) => {
    const word = query.trim().toLocaleLowerCase();
    if (word) set(({ words }) => ({ words: [word, ...words.filter((item) => item !== word)].slice(0, 20) }));
  },
  remove: (query) => set(({ words }) => ({ words: words.filter((word) => word !== query) })),
  clear: () => set({ words: [] }),
}));
