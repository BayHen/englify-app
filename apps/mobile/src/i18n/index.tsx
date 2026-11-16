import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { readStoredLanguage, writeStoredLanguage } from './storage';
import type { InterfaceLanguage } from './types';
import { translate, translateLiteral } from './translate';
import { I18nContext, type I18nValue } from './context';

export function I18nProvider({ children }: { children: ReactNode }) {
  const [language, setLanguageState] = useState<InterfaceLanguage>('en');
  const [pendingSync, setPendingSync] = useState(false);
  const [ready, setReady] = useState(false);
  const pendingRef = useRef(false);
  const languageRef = useRef<InterfaceLanguage>('en');
  const persist = useCallback((next: InterfaceLanguage, pending: boolean) => {
    setLanguageState(next); setPendingSync(pending); pendingRef.current = pending; languageRef.current = next;
    void writeStoredLanguage({ language: next, pendingSync: pending }).catch(() => undefined);
  }, []);
  useEffect(() => {
    let active = true;
    void readStoredLanguage().then((stored) => {
      if (!active) return;
      if (stored) {
        setLanguageState(stored.language); setPendingSync(stored.pendingSync); pendingRef.current = stored.pendingSync; languageRef.current = stored.language;
      }
    }).finally(() => { if (active) setReady(true); });
    return () => { active = false; };
  }, []);
  const setLanguage = useCallback((next: InterfaceLanguage) => persist(next, true), [persist]);
  const reconcileRemoteLanguage = useCallback((remote: InterfaceLanguage): InterfaceLanguage | null => {
    if (!pendingRef.current) { persist(remote, false); return null; }
    if (languageRef.current === remote) { persist(remote, false); return null; }
    return languageRef.current;
  }, [persist]);
  const markLanguageSynced = useCallback((next: InterfaceLanguage) => persist(next, false), [persist]);
  const value = useMemo<I18nValue>(() => ({
    language, pendingSync, ready,
    t: (key) => translate(language, key),
    l: (value) => translateLiteral(language, value),
    setLanguage,
    reconcileRemoteLanguage,
    markLanguageSynced,
  }), [language, pendingSync, ready, setLanguage, reconcileRemoteLanguage, markLanguageSynced]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export type { InterfaceLanguage } from './types';
export type { TranslationKey } from './keys';
export { translate, translateLiteral } from './translate';
export { useI18n } from './context';
