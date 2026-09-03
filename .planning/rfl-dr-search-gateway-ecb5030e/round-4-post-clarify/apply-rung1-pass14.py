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
    "plus any future `qN_*` prefix (seed a `q4_*` fixture and assert removal) plus `last.json` plus `fleet-slots.lock/`",
    "plus any future `qN_*` prefix (seed a `q4_*` fixture and assert removal) plus `last.json` plus orphaned `last.json.tmp.*` (seed `last.json.tmp.{pid}.{nanos}` / `{uuid}` and assert removal) plus `fleet-slots.lock/`",
    "AC1",
)

one(
    "`cache clear` while a slot or `.inflight` is held **waits up to 30s then refuses** (`cache_clear_busy`, nonzero, no unlink) — must not admit N+1 / a second leader",
    "`cache clear` while a slot or `.inflight` is held **waits up to 30s then refuses** (`cache_clear_busy`, nonzero, no unlink) — must not admit N+1 / a second leader; held `reddit-oauth-token.lock` also drives `cache_clear_busy` / no-unlink; absent `reddit-oauth-token.lock` is unlockable (ENOENT; clear proceeds)",
    "AC2",
)

one(
    "N concurrent acquires with remaining TTL ≥ 60s perform **zero** token-endpoint calls (re-read under lock; no stampede)",
    "N concurrent acquires with remaining TTL ≥ 60s perform **zero** token-endpoint calls (re-read under lock; no stampede); forced refreshes (TTL < 60s) consume **zero** `reddit` search-bucket tokens (token-endpoint calls are not `acquire(\"reddit\", …)`)",
    "AC3",
)

one(
    "§3 X-union dedup test; clap `--cache-ttl` in `--help`; reddit no-stampede test; `clear()` removes future `qN_*`.",
    "§3 X-union dedup test; clap `--cache-ttl` in `--help`; reddit no-stampede test; `clear()` removes future `qN_*`. `clear()` also removes orphaned `last.json.tmp.*`; held reddit lock drives `cache_clear_busy`; token-endpoint does not consume the reddit search bucket.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
