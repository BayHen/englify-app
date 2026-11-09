from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import create_app


def test_health_endpoints_without_database() -> None:
    with TestClient(create_app()) as client:
        for path in ("/health", "/api/v1/health"):
            response = client.get(path)
            assert response.status_code == 200
            assert response.json() == {"data": {"status": "ok"}, "error": None}
            assert response.headers["X-Request-ID"]


def test_https_expo_web_origin_is_explicitly_allowed() -> None:
    settings = Settings(
        _env_file=None, environment="development",
        cors_origins="https://preview.on.expo.app",
    )
    with TestClient(create_app(settings)) as client:
        allowed = client.options(
            "/api/v1/me",
            headers={
                "Origin": "https://preview.on.expo.app",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization",
            },
        )
        other = client.options(
            "/api/v1/me",
            headers={
                "Origin": "https://untrusted.on.expo.app",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization",
            },
        )
    assert allowed.status_code == 200
    assert allowed.headers["access-control-allow-origin"] == "https://preview.on.expo.app"
    assert "access-control-allow-origin" not in other.headers
