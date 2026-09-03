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
    "Fork may read `SB_DR_FLEET_SLOTS` (same porous env as `SB_DR_FLEET`); still must not read SB catalogs.",
    "Fork may read `SB_DR_FLEET` for the TTL warning only (**superseded** for slots by item 10 M-2 / I-18: `SB_DR_FLEET_SLOTS` is orchestrator-only; the fork does **not** read it). Still must not read SB catalogs.",
    "Y1",
)

one(
    "§4.4 doctor risk is shared fleet quota (not `$HOME/.cache/search`); `--max-chars` emit/truncation test in §6.12; doctor.rs behavior tests in §6.12.",
    "§4.4 doctor risk is shared fleet quota (not `$HOME/.cache/search`); `--max-chars` emit/truncation test in §6.12; doctor.rs behavior tests in §6.12. §1.2 H1 `SB_DR_FLEET_SLOTS` fork-read is superseded (I-18); fork does not read it.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
