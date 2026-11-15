import { searchTatoeba } from '../supabase/functions/_shared/tatoeba.ts';

const start = Date.now();
try {
  const page = await searchTatoeba('coffee');
  console.log(`pairs=${page.pairs.length};eligible=${page.pairs.filter((pair) => pair.validationStatus === 'eligible').length};elapsed_ms=${Date.now() - start}`);
} catch (error) {
  console.log(`request_error=${error instanceof Error ? error.name : 'unknown'};elapsed_ms=${Date.now() - start}`);
}
