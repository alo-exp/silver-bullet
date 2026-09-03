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
    "Starter **2,500/day** pack total is **ops runbook only**",
    "free **2,500 queries** / Starter 50k credits are **ops runbook only**",
    "K1",
)

one(
    "Partial keys → `partial` + `providers_missing`",
    "Partial keys → `partial_success` + `providers_missing`",
    "K2",
)

one(
    "write secrets into `search config set keys.*` (stdin `-`) and env.",
    "write secrets into `search config set keys.*` (stdin `-`).",
    "K3",
)

one(
    "(`stackexchange`, `github`, `hn`, `discourse`, `gitlab`, `youtube`, `registries`, `reddit`)",
    "(`stackexchange`, `github`, `hn`, `discourse`, `gitlab`, `youtube`, `registries`, `reddit`, `x`, `xweb`)",
    "K4",
)

one(
    "export SB_SEARCH_BIN=/usr/local/bin/search",
    "export SB_SEARCH_BIN=\"$HOME/.cargo/bin/search\"",
    "K5",
)

one(
    "X credit 0 → stamp official `-p x` missing and fall back to xAI then dedicated `site:x.com`",
    "X credit 0 → stamp official `-p x` missing and fall back to the remaining legs (`-p xweb` / xAI / dedicated `site:x.com`)",
    "K6",
)

one(
    "§6.3/§6.4 markdown sub-bullets (`Phase 1 CachedEntry`; malformed `{id}.json`) start on their own lines.",
    "§6.3/§6.4 markdown sub-bullets (`Phase 1 CachedEntry`; malformed `{id}.json`) start on their own lines. **Rung 2 Kimi ACCEPTs:** §6.4 Serper free 2,500 vs Starter 50k; §3.2 `partial_success`; §2.7 step 4 keys via `search config set` only (no env persist); probe native list includes `x`/`xweb`; cargo-install `SB_SEARCH_BIN` is `$HOME/.cargo/bin/search`; §4.4 X-credit-0 alert includes xweb.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
print(f"sha256 {digest}")
