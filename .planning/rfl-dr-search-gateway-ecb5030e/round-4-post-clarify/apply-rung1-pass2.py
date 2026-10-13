#!/usr/bin/env python3
from pathlib import Path

PLAN = Path("/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md")
text = PLAN.read_text(encoding="utf-8")
orig = text

# R1: annotate historical ledger X must_search:false (not L54 supersession clause, not Facebook)
old1 = "X stays `must_search: false`"
new1 = "X stays `must_search: false` (superseded 2026-08-31; X is `must_search: true` per §1.2 lock)"
if old1 not in text:
    raise SystemExit("missing R1 stays")
text = text.replace(old1, new1)

old2 = ", X `must_search: false`"
new2 = ", X `must_search: false` (superseded 2026-08-31; X is `must_search: true` per §1.2 lock)"
c = text.count(old2)
if c < 8:
    raise SystemExit(f"expected many R1 commas, got {c}")
text = text.replace(old2, new2)

# R2: official-JSON site: fallbacks are best-effort degrade
old3 = "The consent UI must surface that dependency; consenting a `site:` channel without a Method B key is a recorded `providers_missing` gap, not a silent skip."
new3 = (
    old3
    + " Official-JSON channels’ Method B `site:` fallbacks (SE/GitHub/GitLab/YouTube/Reddit/PH) are **best-effort degrade**, not extra per-channel consent gates; declining Serper (and Brave) makes those fallbacks a recorded gap only."
)
if old3 not in text:
    raise SystemExit("missing R2 anchor")
text = text.replace(old3, new3, 1)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
