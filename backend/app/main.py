"""Englify Quest application factory and ASGI entry point."""

import logging
from contextlib import asynccontextmanager
from time import perf_counter
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from app.api.dictionary import router as dictionary_router
from app.api.gamification import router as gamification_router
from app.api.health import router as health_router
from app.api.learning import router as learning_router
from app.api.me import router as me_router
from app.api.translation import router as translation_router
from app.core.config import Settings
from app.core.exceptions import error_response, register_exception_handlers
from app.core.logging import configure_logging
from app.db.session import init_engine_state


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings()
    configure_logging(settings.log_level)

    @asynccontextmanager
    async def lifespan(application: FastAPI):
        yield
        if application.state.engine is not None:
            application.state.engine.dispose()

    application = FastAPI(title="Englify Quest API", version="0.1.0", lifespan=lifespan)
    application.state.settings = settings
    init_engine_state(application)
    application.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.allowed_origins),
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
        allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
    )

    @application.middleware("http")
    async def log_request(request: Request, call_next):
        request_id = uuid4().hex
        request.state.request_id = request_id
        started = perf_counter()
        try:
            response = await call_next(request)
        except Exception as exc:
            logging.getLogger("englify").error(
                "Unhandled request error",
                extra={"request_id": request_id, "error_type": type(exc).__name__},
            )
            response = error_response(500, "internal_error", "An unexpected error occurred")
        response.headers["X-Request-ID"] = request_id
        logging.getLogger("englify").info(
            "HTTP request",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": round((perf_counter() - started) * 1000, 2),
            },
        )
        return response

    register_exception_handlers(application)
    application.include_router(health_router)
    application.include_router(dictionary_router)
    application.include_router(me_router)
    application.include_router(translation_router)
    application.include_router(learning_router)
    application.include_router(gamification_router)
    return application


app = create_app()
