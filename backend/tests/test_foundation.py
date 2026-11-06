import json
import logging
from typing import Annotated

import pytest
from fastapi import Depends, FastAPI, Query
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.logging import JsonFormatter
from app.core.responses import AppError
from app.db.session import get_db_session, get_settings
from app.main import create_app


def test_settings_reject_invalid_database_and_cors() -> None:
    with pytest.raises(ValidationError, match=r"postgresql\+psycopg"):
        Settings(_env_file=None, database_url="sqlite:///local.db")
    with pytest.raises(ValidationError) as secret_error:
        Settings(_env_file=None, database_url="postgresql+psycopg://user:private-value@host")
    assert "private-value" not in str(secret_error.value)
    with pytest.raises(ValidationError, match="HTTPS"):
        Settings(_env_file=None, environment="production", cors_origins="http://localhost:3000")
    with pytest.raises(ValidationError, match="explicit HTTP origins"):
        Settings(_env_file=None, cors_origins="*")


def test_settings_and_database_dependency_without_docker() -> None:
    settings = Settings(_env_file=None, environment="test")
    app = create_app(settings)

    @app.get("/api/v1/test-settings")
    def read_settings(config: Annotated[Settings, Depends(get_settings)]) -> dict[str, str]:
        return {"environment": config.environment}

    @app.get("/api/v1/test-db")
    def read_database(_session: Annotated[Session, Depends(get_db_session)]) -> dict[str, bool]:
        return {"connected": True}

    with TestClient(app) as client:
        assert client.get("/api/v1/test-settings").json() == {"environment": "test"}
        response = client.get("/api/v1/test-db")
        assert response.status_code == 503
        assert response.json() == {
            "data": None,
            "error": {
                "code": "database_not_configured",
                "message": (
                    "Database is not configured; set ENGLIFY_DATABASE_URL for data endpoints"
                ),
            },
        }


def test_global_error_shapes_and_validation() -> None:
    app: FastAPI = create_app(Settings(_env_file=None, environment="test"))

    @app.get("/api/v1/test-error")
    def fail() -> None:
        raise AppError(409, "conflict", "Already exists")

    @app.get("/api/v1/test-unknown")
    def fail_unknown() -> None:
        raise RuntimeError("do not expose this text")

    @app.get("/api/v1/test-validated")
    def validated(count: int = Query(ge=1)) -> dict[str, int]:
        return {"count": count}

    with TestClient(app, raise_server_exceptions=False) as client:
        assert client.get("/api/v1/test-error").json() == {
            "data": None,
            "error": {"code": "conflict", "message": "Already exists"},
        }
        invalid = client.get("/api/v1/test-validated?count=0")
        assert invalid.status_code == 422
        assert invalid.json()["error"]["code"] == "validation_error"
        assert invalid.json()["error"]["details"][0]["field"] == "query.count"
        unknown = client.get("/api/v1/test-unknown")
        assert unknown.status_code == 500
        assert unknown.headers["X-Request-ID"]
        assert unknown.json()["error"] == {
            "code": "internal_error", "message": "An unexpected error occurred"
        }
        assert "do not expose" not in unknown.text
        assert client.get("/missing").json()["error"]["code"] == "http_error"


def test_cors_only_allows_explicit_development_origins() -> None:
    app = create_app(Settings(_env_file=None, environment="development"))
    with TestClient(app) as client:
        allowed = client.options(
            "/api/v1/health",
            headers={"Origin": "http://localhost:3000", "Access-Control-Request-Method": "GET"},
        )
        assert allowed.headers["access-control-allow-origin"] == "http://localhost:3000"
        denied = client.options(
            "/api/v1/health",
            headers={"Origin": "https://example.com", "Access-Control-Request-Method": "GET"},
        )
        assert denied.status_code == 400
        assert "access-control-allow-origin" not in denied.headers


def test_structured_log_formatter() -> None:
    record = logging.LogRecord("englify", logging.INFO, __file__, 1, "HTTP request", (), None)
    record.request_id = "example-id"
    record.status_code = 200
    payload = json.loads(JsonFormatter().format(record))
    assert payload["request_id"] == "example-id"
    assert payload["status_code"] == 200
    assert payload["timestamp"].endswith("+00:00")
