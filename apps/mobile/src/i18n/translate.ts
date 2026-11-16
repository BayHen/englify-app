import { en } from './en';
import { vi } from './vi';
import type { InterfaceLanguage } from './types';
import type { TranslationKey } from './keys';
import { uiLiteralVi } from './ui-literal-vi';

const resources = { en, vi } as const;

export function translate(language: InterfaceLanguage, key: TranslationKey): string {
  return resources[language][key] ?? resources.en[key] ?? key;
}

const englishLiteralKeys = new Map<string, TranslationKey>(
  Object.entries(en).map(([key, value]) => [value, key as TranslationKey]),
);

export function translateLiteral(language: InterfaceLanguage, value: string): string {
  if (language === 'en' || !value.trim()) return value;
  const resourceKey = englishLiteralKeys.get(value);
  if (resourceKey) return translate(language, resourceKey);
  const exact = uiLiteralVi[value];
  if (exact) return exact;

  const patterns: [RegExp, (...parts: string[]) => string][] = [
    [/^Hi, (.+)!$/, (name) => `Xin chào, ${name}!`],
    [/^Saved \((\d+)\)$/, (count) => `Đã lưu (${count})`],
    [/^Pronounce (.+)$/, (term) => `Phát âm ${term}`],
    [/^Listen to (.+)$/, (speaker) => `Nghe giọng ${speaker}`],
    [/^Resend in (\d+)s$/, (seconds) => `Gửi lại sau ${seconds} giây`],
    [/^(\d+) minutes a day$/, (minutes) => `${minutes} phút mỗi ngày`],
    [/^Page (\d+) of (\d+)$/, (page, total) => `Trang ${page} / ${total}`],
    [/^Recording… (\d+) s$/, (seconds) => `Đang ghi âm… ${seconds} giây`],
    [/^Open (.+)$/, (label) => `Mở ${translateLiteral(language, label)}`],
  ];
  for (const [pattern, format] of patterns) {
    const match = value.match(pattern);
    if (match) return format(...match.slice(1));
  }
  return value;
}
