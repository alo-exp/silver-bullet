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
    "**preserves** `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json`)",
    "**preserves** `{quota_dir}/buckets/` and `{quota_dir}/reddit-oauth-token.json` and query-cache `.gitignore` (seed `{cache_dir}/.gitignore` with `*` / `!.gitignore` and assert it remains))",
    "AD1",
)

one(
    "token-endpoint does not consume the reddit search bucket.",
    "token-endpoint does not consume the reddit search bucket. `clear()` preserves query-cache `.gitignore`.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
