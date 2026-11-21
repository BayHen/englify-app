#!/usr/bin/env python3
"""Heuristic static audit for mobile UI source files.

This script identifies code that deserves manual UI/UX or accessibility review.
It does not prove a defect and cannot certify accessibility or usability.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable


EXTENSIONS = {
    ".swift", ".m", ".mm", ".kt", ".kts", ".java", ".xml",
    ".dart", ".tsx", ".ts", ".jsx", ".js", ".cs", ".xaml",
}

SKIP_DIRS = {
    ".git", ".gradle", ".idea", ".dart_tool", ".build", "build",
    "dist", "node_modules", "Pods", "DerivedData", ".next", "vendor",
}


@dataclass
class Finding:
    rule: str
    severity: str
    path: str
    line: int
    message: str
    excerpt: str


@dataclass(frozen=True)
class Rule:
    name: str
    severity: str
    pattern: re.Pattern[str]
    message: str
    extensions: frozenset[str] | None = None


RULES = [
    Rule(
        "android-orientation-lock",
        "P1",
        re.compile(r'android:screenOrientation\s*=\s*["\'](?:portrait|landscape|sensorPortrait|sensorLandscape)["\']'),
        "Fixed Android orientation can break adaptive, tablet, foldable, and accessibility use. Confirm it is essential.",
        frozenset({".xml"}),
    ),
    Rule(
        "gesture-only-candidate",
        "P1",
        re.compile(r'\b(?:onLongPress|onDoubleTap|onHorizontalDrag|onVerticalDrag|onPanUpdate|detectDragGestures|swipeActions)\b'),
        "Gesture handling found. Verify a visible and assistive-technology alternative exists for every core action.",
    ),
    Rule(
        "hardcoded-text-size",
        "P2",
        re.compile(r'(?:fontSize\s*[:=]|\.font\(\.system\(size:|TextUnit\.(?:Sp|sp)|setTextSize\s*\()[^\n]{0,40}\b\d+(?:\.\d+)?'),
        "Hard-coded text sizing found. Verify semantic styles, scaling, localization, and no fixed-height clipping.",
    ),
    Rule(
        "hardcoded-color",
        "P2",
        re.compile(r'(?:#[0-9A-Fa-f]{6,8}\b|Color\(0x[0-9A-Fa-f]{6,8}\)|UIColor\(red:|Color\.(?:Red|Blue|Green|Gray)\b)'),
        "Raw color found. Prefer semantic tokens or dynamic platform colors and verify contrast in all appearances.",
    ),
    Rule(
        "empty-content-description",
        "P1",
        re.compile(r'(?:contentDescription\s*=\s*(?:null|""|String\.Empty)|android:contentDescription\s*=\s*["\']\s*["\'])'),
        "Empty accessibility description found. Confirm the element is decorative; otherwise provide a meaningful accessible name.",
        frozenset({".kt", ".kts", ".java", ".xml"}),
    ),
    Rule(
        "flutter-icon-button-without-tooltip-candidate",
        "P2",
        re.compile(r'\bIconButton\s*\('),
        "Flutter IconButton found. Verify tooltip/semantic label, target size, enabled/disabled state, and focus behavior.",
        frozenset({".dart"}),
    ),
    Rule(
        "react-native-touchable-candidate",
        "P2",
        re.compile(r'<(?:TouchableOpacity|TouchableHighlight|Pressable)\b'),
        "React Native press target found. Verify accessibilityRole, accessible name/state, target size, and disabled/busy behavior.",
        frozenset({".tsx", ".jsx", ".ts", ".js"}),
    ),
    Rule(
        "custom-back-handling",
        "P1",
        re.compile(r'\b(?:onBackPressed\s*\(|KEYCODE_BACK|WillPopScope\b|BackHandler\b)'),
        "Custom back handling found. Verify current Android predictive-back/system-back behavior and modal dismissal semantics.",
        frozenset({".kt", ".kts", ".java", ".dart"}),
    ),
    Rule(
        "fixed-height-text-container-candidate",
        "P2",
        re.compile(r'(?:height\s*[:=]\s*(?:const\s+)?\d+|\.frame\s*\(\s*height\s*:\s*\d+)'),
        "Fixed height found. If the region contains text or controls, verify large text, localization, and keyboard/display scaling.",
    ),
    Rule(
        "todo-ui-state",
        "P2",
        re.compile(r'\b(?:TODO|FIXME)\b.*\b(?:loading|empty|error|offline|accessib|a11y|permission|responsive|adaptive|tablet)\b', re.I),
        "Unfinished UI state or accessibility work is explicitly noted.",
    ),
]


def iter_files(root: Path, max_files: int) -> Iterable[Path]:
    count = 0
    for current, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.startswith(".")]
        for filename in files:
            path = Path(current) / filename
            if path.suffix.lower() not in EXTENSIONS:
                continue
            yield path
            count += 1
            if count >= max_files:
                return


def audit_file(path: Path, root: Path) -> list[Finding]:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return [Finding("read-error", "P3", str(path), 0, str(exc), "")]

    findings: list[Finding] = []
    suffix = path.suffix.lower()
    for line_number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith(("//", "#", "<!--", "*")):
            continue
        for rule in RULES:
            if rule.extensions and suffix not in rule.extensions:
                continue
            if rule.pattern.search(line):
                findings.append(Finding(
                    rule=rule.name,
                    severity=rule.severity,
                    path=str(path.relative_to(root)),
                    line=line_number,
                    message=rule.message,
                    excerpt=stripped[:220],
                ))
    return findings


def render_text(findings: list[Finding], scanned: int) -> str:
    lines = [
        "Mobile UI heuristic audit",
        f"Files scanned: {scanned}",
        f"Review candidates: {len(findings)}",
        "Note: findings are heuristic and require manual/device verification.",
        "",
    ]
    order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
    for item in sorted(findings, key=lambda f: (order.get(f.severity, 9), f.path, f.line, f.rule)):
        lines.extend([
            f"[{item.severity}] {item.rule} — {item.path}:{item.line}",
            f"  {item.message}",
            f"  {item.excerpt}",
            "",
        ])
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", default=".", help="Project directory to scan")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--output", help="Write output to a file instead of stdout")
    parser.add_argument("--max-files", type=int, default=5000, help="Maximum source files to scan")
    args = parser.parse_args()

    root = Path(args.path).expanduser().resolve()
    if not root.is_dir():
        print(f"error: not a directory: {root}", file=sys.stderr)
        return 2
    if args.max_files < 1:
        print("error: --max-files must be positive", file=sys.stderr)
        return 2

    findings: list[Finding] = []
    scanned = 0
    for path in iter_files(root, args.max_files):
        scanned += 1
        findings.extend(audit_file(path, root))

    if args.format == "json":
        payload = {
            "root": str(root),
            "files_scanned": scanned,
            "finding_count": len(findings),
            "disclaimer": "Heuristic candidates only; verify manually and on devices.",
            "findings": [asdict(item) for item in findings],
        }
        output = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    else:
        output = render_text(findings, scanned)

    if args.output:
        out = Path(args.output).expanduser()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(output, encoding="utf-8")
    else:
        sys.stdout.write(output)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
