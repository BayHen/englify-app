"""Load reviewed, original Real English development content."""

from pathlib import Path

import psycopg
from sqlalchemy.engine import make_url

from app.core.config import Settings


def main() -> None:
    settings = Settings()
    if settings.environment == "production":
        raise RuntimeError("Development content cannot be loaded in production")
    script = Path(__file__).with_name("real_english_development.sql").read_text(encoding="utf-8")
    url = make_url(settings.require_database_url()).set(drivername="postgresql")
    with psycopg.connect(url.render_as_string(hide_password=False), autocommit=True) as connection:
        connection.execute(script)
    print("Real English development content loaded")


if __name__ == "__main__":
    main()
