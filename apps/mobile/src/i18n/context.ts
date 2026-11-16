import { createContext, useContext } from 'react';
import type { InterfaceLanguage } from './types';
import type { TranslationKey } from './keys';
import { translate, translateLiteral } from './translate';

export type I18nValue = {
  language: InterfaceLanguage;
  pendingSync: boolean;
  ready: boolean;
  t: (key: TranslationKey) => string;
  l: (value: string) => string;
  setLanguage: (language: InterfaceLanguage) => void;
  reconcileRemoteLanguage: (language: InterfaceLanguage) => InterfaceLanguage | null;
  markLanguageSynced: (language: InterfaceLanguage) => void;
};

const defaultValue: I18nValue = {
  language: 'en',
  pendingSync: false,
  ready: true,
  t: (key) => translate('en', key),
  l: (value) => translateLiteral('en', value),
  setLanguage: () => undefined,
  reconcileRemoteLanguage: () => null,
  markLanguageSynced: () => undefined,
};

export const I18nContext = createContext<I18nValue>(defaultValue);

export function useI18n(): I18nValue {
  return useContext(I18nContext);
}
