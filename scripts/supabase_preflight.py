"""Read-only inventory of the existing Supabase PostgreSQL schema.

Run from the repository root. Never prints database URLs or row contents.
"""

from __future__ import annotations

import sys
from pathlib import Path

from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))
from app.core.config import Settings


def main() -> int:
    settings = Settings()
    if settings.database_url is None:
        print("BLOCKED: ENGLIFY_DATABASE_URL is not configured.")
        return 2
    engine = create_engine(
        settings.require_database_url(),
        pool_pre_ping=True,
        connect_args={"connect_timeout": 5},
    )
    try:
        with engine.connect() as connection:
            connection.execute(text("SET TRANSACTION READ ONLY"))
            version = connection.execute(
                text("SELECT version_num FROM public.alembic_version LIMIT 1")
            ).scalar_one_or_none()
            print(f"alembic_revision={version or 'missing'}")
            rows = connection.execute(
                text("""
                    SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled,
                           EXISTS (
                             SELECT 1 FROM pg_policies p
                             WHERE p.schemaname = 'public' AND p.tablename = c.relname
                           ) AS has_policy
                    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                    WHERE n.nspname = 'public' AND c.relkind = 'r'
                    ORDER BY c.relname
                """)
            ).mappings().all()
            for row in rows:
                # relname comes from pg_class, not from an external argument.
                quoted = connection.dialect.identifier_preparer.quote(row["table_name"])
                count = connection.execute(text(f"SELECT count(*) FROM public.{quoted}")).scalar_one()
                print(
                    f"{row['table_name']}: count={count}, "
                    f"rls={row['rls_enabled']}, policy={row['has_policy']}"
                )
            unvalidated = connection.execute(
                text("""
                    SELECT count(*) FROM pg_constraint co
                    JOIN pg_class c ON c.oid = co.conrelid
                    JOIN pg_namespace n ON n.oid = c.relnamespace
                    WHERE n.nspname = 'public' AND NOT co.convalidated
                """)
            ).scalar_one()
            print(f"unvalidated_constraints={unvalidated}")
            connection.rollback()
    except SQLAlchemyError:
        print("BLOCKED: database preflight failed; check connectivity and read permissions.")
        return 2
    finally:
        engine.dispose()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
