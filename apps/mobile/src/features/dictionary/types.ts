export type DictionaryWord = {
  id: string;
  term: string;
  definition: string;
  translation: string | null;
  ipa: string | null;
  part_of_speech: string | null;
  example: string | null;
  audio_url: string | null;
  source_name: string;
  license_id: string;
};

export type SavedWord = {
  id: string;
  word: DictionaryWord;
  created_at: string;
  next_review_at: string | null;
};

export function filterCachedWords(words: DictionaryWord[], query: string): DictionaryWord[] {
  const normalized = query.trim().toLocaleLowerCase();
  if (!normalized) return words.slice(0, 50);
  return words.filter((word) =>
    word.term.toLocaleLowerCase().startsWith(normalized)
    || (word.translation ?? '').toLocaleLowerCase().includes(normalized)
  ).slice(0, 50);
}
