#!/usr/bin/env python3
import hashlib
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
    "relax the argv lock. - **Phase 1 `CachedEntry`:**",
    "relax the argv lock.\n- **Phase 1 `CachedEntry`:**",
    "AG1-L460",
)

one(
    "tokens = 0.0`). - **Malformed/truncated `{id}.json`:**",
    "tokens = 0.0`).\n- **Malformed/truncated `{id}.json`:**",
    "AG1-L470",
)

one(
    "§4.1/§5/§8.1/§8.4 `clear()` delete-set rosters include future `qN_*`.",
    "§4.1/§5/§8.1/§8.4 `clear()` delete-set rosters include future `qN_*`. §6.3/§6.4 markdown sub-bullets (`Phase 1 CachedEntry`; malformed `{id}.json`) start on their own lines.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
print(f"sha256 {digest}")
