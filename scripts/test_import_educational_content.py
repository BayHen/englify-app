import json

import pytest

from scripts.import_educational_content import (
    load_records,
    normalized_hash,
    validate_vocabulary,
)


def sample():
    return {"external_id": "hello-a1", "term": "hello", "translation": "xin chào", "part_of_speech": "interjection",
            "cefr_level": "A1", "topic": "greetings", "example": "Hello, Mai.", "example_vi": "Xin chào Mai.",
            "source_name": "Englify Quest editorial", "license_id": "project-owned"}


def test_json_and_csv_validation(tmp_path):
    value = sample()
    path = tmp_path / "content.json"
    path.write_text(json.dumps([value]), encoding="utf-8")
    assert load_records(path) == [value]
    assert validate_vocabulary(value) == []


def test_rejects_invalid_level_and_stable_hash():
    value = {**sample(), "cefr_level": "A0"}
    assert "cefr_level must be A1-C2" in validate_vocabulary(value)
    assert normalized_hash(sample()) == normalized_hash(dict(reversed(list(sample().items()))))


def test_rejects_non_array_json(tmp_path):
    path = tmp_path / "content.json"
    path.write_text("{}", encoding="utf-8")
    with pytest.raises(ValueError, match="array"):
        load_records(path)
