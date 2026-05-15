#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  printf 'Usage: %s <package-root> [<package-root> ...]\n' "${0##*/}" >&2
  exit 2
fi

python3 - "$@" <<'PY'
import pathlib
import sys

LINE_REPLACEMENTS = [
    ("For each match found, present it to the user interactively using AskUserQuestion:", "For each match found, present it to the user directly:"),
    ("present it to the user interactively using AskUserQuestion:", "present it to the user directly:"),
    ("present to user using AskUserQuestion:", "present to the user directly:"),
    ("Ask using AskUserQuestion:", "Ask the user directly:"),
    ("Then use AskUserQuestion:", "Then ask the user directly:"),
    ("Use AskUserQuestion:", "Ask the user directly:"),
    ("Use AskUserQuestion", "Ask the user directly"),
    ("use AskUserQuestion:", "ask the user directly:"),
    ("use AskUserQuestion", "ask the user directly"),
    ("using AskUserQuestion:", "directly:"),
    ("using AskUserQuestion", "directly"),
    ("Only use AskUserQuestion if", "Only ask the user directly if"),
    ("No AskUserQuestion needed", "No interactive user prompt needed"),
    ("No AskUserQuestion.", "No interactive user prompt."),
]


def sanitize_text(text: str) -> str:
    updated = text
    for old, new in LINE_REPLACEMENTS:
        updated = updated.replace(old, new)
    return updated


def sanitize_root(root: pathlib.Path) -> None:
    if not root.exists():
        return

    stack = [root]
    while stack:
        current = stack.pop()
        if current.is_symlink():
            continue
        if current.is_dir():
            for child in sorted(current.iterdir(), key=lambda path: path.name, reverse=True):
                stack.append(child)
            continue
        if not current.is_file():
            continue

        try:
            text = current.read_text()
        except UnicodeDecodeError:
            continue
        except Exception:
            continue

        updated = sanitize_text(text)
        if updated != text:
            current.write_text(updated)


for root_arg in sys.argv[1:]:
    sanitize_root(pathlib.Path(root_arg))
PY
