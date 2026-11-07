"""Deterministic answer checks; no client-supplied score is trusted."""

import re
from typing import Any


def normalize_answer(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().casefold()).rstrip(".!? ")


def is_correct(kind: str, answer: Any, key: Any) -> bool:
    if kind == "multiple_choice":
        return isinstance(answer, str) and answer == key
    if kind in {"fill_blank", "listening", "grammar"}:
        return isinstance(answer, str) and isinstance(key, list) and any(
            normalize_answer(answer) == normalize_answer(expected)
            for expected in key if isinstance(expected, str)
        )
    if kind == "matching":
        return isinstance(answer, dict) and isinstance(key, dict) and answer == key
    return False


def passes(correct: int, total: int) -> bool:
    return total > 0 and correct * 100 >= total * 70
