import { useEffect, useState } from 'react';
import { AccessibilityInfo, Platform } from 'react-native';

/** Defaults to no animation until the platform preference is known. */
export function useReducedMotion(): boolean {
  const [reduced, setReduced] = useState(() => {
    if (Platform.OS !== 'web' || typeof window === 'undefined' || !window.matchMedia) return true;
    return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  });

  useEffect(() => {
    if (Platform.OS === 'web') {
      if (typeof window === 'undefined' || !window.matchMedia) return;
      const query = window.matchMedia('(prefers-reduced-motion: reduce)');
      const update = () => setReduced(query.matches);
      query.addEventListener('change', update);
      return () => query.removeEventListener('change', update);
    }

    let mounted = true;
    void AccessibilityInfo.isReduceMotionEnabled().then((value) => {
      if (mounted) setReduced(value);
    });
    const subscription = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduced);
    return () => { mounted = false; subscription.remove(); };
  }, []);

  return reduced;
}
