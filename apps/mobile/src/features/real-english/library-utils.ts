export type SearchableLesson = {
  title: string;
  description: string;
  content_type: string;
  real_english_phrases: { english_text: string; vietnamese_translation: string; usage_context: string }[];
  real_english_dialogues: {
    title: string;
    real_english_dialogue_lines: { speaker: string; english_text: string; vietnamese_translation: string }[];
  }[];
};

export function normalizeSearchText(value: string) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replaceAll('đ', 'd').replaceAll('Đ', 'D')
    .toLocaleLowerCase('vi').trim();
}

export function lessonMatchesQuery(lesson: SearchableLesson, query: string) {
  const term = normalizeSearchText(query);
  if (!term) return true;
  const text = normalizeSearchText([
    lesson.title, lesson.description, lesson.content_type,
    ...lesson.real_english_phrases.flatMap((phrase) => [phrase.english_text, phrase.vietnamese_translation, phrase.usage_context]),
    ...lesson.real_english_dialogues.flatMap((dialogue) => [dialogue.title,
      ...dialogue.real_english_dialogue_lines.flatMap((line) => [line.speaker, line.english_text, line.vietnamese_translation])]),
  ].join(' '));
  return text.includes(term);
}

export function paginate<T>(items: T[], requestedPage: number, pageSize = 5) {
  const pageCount = Math.max(1, Math.ceil(items.length / pageSize));
  const page = Math.min(Math.max(1, requestedPage), pageCount);
  return { page, pageCount, items: items.slice((page - 1) * pageSize, page * pageSize) };
}
