"""Stable error envelopes for expected and unexpected failures."""

import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.responses import ApiErrorDetail, AppError, ErrorResponse

logger = logging.getLogger("englify")


def error_response(
    status_code: int,
    code: str,
    message: str,
    details: list[dict[str, str]] | None = None,
) -> JSONResponse:
    body = ErrorResponse(error=ApiErrorDetail(code=code, message=message, details=details))
    exclude = {"error": {"details"}} if details is None else None
    return JSONResponse(status_code=status_code, content=body.model_dump(exclude=exclude))


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def app_error_handler(_request: Request, exc: AppError) -> JSONResponse:
        return error_response(exc.status_code, exc.code, exc.message)

    @app.exception_handler(RequestValidationError)
    async def validation_handler(_request: Request, exc: RequestValidationError) -> JSONResponse:
        details = [
            {
                "field": ".".join(str(part) for part in error["loc"]),
                "message": str(error["msg"]),
            }
            for error in exc.errors()
        ]
        return error_response(422, "validation_error", "Invalid request", details)

    @app.exception_handler(StarletteHTTPException)
    async def http_handler(_request: Request, exc: StarletteHTTPException) -> JSONResponse:
        message = exc.detail if isinstance(exc.detail, str) else "Request failed"
        return error_response(exc.status_code, "http_error", message)

    @app.exception_handler(Exception)
    async def unexpected_handler(request: Request, exc: Exception) -> JSONResponse:
        logger.error(
            "Unhandled request error",
            extra={
                "request_id": getattr(request.state, "request_id", None),
                "error_type": type(exc).__name__,
            },
        )
        return error_response(500, "internal_error", "An unexpected error occurred")
