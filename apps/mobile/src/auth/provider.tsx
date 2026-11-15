import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import * as Linking from 'expo-linking';
import { useQueryClient } from '@tanstack/react-query';
import type { Session } from '@supabase/supabase-js';
import { ApiError } from '@/lib/api';
import { useAppStore } from '@/state/app-store';
import type { OnboardingInput, Profile, ProfileChanges, PreferenceChanges } from './api';
import { completeOnboarding, readProfile, updateOwnPreferences, updateOwnProfile } from './profile-repository';
import { parseAuthCallback } from './callback';
import { authConfigured, getSupabase } from './supabase';
import { cacheProfile, getCachedProfile } from '@/features/offline/storage';

type AuthContextValue = {
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
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(authConfigured);
  const [profileError, setProfileError] = useState<string | null>(null);
  const [callbackError, setCallbackError] = useState<string | null>(null);
  const [callbackTarget, setCallbackTarget] = useState<'/login' | '/reset-password' | '/home' | '/onboarding' | null>(null);
  const setDisplayName = useAppStore((state) => state.setDisplayName);
  const queryClient = useQueryClient();

  const clearLocal = useCallback(() => {
    setSession(null); setProfile(null); setProfileError(null); setCallbackTarget(null);
    setDisplayName(null); queryClient.clear();
  }, [queryClient, setDisplayName]);

  const loadProfile = useCallback(async (active: Session): Promise<Profile | null> => {
    try {
      const data = await readProfile(active.user.id);
      setProfile(data); setDisplayName(data.display_name); setProfileError(null);
      await cacheProfile(active.user.id, data).catch(() => undefined);
      return data;
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        await getSupabase().auth.signOut({ scope: 'local' });
        clearLocal();
        return null;
      }
      if (error instanceof ApiError && error.status === 0) {
        const cached = await getCachedProfile(active.user.id).catch(() => null);
        if (cached?.id === active.user.id) {
          setProfile(cached); setDisplayName(cached.display_name); setProfileError(null);
          return cached;
        }
      }
      setProfileError(error instanceof Error ? error.message : 'Could not load your profile');
      return null;
    }
  }, [clearLocal, setDisplayName]);

  const refreshProfile = useCallback(async () => {
    const { data, error } = await getSupabase().auth.getSession();
    if (error) {
      setProfileError('Could not restore your session. Check your connection and try again.');
      return null;
    }
    if (!data.session) { clearLocal(); return null; }
    setSession(data.session);
    return loadProfile(data.session);
  }, [clearLocal, loadProfile]);

  const commitProfile = useCallback(async (operation: () => Promise<Profile>) => {
    const { data, error } = await getSupabase().auth.getSession();
    if (error) throw new Error('Could not restore your session. Check your connection and try again.');
    if (!data.session) { clearLocal(); throw new Error('Session expired. Please sign in again.'); }
    try {
      const updated = await operation();
      setProfile(updated); setDisplayName(updated.display_name); setProfileError(null);
      await cacheProfile(data.session.user.id, updated).catch(() => undefined);
      return updated;
    } catch (cause) {
      if (cause instanceof ApiError && cause.status === 401) {
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
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, next) => {
      if (!live) return;
      setSession(next);
      if (!next) { clearLocal(); return; }
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
      const { error } = await supabase.auth.exchangeCodeForSession(callback.code);
      if (error) { setCallbackError('The email link expired. Please request a new one.'); setCallbackTarget('/login'); return; }
      const nextProfile = await refreshProfile();
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
  }, [clearLocal, loadProfile, refreshProfile]);

  const value = useMemo<AuthContextValue>(() => ({
    configured: authConfigured, loading, session, profile, profileError, callbackError,
    callbackTarget, clearCallbackTarget: () => setCallbackTarget(null),
    signIn: async (email, password) => {
      const { data, error } = await getSupabase().auth.signInWithPassword({ email, password });
      if (error) throw error;
      if (!data.session) throw new Error('No session was returned. Confirm your email first.');
      setCallbackError(null);
      setSession(data.session);
      return loadProfile(data.session);
    },
    signUp: async (email, password, name) => {
      const { data, error } = await getSupabase().auth.signUp({
        email, password,
        options: { data: { display_name: name.trim() }, emailRedirectTo: confirmationRedirect },
      });
      if (error) throw error;
      setCallbackError(null);
      if (data.session) { setSession(data.session); await loadProfile(data.session); }
      return Boolean(data.session);
    },
    signOut: async () => {
      try {
        await getSupabase().auth.signOut({ scope: 'local' });
      } catch {
        // Local UI state must be cleared even if server revocation is unavailable.
      } finally { clearLocal(); }
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
      const { data, error } = await getSupabase().auth.getSession();
      if (error) throw new Error('Could not restore your session. Check your connection and try again.');
      if (!data.session) { clearLocal(); throw new Error('Session expired. Please sign in again.'); }
      try {
        const updated = await completeOnboarding(input);
        setProfile(updated); setDisplayName(updated.display_name); setProfileError(null);
        await cacheProfile(data.session.user.id, updated).catch(() => undefined);
        return updated;
      } catch (cause) {
        if (cause instanceof ApiError && cause.status === 401) {
          await getSupabase().auth.signOut({ scope: 'local' }); clearLocal();
        }
        throw cause;
      }
    },
    saveProfile: (input) => commitProfile(() => updateOwnProfile(input)),
    savePreferences: (input) => commitProfile(() => updateOwnPreferences(input)),
  }), [loading, session, profile, profileError, callbackError, callbackTarget, clearLocal, loadProfile, refreshProfile, commitProfile, setDisplayName]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const value = useContext(AuthContext);
  if (!value) throw new Error('AuthProvider is missing');
  return value;
}
