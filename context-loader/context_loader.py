#!/usr/bin/env python3
"""Keyword-triggered context injection for Claude Code UserPromptSubmit hooks."""

from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

MAX_LINES = 3_000
MAX_BYTES = 80 * 1024
MAX_EXCERPT_LINES = 40


def _debug_enabled() -> bool:
    return os.environ.get("OPERATOR_KIT_DEBUG", "").lower() in {"1", "true", "yes", "on"}


def _debug(message: str) -> None:
    if not _debug_enabled():
        return
    try:
        log_dir = Path(
            os.environ.get(
                "OPERATOR_KIT_LOG_DIR",
                str(Path.home() / ".claude" / "logs" / "operator-kit"),
            )
        ).expanduser()
        log_dir.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
        with (log_dir / "context-loader.log").open("a", encoding="utf-8") as handle:
            handle.write(f"{stamp} {message}\n")
    except OSError:
        pass


def _normalize_path(raw: str) -> Path:
    value = os.path.expandvars(os.path.expanduser(raw))
    if os.name == "nt":
        match = re.match(r"^/([a-zA-Z])/(.*)$", value)
        if match:
            value = f"{match.group(1).upper()}:/{match.group(2)}"
    return Path(value).resolve(strict=False)


def _project_root(payload: Dict[str, Any]) -> Path:
    raw = (
        os.environ.get("PROJECT_ROOT")
        or payload.get("cwd")
        or os.environ.get("CLAUDE_PROJECT_DIR")
        or os.getcwd()
    )
    return _normalize_path(str(raw))


def _keyword_file(root: Path) -> Optional[Path]:
    explicit = os.environ.get("OPERATOR_KIT_KEYWORDS")
    candidates = [
        _normalize_path(explicit) if explicit else None,
        root / ".claude" / "operator-kit-keywords.json",
        root / "context-loader" / "project-keywords.json",
        Path.home() / ".claude" / "operator-kit-keywords.json",
        Path.home() / ".claude" / "hooks" / "operator-kit-keywords.json",
    ]
    return next((path.resolve(strict=False) for path in candidates if path and path.is_file()), None)


def _load_payload() -> Optional[Dict[str, Any]]:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError) as exc:
        _debug(f"ignored invalid hook payload: {exc}")
        return None
    if not isinstance(payload, dict) or not isinstance(payload.get("prompt"), str):
        _debug("ignored hook payload without a string prompt")
        return None
    return payload


def _load_keywords(path: Path) -> Optional[Dict[str, Any]]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        _debug(f"ignored invalid keywords file {path}: {exc}")
        return None
    if not isinstance(data, dict):
        _debug(f"ignored non-object keywords file {path}")
        return None
    return data


def _matches(prompt: str, keyword: str) -> bool:
    keyword = keyword.strip()
    if not keyword:
        return False
    pattern = rf"(?<!\w){re.escape(keyword)}(?!\w)"
    return re.search(pattern, prompt, flags=re.IGNORECASE) is not None


def _matched_entries(prompt: str, data: Dict[str, Any]) -> List[Tuple[str, Dict[str, Any], str]]:
    matches: List[Tuple[str, Dict[str, Any], str]] = []
    for key, value in data.items():
        if key.startswith("_") or not isinstance(value, dict):
            continue
        keywords = value.get("keywords", [])
        if not isinstance(keywords, list):
            continue
        matched = next(
            (keyword for keyword in keywords if isinstance(keyword, str) and _matches(prompt, keyword)),
            None,
        )
        if matched:
            matches.append((key, value, matched))
    return matches


def _safe_project_path(root: Path, relative: Any) -> Tuple[Optional[Path], str]:
    if not isinstance(relative, str) or not relative.strip():
        return None, "(not configured)"
    raw = relative.strip()
    candidate_input = Path(raw)
    if candidate_input.is_absolute() or re.match(r"^[a-zA-Z]:[\\/]", raw):
        return None, f"{raw} (rejected: absolute path)"
    candidate = (root / candidate_input).resolve(strict=False)
    try:
        candidate.relative_to(root)
    except ValueError:
        return None, f"{raw} (rejected: outside project root)"
    return candidate, raw


