#!/usr/bin/env bash
# Relative-link check for the live documentation entry points.
#
# Checks every relative Markdown link (inline `[text](target)` and reference
# definitions `[id]: target`) in README.md, CONTRIBUTING.md, AGENTS.md, CLAUDE.md,
# SECURITY.md and the top-level docs/*.md files, and fails when the target file or
# directory does not exist. URLs with a scheme, anchor-only links and links inside
# code spans or fenced code blocks are ignored. Historical trees (docs/archive,
# docs/audits, research/) are out of scope: they are preserved as written.
#
# Usage: bash tests/docs/test-doc-links.sh [file ...]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

python3 - "$@" <<'PY'
import os
import re
import sys
from pathlib import Path
from urllib.parse import unquote

root = Path(os.environ["REPO_ROOT"])
if len(sys.argv) > 1:
    files = [Path(p).resolve() for p in sys.argv[1:]]
else:
    files = [root / name for name in ("README.md", "CONTRIBUTING.md", "AGENTS.md", "CLAUDE.md", "SECURITY.md")]
    files += sorted((root / "docs").glob("*.md"))

INLINE = re.compile(r"(?<!\!)\[(?:[^\[\]]|\[[^\]]*\])*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
IMAGE = re.compile(r"!\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
# Reference definitions; footnote definitions ([^note]: text) are prose, not links.
REFDEF = re.compile(r"^\s{0,3}\[(?!\^)[^\]]+\]:\s*<?(\S+?)>?(?:\s+.*)?$")
SCHEME = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:")

passes = 0
failures = []


def strip_code(text: str) -> list[tuple[int, str]]:
    """Return (line number, line) pairs with fenced blocks and code spans removed."""
    out = []
    fence = None
    for number, line in enumerate(text.splitlines(), 1):
        marker = re.match(r"^\s*(`{3,}|~{3,})", line)
        if marker:
            token = marker.group(1)[0]
            if fence is None:
                fence = token
            elif fence == token:
                fence = None
            continue
        if fence is not None:
            continue
        out.append((number, re.sub(r"`[^`]*`", "", line)))
    return out


for path in files:
    if not path.is_file():
        failures.append(f"{path.relative_to(root)}: file to check does not exist")
        continue
    rel = path.relative_to(root)
    broken = []
    checked = 0
    for number, line in strip_code(path.read_text(encoding="utf-8")):
        targets = INLINE.findall(line) + IMAGE.findall(line)
        ref = REFDEF.match(line)
        if ref:
            targets.append(ref.group(1))
        for target in targets:
            if SCHEME.match(target) or target.startswith("#") or target.startswith("//"):
                continue
            if "{{" in target or "$" in target:
                continue
            clean = unquote(target.split("#", 1)[0].split("?", 1)[0])
            if not clean:
                continue
            checked += 1
            base = root if clean.startswith("/") else path.parent
            resolved = (base / clean.lstrip("/")).resolve()
            if not resolved.exists():
                broken.append(f"line {number}: {target}")
    if broken:
        failures.append(f"{rel}: {len(broken)} broken relative link(s)")
        print(f"FAIL: {rel} has broken relative links")
        for item in broken:
            print(f"  {item}")
    else:
        passes += 1
        print(f"PASS: {rel} ({checked} relative links resolve)")

print()
print(f"Results: {passes} passed, {len(failures)} failed")
sys.exit(1 if failures else 0)
PY
