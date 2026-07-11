#!/usr/bin/env bash
# Rename plugins/silver-bullet/commands/*.md stubs so filename stem matches name: frontmatter.
# Cursor agent TUI and Codex derive slash routes from the stub filename, not only YAML name.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMANDS_DIR="${REPO_ROOT}/plugins/silver-bullet/commands"

python3 - "$COMMANDS_DIR" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

commands_dir = Path(sys.argv[1])


def parse_frontmatter(path: Path) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    meta: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if match:
            meta[match.group(1)] = match.group(2).strip().strip('"').strip("'")
    return meta


renamed = 0
removed = 0
for path in sorted(commands_dir.glob("*.md")):
    name = parse_frontmatter(path).get("name", "").strip()
    if not name:
        print(f"WARN: skip {path.name} — missing name in frontmatter", file=sys.stderr)
        continue
    target = commands_dir / f"{name}.md"
    if path.resolve() == target.resolve():
        continue
    if target.exists() and target.resolve() != path.resolve():
        target.unlink()
        removed += 1
    path.rename(target)
    renamed += 1
    print(f"renamed {path.name} -> {target.name}")

print(f"rename-command-stubs: {renamed} renamed, {removed} stale targets removed")
PY
