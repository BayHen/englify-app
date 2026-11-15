"""Read-only production RLS check with a synthetic non-admin JWT claim.

This tests database policies, not a real user login or the full gateway.
"""

from __future__ import annotations

import psycopg
from deploy_hybrid_migrations import target_url

SYNTHETIC_USER = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'


def main() -> None:
    with psycopg.connect(target_url(), connect_timeout=10,
                         options='-c statement_timeout=10000') as connection:
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT set_config('request.jwt.claim.sub',%s,true)", (SYNTHETIC_USER,))
                cursor.execute('SET LOCAL ROLE authenticated')
                cursor.execute("SELECT count(*) FROM public.real_english_lessons "
                               "WHERE status<>'published'")
                if cursor.fetchone()[0] != 0:
                    raise RuntimeError('A non-admin could read unpublished lessons')
                cursor.execute("SELECT count(*) FROM public.real_english_phrases p "
                               "JOIN public.real_english_lessons l ON l.id=p.lesson_id "
                               "WHERE l.status<>'published'")
                if cursor.fetchone()[0] != 0:
                    raise RuntimeError('A non-admin could read unpublished expressions')
                cursor.execute("SELECT count(*) FROM public.real_english_lessons WHERE status='published'")
                published_count = cursor.fetchone()[0]
                if published_count < 1:
                    raise RuntimeError('Published lesson is not visible to a learner claim')
            print('Production RLS hides unpublished content and shows', published_count,
                  'published lessons to a synthetic learner claim.')
        finally:
            connection.rollback()


if __name__ == '__main__':
    main()
