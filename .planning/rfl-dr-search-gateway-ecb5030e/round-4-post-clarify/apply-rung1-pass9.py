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
    "do not acquire against the unset-flag `$HOME/.cache/search` default while a fleet uses `{SEARCH_QUOTA_DIR}`",
    "unset-flag `--quota-dir` default is `~/.config/silver-bullet/search-quota/` (same as fleet); a bare `search doctor` spends **fleet** bucket tokens. Do not invent a `$HOME/.cache/search` quota default",
    "X1",
)

one(
    "; `CachedEntry.version` missing → 1; cache-hit must **not** replay stored `bucket_fail_closed`",
    "; `CachedEntry.version` missing → 1; cache-hit must **not** replay stored `bucket_fail_closed`; `--max-chars` is **not** a fingerprint field (same query + `-p` + `-d` + two `--max-chars` values → same `q3_`; stored body untruncated; emit truncates to the reader's `--max-chars`)",
    "X2",
)

one(
    "**brave** `acquire(\"brave\", …, collector)` before HTTP (bucket exists under `--quota-dir`)",
    "**brave** `acquire(\"brave\", …, collector)` before HTTP (bucket exists under `--quota-dir`)\n"
    "- doctor: honors `--quota-dir` (does not invent a `$HOME/.cache/search` quota default); "
    "`doctor_skip_requires_domain` for discourse (no placeholder host); registries doctor ping = 4 `acquire`; "
    "`RateLimited` → `doctor_rate_limited` (not false-unhealthy); YouTube doctor ping spends 1 of 100 under `--quota-dir`",
    "X3",
)

one(
    "Human `--quota-dir` default is `~/.config/silver-bullet/search-quota/` (never ProjectDirs); `--allow-private` is last `stable_hash` field; `-d` canonicalized before `augment_query`; Reddit refresh double-checks TTL under lock; clap `-p` values drift-guard; absent reddit lock is unlockable; brave acquire test in §6.12.",
    "Human `--quota-dir` default is `~/.config/silver-bullet/search-quota/` (never ProjectDirs); `--allow-private` is last `stable_hash` field; `-d` canonicalized before `augment_query`; Reddit refresh double-checks TTL under lock; clap `-p` values drift-guard; absent reddit lock is unlockable; brave acquire test in §6.12. §4.4 doctor risk is shared fleet quota (not `$HOME/.cache/search`); `--max-chars` emit/truncation test in §6.12; doctor.rs behavior tests in §6.12.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