def _excerpt(path: Path) -> List[str]:
    lines: List[str] = []
    try:
        with path.open(encoding="utf-8", errors="replace") as handle:
            for _ in range(MAX_EXCERPT_LINES):
                line = handle.readline()
                if line == "":
                    break
                lines.append(line.rstrip("\n"))
    except OSError as exc:
        return [f"(could not read file: {exc})"]
    return lines


def _entry_lines(root: Path, key: str, entry: Dict[str, Any]) -> Tuple[List[str], List[str]]:
    safe_key = re.sub(r"[^a-zA-Z0-9_.-]+", "-", key).strip("-")[:80] or "topic"
    lines = [
        f"<operator-kit-context topic=\"{safe_key}\">",
        f"Project root: {root}",
        "Relevant project paths:",
    ]
    surfaced: List[str] = []

    configured_paths = entry.get("files", [])
    if not isinstance(configured_paths, list):
        configured_paths = []

    if not configured_paths:
        lines.append("- (none configured)")

    for relative in configured_paths:
        path, display = _safe_project_path(root, relative)
        if path is None:
            lines.append(f"- {display}")
        elif path.is_file():
            lines.append(f"- {display}")
            surfaced.append(display)
        elif path.is_dir():
            lines.append(f"- {display} (directory)")
            surfaced.append(display)
        else:
            lines.append(f"- {display} (not found)")

    priority_path, priority_display = _safe_project_path(root, entry.get("priority_file", ""))
    lines.extend(["", f"Priority file excerpt: {priority_display}", "--- excerpt start ---"])
    if priority_path is None:
        lines.append(priority_display)
    elif priority_path.is_file():
        lines.extend(_excerpt(priority_path))
        if priority_display not in surfaced:
            surfaced.append(priority_display)
    else:
        lines.append(f"(file not found: {priority_display})")
    lines.extend(
        [
            "--- excerpt end ---",
            "The excerpt is orientation only. Read the relevant listed paths before making claims or changes.",
            "</operator-kit-context>",
            "",
        ]
    )
    return lines, surfaced


def _bounded_text(lines: Iterable[str]) -> Tuple[str, bool]:
    output: List[str] = []
    total_bytes = 0
    total_lines = 0
    truncated = False

    for line in lines:
        if total_lines >= MAX_LINES:
            truncated = True
            break
        rendered = f"{line}\n"
        encoded = rendered.encode("utf-8")
        remaining = MAX_BYTES - total_bytes
        if remaining <= 0:
            truncated = True
            break
        if len(encoded) > remaining:
            output.append(encoded[:remaining].decode("utf-8", errors="ignore"))
            total_bytes = MAX_BYTES
            total_lines += 1
            truncated = True
            break
        output.append(rendered)
        total_bytes += len(encoded)
        total_lines += 1

    return "".join(output), truncated


def main() -> int:
    payload = _load_payload()
    if payload is None:
        return 0

    root = _project_root(payload)
    keywords_path = _keyword_file(root)
    if keywords_path is None:
        return 0

    data = _load_keywords(keywords_path)
    if data is None:
        return 0

    matches = _matched_entries(payload["prompt"], data)
    if not matches:
        return 0

    all_lines: List[str] = []
    surfaced: List[str] = []
    matched_keywords: List[str] = []
    for key, entry, keyword in matches:
        entry_lines, entry_surfaced = _entry_lines(root, key, entry)
        all_lines.extend(entry_lines)
        surfaced.extend(entry_surfaced)
        matched_keywords.append(keyword)

    text, truncated = _bounded_text(all_lines)
    sys.stdout.write(text)
    _debug(
        "fired "
        f"root={root} keywords_file={keywords_path} "
        f"keywords={matched_keywords!r} surfaced={surfaced!r} truncated={truncated}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # Hooks should fail open, but debug mode preserves evidence.
        _debug(f"unexpected error: {type(exc).__name__}: {exc}")
        raise SystemExit(0)
