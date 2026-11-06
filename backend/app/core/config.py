"""Validated environment configuration."""

from pathlib import Path
from typing import Literal
from urllib.parse import urlsplit

from pydantic import SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import make_url

ROOT = Path(__file__).resolve().parents[3]
DEV_ORIGINS = ("http://localhost:3000", "http://localhost:8081")


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="ENGLIFY_",
        env_file=ROOT / ".env",
        extra="ignore",
        hide_input_in_errors=True,
    )

    environment: Literal["development", "test", "production"] = "development"
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"
    database_url: SecretStr | None = None
    supabase_url: str | None = None
    supabase_publishable_key: str | None = None
    libretranslate_url: str | None = None
    libretranslate_verified_pairs: str = ""
    cors_origins: str = ""

    @field_validator("supabase_publishable_key")
    @classmethod
    def validate_publishable_key(cls, value: str | None) -> str | None:
        if value is None or not value.strip():
            return None
        if not value.startswith("sb_publishable_"):
            raise ValueError("ENGLIFY_SUPABASE_PUBLISHABLE_KEY must be a publishable key")
        return value

    @field_validator("libretranslate_url")
    @classmethod
    def validate_libre_url(cls, value: str | None) -> str | None:
        if not value or not value.strip():
            return None
        parsed = urlsplit(value.rstrip("/"))
        if (
            parsed.scheme not in {"http", "https"}
            or not parsed.netloc
            or parsed.path
            or parsed.query
            or parsed.fragment
            or parsed.username
            or parsed.password
        ):
            raise ValueError(
                "ENGLIFY_LIBRETRANSLATE_URL must be an origin without credentials or path"
            )
        if parsed.scheme == "http" and parsed.hostname not in {
            "localhost",
            "127.0.0.1",
            "libretranslate",
        }:
            raise ValueError("ENGLIFY_LIBRETRANSLATE_URL must use HTTPS outside local development")
        return value.rstrip("/")

    @field_validator("supabase_url")
    @classmethod
    def validate_supabase_url(cls, value: str | None) -> str | None:
        if value is None or not value.strip():
            return None
        parsed = urlsplit(value.rstrip("/"))
        if (
            parsed.scheme not in {"https", "http"}
            or not parsed.netloc
            or parsed.path
            or parsed.query
            or parsed.fragment
            or parsed.username
            or parsed.password
        ):
            raise ValueError("ENGLIFY_SUPABASE_URL must be an origin without credentials or a path")
        if parsed.scheme == "http" and parsed.hostname not in {"localhost", "127.0.0.1"}:
            raise ValueError("ENGLIFY_SUPABASE_URL must use HTTPS outside localhost")
        return value.rstrip("/")

    @field_validator("database_url")
    @classmethod
    def validate_database_url(cls, value: SecretStr | None) -> SecretStr | None:
        if value is None or not value.get_secret_value():
            return None
        try:
            url = make_url(value.get_secret_value())
        except Exception as exc:
            raise ValueError("ENGLIFY_DATABASE_URL must be a valid SQLAlchemy URL") from exc
        if url.drivername != "postgresql+psycopg" or not url.database:
            raise ValueError("ENGLIFY_DATABASE_URL must use postgresql+psycopg and name a database")
        return value

    @model_validator(mode="after")
    def validate_cors(self) -> "Settings":
        if (
            self.environment == "production"
            and self.supabase_url
            and not self.supabase_url.startswith("https://")
        ):
            raise ValueError("Production ENGLIFY_SUPABASE_URL must use HTTPS")
        for origin in self.allowed_origins:
            parsed = urlsplit(origin)
            if (
                parsed.scheme not in {"http", "https"}
                or not parsed.netloc
                or parsed.username
                or parsed.password
                or parsed.path
                or parsed.query
                or parsed.fragment
                or "*" in origin
            ):
                raise ValueError("ENGLIFY_CORS_ORIGINS must contain explicit HTTP origins")
            if self.environment == "production" and parsed.scheme != "https":
                raise ValueError("Production CORS origins must use HTTPS")
        return self

    @property
    def allowed_origins(self) -> tuple[str, ...]:
        if self.cors_origins.strip():
            return tuple(
                origin.strip() for origin in self.cors_origins.split(",") if origin.strip()
            )
        return DEV_ORIGINS if self.environment == "development" else ()

    def require_database_url(self) -> str:
        if self.database_url is None:
            raise RuntimeError(
                "ENGLIFY_DATABASE_URL is required for database operations; "
                "set it in the root .env or start the Docker development stack"
            )
        return self.database_url.get_secret_value()
