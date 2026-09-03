#!/usr/bin/env python3
from pathlib import Path

PLAN = Path("/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md")
text = PLAN.read_text(encoding="utf-8")
orig = text

u1_old = "(upstream already exposes it; not a `wrong_binary` discriminator)"
u1_new = (
    "(added by the fork in Phase 1 alongside `--cache-dir`/`--quota-dir`; "
    "not a `wrong_binary` discriminator — dir flags + fingerprint versions already reject upstream 0.9.0)"
)
c = text.count(u1_old)
if c != 2:
    raise SystemExit(f"U1: expected 2 hits, got {c}")
text = text.replace(u1_old, u1_new)

u2a_old = (
    "Fork **may** read `SB_DR_FLEET` and `SB_DR_FLEET_SLOTS` env "
    "(fleet TTL warning + **admission N**). Quiesce/clear is **always ceiling-10** "
    "(`0.lock`…`9.lock`), never `{N-1}`."
)
u2a_new = (
    "Fork **may** read `SB_DR_FLEET` for the fleet TTL warning only. "
    "`SB_DR_FLEET_SLOTS` is **orchestrator-only** (`search_orchestrator.py` admission N); "
    "the fork does **not** read it. Quiesce/clear is **always ceiling-10** "
    "(`0.lock`…`9.lock`), never `{N-1}`."
)
if text.count(u2a_old) != 1:
    raise SystemExit(f"U2 §6.13: expected 1 hit, got {text.count(u2a_old)}")
text = text.replace(u2a_old, u2a_new, 1)

u2b_old = (
    "Fork may read `SB_DR_FLEET_SLOTS` for **admission N** and `SB_DR_FLEET` TTL warning only."
)
u2b_new = (
    "Fork may read `SB_DR_FLEET` for the TTL warning only. "
    "`SB_DR_FLEET_SLOTS` is orchestrator-only (admission N); the fork does not read it."
)
if text.count(u2b_old) != 1:
    raise SystemExit(f"U2 L84: expected 1 hit, got {text.count(u2b_old)}")
text = text.replace(u2b_old, u2b_new, 1)

ledger_old = (
    "`--allow-private` is a `stable_hash` boolean (human writer must not poison fleet `q3_` hits)."
)
ledger_new = (
    ledger_old
    + " `--cache-ttl` is a Phase 1 fork ADD (not upstream-exposed); "
    "`SB_DR_FLEET_SLOTS` is orchestrator-only (fork does not read it)."
)
if text.count(ledger_old) != 1:
    raise SystemExit("L85 ACCEPT bullet missing")
text = text.replace(ledger_old, ledger_new, 1)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
