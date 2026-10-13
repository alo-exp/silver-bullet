#!/usr/bin/env python3
from pathlib import Path

PLAN = Path("/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md")
text = PLAN.read_text(encoding="utf-8")
orig = text


def one(old, new, label):
    global text
    c = text.count(old)
    if c != 1:
        raise SystemExit(f"{label}: expected 1 hit, got {c}")
    text = text.replace(old, new, 1)


one(
    "deletes `q3_*` json+inflight, leftover `q2_*`, `last.json`,",
    "deletes `q3_*` json+inflight, leftover `q2_*`, any future `qN_*` prefix (`q4_*` …), `last.json`,",
    "AF1-L330",
)

one(
    "deletes `q3_*.json` **and** `q3_*.inflight`, leftover `q2_*`, `last.json`,",
    "deletes `q3_*.json` **and** `q3_*.inflight`, leftover `q2_*`, any future `qN_*` prefix (`q4_*` …), `last.json`,",
    "AF1-L351",
)

one(
    "clear()` all `q3_*` (json + inflight) + leftover `q2_` + `last.json`",
    "clear()` all `q3_*` (json + inflight) + leftover `q2_` + any future `qN_*` prefix (`q4_*` …) + `last.json`",
    "AF1-L736",
)

one(
    "clear()` deletes `q3_*` + leftover `q2_*` + `last.json`",
    "clear()` deletes `q3_*` + leftover `q2_*` + any future `qN_*` prefix (`q4_*` …) + `last.json`",
    "AF1-L773",
)

one(
    "clear()` `q3_` + leftover `q2_*` + `last.json` + orphaned `last.json.tmp.*` + slot-file contents",
    "clear()` `q3_` + leftover `q2_*` + any future `qN_*` (`q4_*` fixture assert removal) + `last.json` + orphaned `last.json.tmp.*` + slot-file contents",
    "AF1-L781",
)

one(
    "§4.1/§5/§8.1/§8.4 `clear()` preserve rosters include query-cache `.gitignore`.",
    "§4.1/§5/§8.1/§8.4 `clear()` preserve rosters include query-cache `.gitignore`. §4.1/§5/§8.1/§8.4 `clear()` delete-set rosters include future `qN_*`.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
