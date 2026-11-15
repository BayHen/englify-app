"""Install the one-draft/day Real English schedule after explicit Free tier approval.

No credentials are printed. Default invocation rolls back database changes. --apply
sets a random Edge-only Cron secret, stores it in Vault, and commits one schedule.
"""

from __future__ import annotations

import argparse
import json
import os
import secrets
import subprocess
import sys
import tempfile
from pathlib import Path

import psycopg

from deploy_hybrid_migrations import target_url


PROJECT = 'agoydsinleaiovsgbxxf'
ROOT = Path(__file__).resolve().parents[1]


def anon_jwt() -> str:
    result = subprocess.run(
        ['npx.cmd', 'supabase', 'projects', 'api-keys', f'--remote={PROJECT}', '--output-format', 'json'],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    keys = json.loads(result.stdout)['keys']
    matches = [entry['api_key'] for entry in keys if entry['name'] == 'anon' and entry['type'] == 'legacy']
    if len(matches) != 1 or matches[0].count('.') != 2:
        raise RuntimeError('Exactly one legacy anon JWT is required; schedule not installed.')
    return matches[0]


def set_edge_secret(value: str) -> None:
    descriptor, path = tempfile.mkstemp(prefix='englify-cron-', suffix='.env')
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8') as handle:
            handle.write(f'REAL_ENGLISH_CRON_SECRET={value}\n')
        subprocess.run(
            ['npx.cmd', 'supabase', 'secrets', 'set', '--env-file', path,
             f'--remote={PROJECT}', '--yes'],
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
    finally:
        os.unlink(path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    anon = anon_jwt()
    secret = secrets.token_urlsafe(48)
    url = f'https://{PROJECT}.supabase.co/functions/v1/real-english-generate'
    sql = (ROOT / 'supabase/scripts/enable_real_english_cron.sql').read_text(encoding='utf-8')
    with psycopg.connect(target_url(), connect_timeout=10,
                         options='-c lock_timeout=3000 -c statement_timeout=15000') as connection:
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT ai_generation_enabled,maximum_daily_requests,daily_generation_target "
                               "FROM public.real_english_generation_settings WHERE id=true")
                if cursor.fetchone() != (True, 1, 1):
                    raise RuntimeError('Free tier one-per-day database guard is not configured.')
                cursor.execute("SELECT name FROM vault.secrets WHERE name LIKE 'real_english_%'")
                if cursor.fetchone():
                    raise RuntimeError('Cron Vault configuration already exists; inspect it before changing.')
                cursor.execute('CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions')
                cursor.execute('CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions')
                cursor.execute('SELECT vault.create_secret(%s,%s)', (url, 'real_english_generate_url'))
                cursor.execute('SELECT vault.create_secret(%s,%s)', (anon, 'real_english_cron_anon_jwt'))
                cursor.execute('SELECT vault.create_secret(%s,%s)', (secret, 'real_english_cron_secret'))
                cursor.execute(sql)
                cursor.execute("SELECT count(*) FROM cron.job WHERE jobname='englify-real-english-daily' "
                               "AND active AND schedule='0 0 * * *'")
                if cursor.fetchone()[0] != 1:
                    raise RuntimeError('Daily schedule was not installed as expected.')
            if args.apply:
                # Set Edge secret before committing the schedule so the job cannot run with no second factor.
                set_edge_secret(secret)
                connection.commit()
                print('COMMIT: one 07:00 Asia/Ho_Chi_Minh draft request/day scheduled; review remains manual.')
            else:
                connection.rollback()
                print('ROLLBACK: Cron extensions, Vault entries, and schedule validated without changes.')
        except BaseException:
            connection.rollback()
            raise


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'Cron setup failed: {type(error).__name__}: {error}', file=sys.stderr)
        raise SystemExit(1) from None
