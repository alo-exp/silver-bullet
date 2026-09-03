#!/usr/bin/env python3
"""Rewrite ISSUE-LEDGER.md with a Policy G encoder-parseable table (I-1..I-42)."""
from pathlib import Path

LEDGER = Path(
    "/Users/shafqat/.cursor/worktrees/repo/ewwf/.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/ISSUE-LEDGER.md"
)
STATUS = Path(
    "/Users/shafqat/.cursor/worktrees/repo/ewwf/.planning/rfl-dr-search-gateway-ecb5030e/round-4-post-clarify/LADDER-STATUS.json"
)
SHA = "e8d4de532ef111fac2dd44ca7fce43e9345e970a3a6a320a09492e1944329c2e"

text = LEDGER.read_text(encoding="utf-8")
if "| ID | Severity | Status | Summary |" in text:
    raise SystemExit("encoder table already present")

rows = []
for line in text.splitlines():
    if not line.startswith("| I-"):
        continue
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if len(cells) < 3:
        continue
    ident, sev, summary = cells[0], cells[1], cells[2]
    rows.append((ident, sev, summary))

if len(rows) != 42:
    raise SystemExit(f"expected 42 I-* rows, got {len(rows)}")

enc = [
    "",
    f"Freeze SHA after APPLY: `{SHA}`",
    "",
    "## Issue ledger (Policy G encoder)",
    "",
    "| ID | Severity | Status | Summary |",
    "|----|----------|--------|---------|",
]
for ident, sev, summary in rows:
    enc.append(f"| {ident} | {sev} | ACCEPT | {summary} |")
enc.append("")

# Insert encoder table after Current SHA block (before IDs: line)
needle = "IDs: `I-1` … sequential. Do not reuse numbers."
if needle not in text:
    raise SystemExit("needle missing")
text = text.replace(needle, "\n".join(enc) + needle, 1)
LEDGER.write_text(text, encoding="utf-8")

import json

status = json.loads(STATUS.read_text(encoding="utf-8"))
status["freeze"] = {"sha256": SHA, "apply_sha": SHA}
status["updated_at"] = "2026-08-30T20:25:00Z"
STATUS.write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
print(f"wrote encoder table ({len(rows)} rows) + freeze SHA")
