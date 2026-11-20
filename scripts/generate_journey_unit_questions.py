"""Generate reviewable Gemini drafts for the Journey Unit question bank."""

import argparse
import json
import os
from random import Random
from concurrent.futures import ThreadPoolExecutor
from time import sleep
from urllib.error import HTTPError, URLError
from pathlib import Path
from urllib.request import Request, urlopen

from build_journey_v27_curriculum import LEVELS


def validate(data):
    if not isinstance(data, list) or len(data) != 15:
        raise ValueError("Expected 3 questions per lesson and 6 for the checkpoint")
    prompts = set()
    for item in data:
        prompt = item["prompt"].strip()
        options = item["choices"]
        correct = item["correct_index"]
        if not prompt or prompt.casefold() in prompts or not item["explanation_vi"].strip():
            raise ValueError("Missing or duplicate prompt or missing explanation")
        prompts.add(prompt.casefold())
        if len(options) != 3 or len({option.strip().casefold() for option in options}) != 3:
            raise ValueError("Expected three distinct choices")
        if type(correct) is not int or not 0 <= correct < 3:
            raise ValueError("Invalid correct_index")
        if any(not option.strip() or option.lower().startswith(("unrelated", "unsupported form")) for option in options):
            raise ValueError("Empty or placeholder choice")
    return data


def vary_answer_positions(data, level, unit_number):
    random = Random(f"journey:{level}:{unit_number}")
    positions = [0, 1, 2] * 5
    random.shuffle(positions)
    for item, position in zip(data, positions, strict=True):
        correct = item["choices"].pop(item["correct_index"])
        random.shuffle(item["choices"])
        item["choices"].insert(position, correct)
        item["correct_index"] = position
    return data


def generate(key, model, level, target, unit):
    title, topic, vocabulary, grammar = unit
    prompt = (
        f"Write 15 independent multiple-choice questions for Journey Level {level} "
        f"({target}), unit {title}. Topic: {topic}. Vocabulary: {vocabulary}. Grammar: {grammar}. "
        "In order: 3 exploring vocabulary in context, 3 applying grammar, "
        "3 completing realistic exchanges, and 6 fresh checkpoint questions. "
        "Give enough context to make exactly one of three choices defensible. "
        "Make distractors plausible mistakes of similar length and form. Never use placeholder choices, "
        "negated clones, or objective trivia. Vary the correct position. Return a JSON array "
        "with fields prompt, choices (array of three strings), correct_index (zero-based integer), "
        "and explanation_vi (one concise Vietnamese sentence explaining why the key fits)."
    )
    request = Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        data=json.dumps({
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"responseMimeType": "application/json"},
        }).encode(),
        headers={"x-goog-api-key": key, "Content-Type": "application/json"},
    )
    with urlopen(request, timeout=45) as response:
        result = json.load(response)
    return validate(json.loads(result["candidates"][0]["content"]["parts"][0]["text"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--level", type=int, choices=range(1, 11), required=True)
    parser.add_argument("--model", required=True, help="Gemini model ID configured for your project")
    parser.add_argument("--output", type=Path, required=True, help="Directory for review-only drafts")
    parser.add_argument("--workers", type=int, choices=range(1, 5), default=1)
    args = parser.parse_args()
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        parser.error("Set GEMINI_API_KEY locally. Do not commit or paste the key.")
    _, _, target, _, units = LEVELS[args.level - 1]
    args.output.mkdir(parents=True, exist_ok=True)
    def generate_unit(entry):
        number, unit = entry
        path = args.output / f"level-{args.level:02}-unit-{number:02}.json"
        if path.exists():
            validate(json.loads(path.read_text(encoding="utf-8")))
            return
        for retry in range(4):
            try:
                data = generate(key, args.model, args.level, target, unit)
                break
            except HTTPError as error:
                if error.code not in {429, 500, 502, 503, 504} or retry == 3:
                    raise
                sleep(3 * (2 ** retry))
            except (TimeoutError, URLError, ValueError, KeyError, IndexError, TypeError):
                if retry == 3:
                    raise
                sleep(3 * (2 ** retry))
        vary_answer_positions(data, args.level, number)
        with path.open("x", encoding="utf-8") as output:
            json.dump(data, output, ensure_ascii=False, indent=2)
        print(f"Draft saved for review: {path}", flush=True)

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        jobs = [(number, pool.submit(generate_unit, (number, unit)))
                for number, unit in enumerate(units, 1)]
        failed = []
        for number, job in jobs:
            try:
                job.result()
            except (HTTPError, URLError, TimeoutError, ValueError, KeyError, IndexError, TypeError) as error:
                failed.append(number)
                print(f"Unit {number:02} failed: {type(error).__name__}", flush=True)
        if failed:
            raise SystemExit(f"Missing drafts for units: {failed}")


if __name__ == "__main__":
    main()
