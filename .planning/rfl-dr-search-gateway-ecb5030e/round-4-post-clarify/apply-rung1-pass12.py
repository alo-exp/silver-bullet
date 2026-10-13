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
    "**x** official `search/recent` skips without bearer; **xweb** unpaid HTTP skips without guest/cookies, acquires `xweb` bucket, never execs `twitter`/`opencli`/`bird`; **brave** `acquire(\"brave\", …, collector)` before HTTP (bucket exists under `--quota-dir`)",
    "**x** official `search/recent` skips without bearer, `acquire(\"x\", …, collector)` before HTTP; **xweb** unpaid HTTP skips without guest/cookies, acquires `xweb` bucket, never execs `twitter`/`opencli`/`bird`; **brave** `acquire(\"brave\", …, collector)` before HTTP (bucket exists under `--quota-dir`); **serper** `acquire(\"serper\", …, collector)` before POST",
    "AA1",
)

one(
    "`SB_DR_FLEET=1` + unset TTL emits `cache_ttl_default_300s` in `warnings`",
    "`SB_DR_FLEET=1` + unset TTL emits `cache_ttl_default_300s` in `warnings`; a run without `SB_DR_FLEET` and with TTL unset must **not** emit `cache_ttl_default_300s`",
    "AA2",
)

one(
    "§1.2 H1 `SB_DR_FLEET_SLOTS` fork-read is superseded (I-18); fork does not read it.",
    "§1.2 H1 `SB_DR_FLEET_SLOTS` fork-read is superseded (I-18); fork does not read it. §6.12 serper/x acquire tests; human-run `cache_ttl_default_300s` negative test.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
