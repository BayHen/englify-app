"""Verify Supabase access tokens before allowing private API access."""

from dataclasses import dataclass
from typing import Annotated
from uuid import UUID

import httpx
import jwt
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient
from jwt.exceptions import PyJWKClientConnectionError, PyJWTError

from app.core.config import Settings
from app.core.responses import AppError
from app.db.session import get_settings

bearer = HTTPBearer(auto_error=False)
_jwks_clients: dict[str, PyJWKClient] = {}


@dataclass(frozen=True)
class CurrentUser:
    id: UUID


def verify_access_token(token: str, settings: Settings) -> CurrentUser:
    if settings.supabase_url is None:
        raise AppError(503, "auth_not_configured", "Supabase Auth is not configured")
    issuer = f"{settings.supabase_url}/auth/v1"
    try:
        algorithm = jwt.get_unverified_header(token).get("alg")
    except (PyJWTError, ValueError, TypeError) as exc:
        raise AppError(401, "invalid_token", "Access token is invalid or expired") from exc
    if algorithm == "HS256":
        return _verify_legacy_token(token, settings, issuer)
    if algorithm not in {"RS256", "ES256"}:
        raise AppError(401, "invalid_token", "Access token is invalid or expired")
    client = _jwks_clients.setdefault(
        issuer,
        PyJWKClient(f"{issuer}/.well-known/jwks.json", cache_jwk_set=True, lifespan=300, timeout=5),
    )
    try:
        key = client.get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            key.key,
            algorithms=["RS256", "ES256"],
            audience="authenticated",
            issuer=issuer,
            options={"require": ["exp", "iat", "iss", "aud", "sub", "role"]},
            leeway=5,
        )
        if claims.get("role") != "authenticated":
            raise ValueError("Not a user access token")
        return CurrentUser(id=UUID(claims["sub"]))
    except PyJWKClientConnectionError as exc:
        raise AppError(
            503, "auth_unavailable", "Token verification is temporarily unavailable"
        ) from exc
    except (PyJWTError, ValueError, KeyError, TypeError) as exc:
        raise AppError(401, "invalid_token", "Access token is invalid or expired") from exc


def _verify_legacy_token(token: str, settings: Settings, issuer: str) -> CurrentUser:
    """Legacy HS256 must be verified by Supabase Auth, never with a mobile secret."""
    if not settings.supabase_publishable_key:
        raise AppError(
            503, "auth_not_configured", "Legacy Auth verification needs a publishable key"
        )
    try:
        with httpx.Client(timeout=5) as client:
            response = client.get(
                f"{issuer}/user",
                headers={
                    "apikey": settings.supabase_publishable_key,
                    "Authorization": f"Bearer {token}",
                },
            )
        if response.status_code in {401, 403}:
            raise AppError(401, "invalid_token", "Access token is invalid or expired")
        response.raise_for_status()
        user = response.json()
        claims = jwt.decode(
            token,
            options={
                "verify_signature": False,
                "verify_exp": True,
                "verify_aud": True,
                "verify_iss": True,
                "require": ["exp", "iat", "iss", "aud", "sub", "role"],
            },
            audience="authenticated",
            issuer=issuer,
            leeway=5,
        )
        if claims.get("role") != "authenticated" or user.get("id") != claims.get("sub"):
            raise ValueError("Token and Auth user do not match")
        return CurrentUser(id=UUID(user["id"]))
    except AppError:
        raise
    except (httpx.TimeoutException, httpx.NetworkError) as exc:
        raise AppError(
            503, "auth_unavailable", "Auth verification is temporarily unavailable"
        ) from exc
    except httpx.HTTPStatusError as exc:
        raise AppError(
            503, "auth_unavailable", "Auth verification is temporarily unavailable"
        ) from exc
    except (PyJWTError, ValueError, KeyError, TypeError) as exc:
        raise AppError(401, "invalid_token", "Access token is invalid or expired") from exc


def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> CurrentUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AppError(401, "authentication_required", "Sign in to access this resource")
    return verify_access_token(credentials.credentials, settings)
