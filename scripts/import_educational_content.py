"""Validate CSV/JSON educational content and stage it for Admin review.

The command never publishes content. Remote databases require --allow-remote.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import ipaddress
import json
import os
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import psycopg

CEFR = {"A1", "A2", "B1", "B2", "C1", "C2"}
VOCABULARY_FIELDS = {
    "external_id", "term", "translation", "part_of_speech", "cefr_level", "topic",
    "example", "example_vi", "source_name", "license_id",
}


def load_records(path: Path) -> list[dict[str, Any]]:
    if path.suffix.lower() == ".csv":
        with path.open(encoding="utf-8-sig", newline="") as handle:
            return [dict(row) for row in csv.DictReader(handle)]
    if path.suffix.lower() == ".json":
        value = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(value, list) or not all(isinstance(item, dict) for item in value):
            raise ValueError("JSON input must be an array of objects")
        return value
    raise ValueError("Only .csv and .json inputs are supported")


def validate_vocabulary(record: dict[str, Any]) -> list[str]:
    errors = [f"{field} is required" for field in sorted(VOCABULARY_FIELDS) if not str(record.get(field, "")).strip()]
    if record.get("cefr_level") and record["cefr_level"] not in CEFR:
        errors.append("cefr_level must be A1-C2")
    if len(str(record.get("term", ""))) > 120:
        errors.append("term is longer than 120 characters")
    return errors


def normalized_hash(record: dict[str, Any]) -> str:
    canonical = json.dumps(record, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode()).hexdigest()


def is_loopback_url(database_url: str) -> bool:
    host = urlparse(database_url.replace("postgresql+psycopg", "postgresql", 1)).hostname
    if host == "localhost":
        return True
    try:
        return bool(host and ipaddress.ip_address(host).is_loopback)
    except ValueError:
        return False


def stage(args: argparse.Namespace) -> str:
    database_url = os.environ.get("ENGLIFY_DATABASE_URL", "")
    if not database_url:
        raise RuntimeError("ENGLIFY_DATABASE_URL is required")
    if not args.allow_remote and not is_loopback_url(database_url):
        raise RuntimeError("Remote staging requires explicit --allow-remote")
    records = load_records(args.input)
    if not records:
        raise ValueError("Input contains no records")
    seen: set[str] = set()
    prepared: list[tuple[str, dict[str, Any], str, list[str]]] = []
    for record in records:
        external_id = str(record.get("external_id", "")).strip()
        errors = validate_vocabulary(record) if args.content_type == "vocabulary" else ([] if external_id else ["external_id is required"])
        if external_id in seen:
            errors.append("duplicate external_id in input")
        seen.add(external_id)
        prepared.append((external_id, record, normalized_hash(record), errors))
    with (
        psycopg.connect(database_url.replace("postgresql+psycopg", "postgresql", 1)) as connection,
        connection.transaction(),
        connection.cursor() as cursor,
    ):
            cursor.execute("SELECT id FROM public.content_import_batches WHERE idempotency_key=%s", (args.idempotency_key,))
            existing = cursor.fetchone()
            if existing:
                return str(existing[0])
            all_errors = [{"external_id": item[0], "errors": item[3]} for item in prepared if item[3]]
            cursor.execute(
                """INSERT INTO public.content_import_batches
                (actor_id,content_type,source_name,license_id,source_url,status,idempotency_key,record_count,validation_errors)
                VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s::jsonb) RETURNING id""",
                (args.actor_id, args.content_type, args.source_name, args.license_id, args.source_url,
                 "validated" if not all_errors else "draft", args.idempotency_key, len(prepared), json.dumps(all_errors)),
            )
            batch_id = str(cursor.fetchone()[0])
            cursor.executemany(
                """INSERT INTO public.content_import_items
                (batch_id,external_id,payload,normalized_hash,status,validation_errors)
                VALUES(%s,%s,%s::jsonb,%s,%s,%s::jsonb)""",
                [(batch_id, external_id, json.dumps(payload, ensure_ascii=False), digest,
                  "validated" if not errors else "rejected", json.dumps(errors, ensure_ascii=False))
                 for external_id, payload, digest, errors in prepared],
            )
            return batch_id


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser()
    result.add_argument("input", type=Path)
    result.add_argument("--content-type", choices=("vocabulary", "lesson", "quiz", "real_english"), required=True)
    result.add_argument("--actor-id", required=True)
    result.add_argument("--source-name", required=True)
    result.add_argument("--license-id", required=True)
    result.add_argument("--source-url")
    result.add_argument("--idempotency-key", required=True)
    result.add_argument("--allow-remote", action="store_true")
    return result


if __name__ == "__main__":
    print(stage(parser().parse_args()))
