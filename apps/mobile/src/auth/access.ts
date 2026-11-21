import type { Href } from 'expo-router';
import { create } from 'zustand';
import type { AuthPhase } from './provider';

const accountRoutes = [
  'journey', 'journey-placement', 'learning-plan', 'practice', 'coach', 'vocabulary-review',
  'real-english', 'speaking', 'writing', 'writing-progress', 'quiz-arena', 'mistakes', 'rewards',
  'explore', 'account-settings', 'edit-profile', 'change-avatar', 'change-password', 'learning-preferences',
];
const accountDetail = /^\/(lesson|writing-progress|quiz-practice|time-attack|ranked-arena|mistake-review)\/[\w-]+$/;

export function accountDestination(path: string): Href | null {
  return accountRoutes.some((route) => path === `/${route}`) || accountDetail.test(path) ? path as Href : null;
}

export function authenticationRedirects(phase: AuthPhase, signedIn: boolean, hasProfile: boolean, onboarded: boolean, destination: Href | null) {
  const requiresOnboarding = signedIn && hasProfile && !onboarded;
  return {
    publicAuth: requiresOnboarding ? '/onboarding' as const : (onboarded ? destination : null) ?? '/home',
    privateRoute: phase === 'signingOut' || (signedIn && !hasProfile) ? '/home'
      : requiresOnboarding ? '/onboarding' : '/login-required',
  } satisfies Record<string, Href>;
}

export const usePendingDestination = create<{ destination: Href | null; set: (destination: Href | null) => void }>(
  (set) => ({ destination: null, set: (destination) => set({ destination }) }),
);
