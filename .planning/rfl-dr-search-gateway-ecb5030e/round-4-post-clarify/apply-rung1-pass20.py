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
    "§3 X-union dedup test",
    "§4.3 X-union dedup test",
    "AH1-L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
print(f"sha256 {digest}")
