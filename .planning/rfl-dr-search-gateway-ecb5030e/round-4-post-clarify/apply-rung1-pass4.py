#!/usr/bin/env python3
from pathlib import Path

PLAN = Path("/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md")
text = PLAN.read_text(encoding="utf-8")
orig = text

repls = [
    (
        "**`--max-chars` / `--allow-private` (M-4):** **Not** `stable_hash` fields. `--max-chars` truncation at **emit** (after cache store/load); stored body is untruncated. `--allow-private`: fleet **never** passes it (default false).",
        "**`--max-chars` / `--allow-private` (M-4):** `--max-chars` is **not** a `stable_hash` field (truncation at **emit**; stored body untruncated). **`--allow-private` IS a `stable_hash` field** (boolean; default false) — **supersedes** the 2026-08-18 “not in hash” clause for this flag only. Reason: a human `--allow-private --cache-dir \"$SEARCH_CACHE_DIR\"` writer must not satisfy a later fleet reader (no `--allow-private`) via a shared `q3_` hit. Distinct from `last.json` clobber. Fleet always false so fleet-to-fleet hits unchanged.",
    ),
    (
        "IDN Discourse is a known limit; Phase 6 metrics = usage + run_manifest (no required latency export).",
        "IDN Discourse is a known limit; Phase 6 metrics = usage + run_manifest (no required latency export); `--allow-private` is a `stable_hash` boolean (human writer must not poison fleet `q3_` hits).",
    ),
    (
        "fingerprint that includes providers+domains+filters (**not** `count`, **not** TTL;",
        "fingerprint that includes providers+domains+filters + `--allow-private` boolean (**not** `count`, **not** TTL, **not** `--max-chars`;",
    ),
    (
        "**Do not** put `--max-chars` or `--allow-private` in the hash (missing High+ item 10 M-4): `--max-chars` truncation is applied at **emit** (after cache store/load), not before `CachedEntry` store — stored body is untruncated; a smaller `--max-chars` reader truncates locally. `--allow-private`: fleet **never** passes it (default false).",
        "**Do not** put `--max-chars` in the hash (missing High+ item 10 M-4): truncation is applied at **emit** (after cache store/load), not before `CachedEntry` store — stored body is untruncated; a smaller `--max-chars` reader truncates locally. **`--allow-private` IS in the hash** (boolean field; default false; round-4 pass 4 S1): a human `--allow-private` write into the fleet `SEARCH_CACHE_DIR` must produce a **different** `q3_` than a fleet reader (default false) so private-network results cannot leak on a cache hit. Distinct from I-6 (`last.json` write clobber). Fleet never passes `--allow-private`, so fleet-to-fleet fingerprints stay identical.",
    ),
    (
        "(fingerprint identical; shorter TTL must miss a longer-TTL-aged entry);",
        "(fingerprint identical; shorter TTL must miss a longer-TTL-aged entry); `--allow-private` true vs default false are **different** `q3_` names (human `--allow-private --cache-dir` writer must not satisfy a fleet reader);",
    ),
    (
        "`q3_` fingerprint includes `-p`+canonicalized domains+filters (**not** count, **not** TTL;",
        "`q3_` fingerprint includes `-p`+canonicalized domains+filters+`--allow-private` (**not** count, **not** TTL, **not** `--max-chars`;",
    ),
]

for i, (old, new) in enumerate(repls, 1):
    c = text.count(old)
    if c != 1:
        raise SystemExit(f"repl {i}: expected 1 hit, got {c}")
    text = text.replace(old, new, 1)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
