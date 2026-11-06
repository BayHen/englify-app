"""Lazy database engine and request-scoped sessions."""

from collections.abc import Iterator
from threading import Lock
from typing import Annotated

from fastapi import Depends, FastAPI, Request
from sqlalchemy import Engine, create_engine
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.responses import AppError


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_engine(request: Request, settings: Annotated[Settings, Depends(get_settings)]) -> Engine:
    if settings.database_url is None:
        raise AppError(
            503,
            "database_not_configured",
            "Database is not configured; set ENGLIFY_DATABASE_URL for data endpoints",
        )
    with request.app.state.engine_lock:
        if request.app.state.engine is None:
            request.app.state.engine = create_engine(
                settings.require_database_url(), pool_pre_ping=True
            )
        return request.app.state.engine


def get_db_session(engine: Annotated[Engine, Depends(get_engine)]) -> Iterator[Session]:
    with Session(engine) as session:
        yield session


def init_engine_state(app: FastAPI) -> None:
    app.state.engine = None
    app.state.engine_lock = Lock()
