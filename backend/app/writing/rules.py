"""Deterministic checks for structured writing; paragraphs receive no score."""

import re
from dataclasses import dataclass


@dataclass(frozen=True)
class RuleFeedback:
    result: str
    suggestions: tuple[str, ...]


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip()).casefold().rstrip(".!?")


def check(kind: str, body: str, accepted: list[str]) -> RuleFeedback:
    if kind == "paragraph":
        suggestions = []
        if len(body.split()) < 20:
            suggestions.append("Add more detail or an example to develop your paragraph.")
        if body and not body[0].isupper():
            suggestions.append("Start your paragraph with a capital letter.")
        if body and body[-1] not in ".!?":
            suggestions.append("End your paragraph with punctuation.")
        return RuleFeedback("self_review", tuple(suggestions))
    if normalize(body) in {normalize(answer) for answer in accepted}:
        return RuleFeedback("matched", ("Your response matches an accepted example.",))
    suggestions = ["Compare the word order and spelling with the prompt, then try again."]
    if body and not body[0].isupper() and kind != "fill_blank":
        suggestions.append("Start the sentence with a capital letter.")
    return RuleFeedback("needs_revision", tuple(suggestions))
