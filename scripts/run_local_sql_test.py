"""Execute SQL smoke tests only against the disposable Supabase CLI database."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path
from urllib.parse import urlsplit

import psycopg

NPX = "npx.cmd" if os.name == "nt" else "npx"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    result = subprocess.run(
        [NPX, "supabase", "status", "--output", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    database_url = json.loads(result.stdout)["DB_URL"]
    parsed = urlsplit(database_url)
    if parsed.hostname not in {"127.0.0.1", "localhost"} or parsed.port != 54322:
        raise RuntimeError("Refusing to execute SQL against a non-local database")
    with psycopg.connect(database_url, autocommit=True) as connection:
        for path in args.paths:
            sql = path.read_text(encoding="utf-8")
            connection.execute(sql)
            print(f"PASS: {path.as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
