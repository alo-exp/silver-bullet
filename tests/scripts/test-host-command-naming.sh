#!/usr/bin/env bash
# Fail when plugin command stubs use colon filenames or non-kebab metadata.
# Cursor plugin commands use filesystem-safe filenames and kebab-case names.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMMANDS_DIR="${REPO_ROOT}/plugins/silver-bullet/commands"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

if python3 - "$COMMANDS_DIR" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

commands_dir = Path(sys.argv[1])
bad: list[str] = []


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


for path in sorted(commands_dir.glob("*.md")):
    meta = parse_frontmatter(path)
    if ":" in path.name:
        bad.append(f"{path.name}: colon in filename is not desktop-safe")
    name = meta.get("name", "").strip()
    if not name:
        bad.append(f"{path.name}: missing name in frontmatter")
    elif name != path.stem:
        bad.append(f"{path.name}: name {name!r} must match kebab-case filename stem")
    if not meta.get("description", "").strip():
        bad.append(f"{path.name}: missing description in frontmatter")
    if ":" in name:
        bad.append(f"{path.name}: command name {name!r} must be kebab-case")

if bad:
    print("\n".join(bad))
    raise SystemExit(1)
PY
then
  pass "all command stubs use kebab-case metadata with desktop-safe filenames"
else
  fail "command stub filename/name alignment"
fi

if bash "${REPO_ROOT}/scripts/validate-host-skill-surface.sh" --repo-root "$REPO_ROOT" >/dev/null 2>&1; then
  pass "validate-host-skill-surface includes command naming"
else
  fail "validate-host-skill-surface includes command naming"
fi

bad_fixture="$(mktemp -d)"
trap 'rm -rf "$bad_fixture"' EXIT
mkdir -p "$bad_fixture/plugins/silver-bullet/commands"
cat >"$bad_fixture/plugins/silver-bullet/commands/sb:init.md" <<'EOF'
---
name: "sb:init"
---
EOF
if python3 - "$bad_fixture" <<'PY' >/dev/null 2>&1
import subprocess, sys
raise SystemExit(subprocess.call(["bash", "scripts/validate-host-skill-surface.sh", "--repo-root", sys.argv[1]]))
PY
then
  fail "colon sb:init.md filename should fail validation"
else
  pass "colon sb:init.md filename fails validation"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
