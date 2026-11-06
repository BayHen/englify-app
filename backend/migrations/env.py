"""Alembic environment for PostgreSQL migrations."""

from alembic import context
from sqlalchemy import create_engine, pool

from app.core.config import Settings
from app.db.base import Base

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = Settings().require_database_url()
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    engine = create_engine(Settings().require_database_url(), poolclass=pool.NullPool)
    try:
        with engine.connect() as connection:
            context.configure(connection=connection, target_metadata=target_metadata)
            with context.begin_transaction():
                context.run_migrations()
    finally:
        engine.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
