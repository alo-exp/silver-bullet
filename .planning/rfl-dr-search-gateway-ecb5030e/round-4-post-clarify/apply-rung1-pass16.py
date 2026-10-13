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
    "preserve the directory; preserve `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`) **after** the quiesce barrier (§2.2)",
    "preserve the directory; preserve `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json` and query-cache `.gitignore`) **after** the quiesce barrier (§2.2)",
    "AE1-L330",
)

one(
    "preserve the directory; **preserve** `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`) **after** the §2.2 quiesce barrier",
    "preserve the directory; **preserve** `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json` and query-cache `.gitignore`) **after** the §2.2 quiesce barrier",
    "AE1-L351",
)

one(
    "after quiesce (`cache_clear_busy`, ceiling-10); preserve `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`**",
    "after quiesce (`cache_clear_busy`, ceiling-10); preserve `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json` and query-cache `.gitignore`**",
    "AE1-L736",
)

one(
    "after quiesce (`cache_clear_busy`); preserve `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`**",
    "after quiesce (`cache_clear_busy`); preserve `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json` and query-cache `.gitignore`**",
    "AE1-L773",
)

one(
    "`clear()` preserves query-cache `.gitignore`.",
    "`clear()` preserves query-cache `.gitignore`. §4.1/§5/§8.1/§8.4 `clear()` preserve rosters include query-cache `.gitignore`.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
