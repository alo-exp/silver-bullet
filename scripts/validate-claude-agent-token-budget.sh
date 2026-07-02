#!/usr/bin/env bash
# Fail when Claude plugin agent description tokens exceed the host budget.
#
# Claude warns when combined plugin agent descriptions exceed ~15k tokens.
# We budget frontmatter description fields under agents/claude only (target 14k).
#
# Usage:
#   scripts/validate-claude-agent-token-budget.sh [--repo-root PATH] [--max-tokens N]

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
max_tokens=14000

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="${2:-}"
      shift 2
      ;;
    --max-tokens)
      max_tokens="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '1,12p' "$0"
      exit 0
      ;;
    *)
      printf 'validate-claude-agent-token-budget: unknown argument: %s\n' >&2
      exit 2
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  printf 'validate-claude-agent-token-budget: python3 required\n' >&2
  exit 1
fi

python3 - "$repo_root" "$max_tokens" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
max_tokens = int(sys.argv[2])
claude_root = repo_root / "agents" / "claude"

if not claude_root.is_dir():
    print(f"validate-claude-agent-token-budget: missing {claude_root}")
    sys.exit(1)


def parse_frontmatter(path: Path) -> dict[str, str]:
    lines = path.read_text(errors="ignore").splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    meta: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if not match:
            continue
        key, value = match.group(1), match.group(2).strip()
        if value in {">", "|", ">-", "|-" }:
            continue
        if value.startswith('"') and value.endswith('"'):
            value = value[1:-1]
        meta[key] = value
    return meta


def estimate_tokens(text: str) -> float:
    return len(text) / 4.0


total = 0.0
count = 0
library = 0.0
library_count = 0
top: list[tuple[float, str]] = []

for skill in sorted(claude_root.glob("*/SKILL.md")):
    meta = parse_frontmatter(skill)
    desc = meta.get("description", "").strip()
    if not desc:
        continue
    tokens = estimate_tokens(desc)
    total += tokens
    count += 1
    top.append((tokens, skill.parent.name))
    if meta.get("user-invocable", "true").strip().lower() != "false":
        library += tokens
        library_count += 1

top.sort(reverse=True)
print(f"Claude agent descriptions: {count} skills, ~{total:.0f} tokens (all)")
print(f"User-invocable library subset: {library_count} skills, ~{library:.0f} tokens")
print(f"Budget: {max_tokens} tokens (buffer under Claude 15k limit)")
if top[:5]:
    print("Top 5 by description tokens:")
    for tokens, name in top[:5]:
        print(f"  ~{tokens:.0f}  {name}")

if total > max_tokens:
    print(f"FAIL: total description tokens ~{total:.0f} exceed budget {max_tokens}")
    sys.exit(1)

print("PASS: Claude agent description token budget")
PY
