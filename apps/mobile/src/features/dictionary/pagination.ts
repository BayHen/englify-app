export const DICTIONARY_PAGE_SIZE = 5;

export function paginateDictionary<T>(items: readonly T[], requestedPage: number) {
  const totalPages = Math.max(1, Math.ceil(items.length / DICTIONARY_PAGE_SIZE));
  const page = Math.min(totalPages, Math.max(1, Math.trunc(requestedPage) || 1));
  const start = (page - 1) * DICTIONARY_PAGE_SIZE;
  return { items: items.slice(start, start + DICTIONARY_PAGE_SIZE), page, totalPages, totalItems: items.length };
}
