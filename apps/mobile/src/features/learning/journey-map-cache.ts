import type { QueryClient } from '@tanstack/react-query';
import { cacheJourney } from '@/features/offline/storage';
import { getJourney, type JourneyCourse } from './api';

const mapKey = (userId: string) => ['journey-map', userId] as const;

export function readJourneyMap(client: QueryClient, userId?: string) {
  return userId ? client.getQueryData<JourneyCourse[]>(mapKey(userId)) : undefined;
}

export function refreshJourneyMap(client: QueryClient, userId: string) {
  return client.fetchQuery({
    queryKey: mapKey(userId),
    retry: false,
    queryFn: async () => {
      const courses = await getJourney();
      void cacheJourney(userId, { courses, savedAt: new Date().toISOString() }).catch(() => undefined);
      return courses;
    },
  });
}
