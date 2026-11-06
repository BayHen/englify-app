from fastapi.testclient import TestClient

from app.main import create_app


def test_health_endpoints_without_database() -> None:
    with TestClient(create_app()) as client:
        for path in ("/health", "/api/v1/health"):
            response = client.get(path)
            assert response.status_code == 200
            assert response.json() == {"data": {"status": "ok"}, "error": None}
            assert response.headers["X-Request-ID"]
