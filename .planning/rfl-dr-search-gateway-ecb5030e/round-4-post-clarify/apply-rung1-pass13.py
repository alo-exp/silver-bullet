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
    "Pre-run Serper remaining `< 50` alerts; `serper_unavailable` marks Method B gaps.",
    "X-union dedup test: two/three X-leg envelopes sharing a tweet id or canonical `x.com`/`twitter.com` status URL (plus an xAI hit carrying the id) emit one row; results without id/URL stay undeduped and recorded. "
    "Pre-run Serper remaining `< 50` alerts; `serper_unavailable` marks Method B gaps.",
    "AB1",
)

one(
    "`--cache-dir` **and** `--quota-dir` appear in `--help`",
    "`--cache-dir`, `--quota-dir`, **and** `--cache-ttl` appear in `--help`",
    "AB2",
)

one(
    "reddit OAuth: shared token file + flock; refresh path; 401 retries once then Auth",
    "reddit OAuth: shared token file + flock; refresh path; 401 retries once then Auth; N concurrent acquires with remaining TTL ≥ 60s perform **zero** token-endpoint calls (re-read under lock; no stampede)",
    "AB3",
)

one(
    "plus leftover `q2_*` plus `last.json` plus `fleet-slots.lock/`",
    "plus leftover `q2_*` plus any future `qN_*` prefix (seed a `q4_*` fixture and assert removal) plus `last.json` plus `fleet-slots.lock/`",
    "AB4",
)

one(
    "§6.12 serper/x acquire tests; human-run `cache_ttl_default_300s` negative test.",
    "§6.12 serper/x acquire tests; human-run `cache_ttl_default_300s` negative test. §3 X-union dedup test; clap `--cache-ttl` in `--help`; reddit no-stampede test; `clear()` removes future `qN_*`.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
