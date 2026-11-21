import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import * as Linking from 'expo-linking';
import { useQueryClient } from '@tanstack/react-query';
import type { Session } from '@supabase/supabase-js';
import { ApiError } from '@/lib/api';
import { useAppStore } from '@/state/app-store';
import type { OnboardingInput, Profile, ProfileChanges, PreferenceChanges } from './api';
import { completeOnboarding, readProfile, updateOwnPreferences, updateOwnProfile } from './profile-repository';
import { parseAuthCallback } from './callback';
import { authConfigured, getSupabase, removePersistedSession } from './supabase';
import { cacheProfile, getCachedProfile } from '@/features/offline/storage';
import { useI18n } from '@/i18n';
import { usePendingDestination } from './access';
import { clearAccountTranslations } from '@/features/translation/api';
import { useGuestRecent } from '@/features/dictionary/guest-recent';

export type AuthPhase = 'initializing' | 'guest' | 'authenticating' | 'authenticated' | 'signingOut';

type AuthContextValue = {
  phase: AuthPhase;
  configured: boolean;
  loading: boolean;
  session: Session | null;
  profile: Profile | null;
  profileError: string | null;
  callbackError: string | null;
  callbackTarget: '/login' | '/reset-password' | '/home' | '/onboarding' | null;
  clearCallbackTarget: () => void;
  signIn: (email: string, password: string) => Promise<Profile | null>;
  signUp: (email: string, password: string, name: string) => Promise<boolean>;
  signOut: () => Promise<void>;
  requestPasswordReset: (email: string) => Promise<void>;
  updatePassword: (password: string) => Promise<void>;
  refreshProfile: () => Promise<Profile | null>;
  saveOnboarding: (input: OnboardingInput) => Promise<Profile>;
  saveProfile: (input: ProfileChanges) => Promise<Profile>;
  savePreferences: (input: PreferenceChanges) => Promise<Profile>;
};

