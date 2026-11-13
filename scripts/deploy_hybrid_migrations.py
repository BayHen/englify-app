"""Apply the reviewed additive Admin/V2 migrations to the configured Supabase project.

Default mode validates both migrations inside a transaction and rolls back.
Use --apply only after inspecting dry-run output and confirming the target project.
This script never prints the database URL or credentials.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from urllib.parse import urlsplit

import psycopg

MIGRATIONS = (
    Path('supabase/migrations/20261110170000_admin_rls_foundation.sql'),
    Path('supabase/migrations/20261111010000_real_english_hybrid_foundation.sql'),
)


def env_value(path: Path, name: str) -> str:
    for line in path.read_text(encoding='utf-8').splitlines():
        if line.startswith(f'{name}='):
            return line.partition('=')[2].strip().strip('"')
    raise SystemExit(f'{name} is missing from {path}.')


def target_url() -> str:
    app_url = env_value(Path('apps/admin/.env.local'), 'NEXT_PUBLIC_SUPABASE_URL')
    project_ref = (urlsplit(app_url).hostname or '').removesuffix('.supabase.co')
    if not project_ref or not app_url.endswith(f'{project_ref}.supabase.co'):
        raise SystemExit('Admin Supabase URL is invalid.')
    raw = env_value(Path('.env'), 'ENGLIFY_DATABASE_URL')
    raw = raw.replace('postgresql+psycopg://', 'postgresql://', 1)
    db_target = urlsplit(raw)
    if project_ref not in (db_target.hostname or '') and project_ref not in (db_target.username or ''):
        raise SystemExit('Database URL and Admin URL target different projects.')
    return raw


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true', help='Commit migration changes to the configured project')
    parser.add_argument('--verify', action='store_true', help='Read only post-deployment metadata checks')
    arguments = parser.parse_args()
    if arguments.apply and arguments.verify:
        parser.error('--apply and --verify are mutually exclusive')
    connection = psycopg.connect(target_url(), connect_timeout=10,
                                 options='-c lock_timeout=3000 -c statement_timeout=60000'
                                 + (' -c default_transaction_read_only=on' if arguments.verify else ''))
    try:
        if arguments.verify:
            with connection.cursor() as cursor:
                cursor.execute("""
                    SELECT to_regprocedure('public.englify_is_admin()') IS NOT NULL,
                           to_regclass('public.real_english_lessons') IS NOT NULL,
                           to_regclass('public.real_english_generation_settings') IS NOT NULL,
                           (SELECT relrowsecurity FROM pg_class WHERE oid='public.real_english_lessons'::regclass)
                """)
                print('admin_rpc_lesson_table_settings_rls=', cursor.fetchone())
                cursor.execute("""
                    SELECT count(*) FROM pg_policies WHERE schemaname='public'
                      AND tablename IN ('real_english_lessons','real_english_user_progress',
                                        'real_english_generation_settings')
                """)
                print('relevant_policy_count=', cursor.fetchone()[0])
                cursor.execute("""
                    SELECT to_regprocedure('extensions.digest(text,text)') IS NOT NULL,
                           to_regprocedure('auth.uid()') IS NOT NULL
                """)
                print('pgcrypto_and_auth_helpers=', cursor.fetchone())
                cursor.execute('SELECT count(*) FROM public.admin_members')
                print('admin_member_count=', cursor.fetchone()[0])
                cursor.execute('SELECT user_id FROM public.admin_members LIMIT 1')
                member = cursor.fetchone()
                if member:
                    cursor.execute("SELECT set_config('request.jwt.claim.sub', %s, true)", (str(member[0]),))
                    cursor.execute('SET LOCAL ROLE authenticated')
                    cursor.execute('SELECT public.englify_is_admin()')
                    print('admin_membership_rpc=', cursor.fetchone()[0])
                    cursor.execute('SELECT count(*) FROM public.real_english_generation_settings')
                    print('admin_settings_visible=', cursor.fetchone()[0] == 1)
                    cursor.execute("SELECT set_config('request.jwt.claim.sub', %s, true)",
                                   ('00000000-0000-4000-8000-000000000000',))
                    cursor.execute('SELECT public.englify_is_admin()')
                    print('nonmember_membership_rpc=', cursor.fetchone()[0])
                    cursor.execute('SELECT count(*) FROM public.real_english_generation_settings')
                    print('nonmember_settings_visible=', cursor.fetchone()[0] == 0)
            connection.rollback()
            return
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT to_regprocedure('public.englify_is_admin()') IS NOT NULL,
                       to_regclass('public.real_english_lessons') IS NOT NULL
            """)
            current = cursor.fetchone()
            if current != (False, False):
                raise SystemExit(f'Expected both migrations to be pending; current object presence: {current}')
        for migration in MIGRATIONS:
            connection.execute(migration.read_text(encoding='utf-8'))
            print(f'validated={migration.name}')
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT to_regprocedure('public.englify_is_admin()') IS NOT NULL,
                       to_regclass('public.real_english_lessons') IS NOT NULL,
                       to_regclass('public.real_english_generation_settings') IS NOT NULL
            """)
            if cursor.fetchone() != (True, True, True):
                raise RuntimeError('Migration postcondition failed.')
        if arguments.apply:
            connection.commit()
            print('COMMIT completed: both reviewed migrations applied')
        else:
            connection.rollback()
            print('ROLLBACK completed: dry-run made no persistent changes')
    except BaseException:
        connection.rollback()
        raise
    finally:
        connection.close()


if __name__ == '__main__':
    main()
