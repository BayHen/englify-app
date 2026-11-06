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
    cors_origins: str = ""

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
            raise ValueError(
                "ENGLIFY_DATABASE_URL must use postgresql+psycopg and name a database"
            )
        return value

    @model_validator(mode="after")
    def validate_cors(self) -> "Settings":
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