const AuthContext = createContext<AuthContextValue | null>(null);
const confirmationRedirect = 'englifyquest://auth-callback';
const recoveryRedirect = 'englifyquest://reset-password';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [transition, setTransition] = useState<'authenticating' | 'signingOut' | null>(null);
  const transaction = useRef(false);
  const revision = useRef(0);
  const profileFlight = useRef<{ account: string; generation: number; promise: Promise<Profile | null> } | null>(null);
  const [session, updateSession] = useState<Session | null>(null);
  const activeAccount = useRef<string | null>(null);
  const setSession = useCallback((next: Session | null) => {
    if (activeAccount.current !== (next?.user.id ?? null)) useGuestRecent.getState().clear();
    activeAccount.current = next?.user.id ?? null;
    updateSession(next);
  }, []);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(authConfigured);
  const [profileError, setProfileError] = useState<string | null>(null);
  const [callbackError, setCallbackError] = useState<string | null>(null);
  const [callbackTarget, setCallbackTarget] = useState<'/login' | '/reset-password' | '/home' | '/onboarding' | null>(null);
  const setDisplayName = useAppStore((state) => state.setDisplayName);
  const queryClient = useQueryClient();
  const { reconcileRemoteLanguage, markLanguageSynced } = useI18n();

  const clearLocal = useCallback(() => {
    revision.current++;
    if (activeAccount.current) clearAccountTranslations(activeAccount.current);
    setSession(null); setProfile(null); setProfileError(null); setCallbackTarget(null);
    setDisplayName(null);
    queryClient.removeQueries({ queryKey: ['journey-map'] });
    queryClient.removeQueries({ queryKey: ['home-overview'] });
  }, [queryClient, setDisplayName, setSession]);

  const requestProfile = useCallback(async (active: Session): Promise<Profile | null> => {
    const generation = revision.current;
    try {
      let data = await readProfile(active.user.id);
      if (generation !== revision.current) return null;
      const remoteLanguage = data.preferences?.interface_language;
      if (remoteLanguage) {
        const pendingLanguage = reconcileRemoteLanguage(remoteLanguage);
        if (pendingLanguage) {
          try {
            data = await updateOwnPreferences({ interface_language: pendingLanguage });
            markLanguageSynced(pendingLanguage);
          } catch (cause) {
            // Keep the local language and retry synchronization after the next authenticated load.
            if (__DEV__) console.warn('Interface language synchronization deferred:', cause instanceof Error ? cause.message : 'unknown error');
          }
        }
      }
      if (generation !== revision.current) return null;
      setProfile(data); setDisplayName(data.display_name); setProfileError(null);
      await cacheProfile(active.user.id, data).catch(() => undefined);
      return data;
    } catch (error) {
      if (generation !== revision.current) return null;
      if (error instanceof ApiError && error.status === 401) {
        await getSupabase().auth.signOut({ scope: 'local' });
        clearLocal();
        return null;
      }
      if (error instanceof ApiError && error.status === 0) {
        const cached = await getCachedProfile(active.user.id).catch(() => null);
        if (generation !== revision.current) return null;
        if (cached?.id === active.user.id) {
          setProfile(cached); setDisplayName(cached.display_name); setProfileError(null);
          return cached;
        }
      }
      setProfileError(error instanceof Error ? error.message : 'Could not load your profile');
      return null;
    }
  }, [clearLocal, markLanguageSynced, reconcileRemoteLanguage, setDisplayName]);

  const loadProfile = useCallback((active: Session) => {
    const account = active.user.id;
    const generation = revision.current;
    const pending = profileFlight.current;
    if (pending?.account === account && pending.generation === generation) return pending.promise;
    const promise = requestProfile(active).finally(() => {
      if (profileFlight.current?.promise === promise) profileFlight.current = null;
    });
    profileFlight.current = { account, generation, promise };
    return promise;
  }, [requestProfile]);

  const refreshProfile = useCallback(async () => {
    const { data, error } = await getSupabase().auth.getSession();
    if (error) {
      setProfileError('Could not restore your session. Check your connection and try again.');
      return null;
    }
    if (!data.session) { clearLocal(); return null; }
    setSession(data.session);
    return loadProfile(data.session);
  }, [clearLocal, loadProfile, setSession]);

  const commitProfile = useCallback(async (operation: () => Promise<Profile>) => {
    const generation = revision.current;
    const { data, error } = await getSupabase().auth.getSession();
    if (error) throw new Error('Could not restore your session. Check your connection and try again.');
    if (!data.session) { clearLocal(); throw new Error('Session expired. Please sign in again.'); }
    try {
      const updated = await operation();
      if (generation !== revision.current) throw new Error('Your session changed.');
      setProfile(updated); setDisplayName(updated.display_name); setProfileError(null);
      await cacheProfile(data.session.user.id, updated).catch(() => undefined);
      return updated;
    } catch (cause) {
      if (generation === revision.current && cause instanceof ApiError && cause.status === 401) {
        await getSupabase().auth.signOut({ scope: 'local' }); clearLocal();
      }
      throw cause;
    }
  }, [clearLocal, setDisplayName]);

  useEffect(() => {
    if (!authConfigured) return;
    let live = true;
    const handledUrls = new Set<string>();
    const supabase = getSupabase();
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, next) => {
      if (!live) return;
      if (event === 'INITIAL_SESSION' || (next && transaction.current)) return;
      if (!next) { clearLocal(); return; }
      if (activeAccount.current && activeAccount.current !== next.user.id) clearLocal();
      setSession(next);
    });
    async function handleUrl(url: string) {
      if (handledUrls.has(url)) return;
      handledUrls.add(url);
      const callback = parseAuthCallback(url);
      if (callback.kind === 'error') { setCallbackError(callback.message); setCallbackTarget('/login'); return; }
      if (callback.kind !== 'code') {
        if (url.includes('auth-callback') || url.includes('reset-password')) {
          setCallbackError('The email link is incomplete. Please request a new one.');
          setCallbackTarget('/login');
        }
        return;
      }
      const { data, error } = await supabase.auth.exchangeCodeForSession(callback.code);
      if (error) { setCallbackError('The email link expired. Please request a new one.'); setCallbackTarget('/login'); return; }
      const nextProfile = data.session ? await loadProfile(data.session) : null;
      setCallbackTarget(callback.recovery ? '/reset-password' : nextProfile?.preferences?.onboarding_completed_at ? '/home' : '/onboarding');
    }
    const link = Linking.addEventListener('url', ({ url }) => { void handleUrl(url); });
    void (async () => {
      try {
        const initialUrl = await Linking.getInitialURL();
        if (!live) return;
        if (initialUrl && parseAuthCallback(initialUrl).kind !== 'none') {
          await handleUrl(initialUrl);
        } else {
          const { data, error } = await supabase.auth.getSession();
          if (!live) return;
          if (error) setProfileError('Could not restore your session. Check your connection and try again.');
          else if (!data.session) clearLocal();
          else { setSession(data.session); await loadProfile(data.session); }
        }
      } catch { if (live) setProfileError('Could not restore your session. Check your connection and try again.'); }
      finally { if (live) setLoading(false); }
    })();
    return () => { live = false; subscription.unsubscribe(); link.remove(); };
  }, [clearLocal, loadProfile, setSession]);

  useEffect(() => {
    if (!loading && !transition && session && profile?.id !== session.user.id && !profileError && !callbackTarget) {
      void loadProfile(session);
    }
  }, [loading, transition, session, profile, profileError, callbackTarget, loadProfile]);

  const value = useMemo<AuthContextValue>(() => ({
    phase: transition ?? (loading ? 'initializing' : session ? 'authenticated' : 'guest'),
    configured: authConfigured, loading, session, profile: profile?.id === session?.user.id ? profile : null, profileError, callbackError,
    callbackTarget, clearCallbackTarget: () => setCallbackTarget(null),
    signIn: async (email, password) => {
      if (transaction.current) return null;
      transaction.current = true;
      setTransition('authenticating');
      try {
        const { data, error } = await getSupabase().auth.signInWithPassword({ email, password });
        if (error) throw error;
        if (!data.session) throw new Error('No session was returned. Confirm your email first.');
        setCallbackError(null);
        const generation = revision.current;
        const nextProfile = await loadProfile(data.session);
        if (generation === revision.current) setSession(data.session);
        return nextProfile;
      } finally { transaction.current = false; setTransition(null); }
    },
    signUp: async (email, password, name) => {
      if (transaction.current) return false;
      transaction.current = true;
      setTransition('authenticating');
      try {
        const { data, error } = await getSupabase().auth.signUp({
          email, password,
          options: { data: { display_name: name.trim() }, emailRedirectTo: confirmationRedirect },
        });
        if (error) throw error;
        setCallbackError(null);
        if (!data.session) return false;
        const generation = revision.current;
        await loadProfile(data.session);
        if (generation === revision.current) setSession(data.session);
        return generation === revision.current;
      } finally { transaction.current = false; setTransition(null); }
    },
    signOut: async () => {
      if (transaction.current) return;
      transaction.current = true;
      setTransition('signingOut');
      usePendingDestination.getState().set(null);
      clearLocal();
      try {
        const { error } = await getSupabase().auth.signOut({ scope: 'local' });
        if (error) await removePersistedSession();
      } catch {
        try { await removePersistedSession(); }
        catch { setProfileError('Could not clear the stored session. Try signing out again.'); }
      } finally { transaction.current = false; setTransition(null); }
    },
    requestPasswordReset: async (email) => {
      const { error } = await getSupabase().auth.resetPasswordForEmail(email, { redirectTo: recoveryRedirect });
      if (error) throw error;
    },
    updatePassword: async (password) => {
      const { error } = await getSupabase().auth.updateUser({ password });
      if (error) throw error;
    },
    refreshProfile,
    saveOnboarding: async (input) => {
      const generation = revision.current;
      const { data, error } = await getSupabase().auth.getSession();
      if (error) throw new Error('Could not restore your session. Check your connection and try again.');
      if (!data.session) { clearLocal(); throw new Error('Session expired. Please sign in again.'); }
      try {
        const updated = await completeOnboarding(input);
        if (generation !== revision.current) throw new Error('Your session changed.');
        setProfile(updated); setDisplayName(updated.display_name); setProfileError(null);
        await cacheProfile(data.session.user.id, updated).catch(() => undefined);
        return updated;
      } catch (cause) {
        if (generation === revision.current && cause instanceof ApiError && cause.status === 401) {
          await getSupabase().auth.signOut({ scope: 'local' }); clearLocal();
        }
        throw cause;
      }
    },
    saveProfile: (input) => commitProfile(() => updateOwnProfile(input)),
    savePreferences: async (input) => {
      const updated = await commitProfile(() => updateOwnPreferences(input));
      if (input.interface_language && updated.preferences?.interface_language === input.interface_language) {
        markLanguageSynced(input.interface_language);
      }
      return updated;
    },
  }), [transition, loading, session, profile, profileError, callbackError, callbackTarget, clearLocal, loadProfile, refreshProfile, commitProfile, markLanguageSynced, setDisplayName, setSession]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const value = useContext(AuthContext);
  if (!value) throw new Error('AuthProvider is missing');
  return value;
}
