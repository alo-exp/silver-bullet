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


# W1 — human --quota-dir default matches §2.2/§6.3 (never ProjectDirs)
one(
    "Default unset for humans → same as `--cache-dir` (laptop single-dir).",
    "Default unset for humans → `~/.config/silver-bullet/search-quota/` (create 0700; **not** `$HOME/.cache/search` / ProjectDirs `\"search\"`; **not** the `--cache-dir` default). Laptop single-dir cache+quota sharing is **superseded**.",
    "W1",
)

# W2 — allow-private is last FNV field after lang
one(
    "lowercase country or `\"\"`; lowercase lang or `\"\"`.",
    "lowercase country or `\"\"`; lowercase lang or `\"\"`; `--allow-private` boolean (`true`/`false`; default false) as the **last** field.",
    "W2 field order",
)
one(
    "**`--allow-private` IS in the hash** (boolean field; default false; round-4 pass 4 S1):",
    "**`--allow-private` IS in the hash** (boolean field; default false; **last** after lang; round-4 pass 4 S1):",
    "W2 position note",
)

# W3 — canonicalize SearchOpts before augment_query
one(
    "Canonicalize `-d` / `--exclude-domain` with the same host sanitization as `discourse-<host>` **before** hashing (M1).",
    "Canonicalize `-d` / `--exclude-domain` with the same host sanitization as `discourse-<host>` onto `SearchOpts.include_domains` / `exclude_domains` **before** both `stable_hash` and `Serper::augment_query` (M1). Stored `site:` bodies must use the canonical host so mixed-case human `-d` cannot poison a fleet reader.",
    "W3",
)

# W4 — double-check TTL under lock
one(
    "Refresh when remaining TTL < 60s or file missing.",
    "Refresh when remaining TTL < 60s or file missing. Under the exclusive lock, **re-read** the shared file and skip the token endpoint if remaining TTL is still ≥ 60s (double-check; one refresh, no stampede).",
    "W4",
)

# W5 — drift-guard for command_schemas values
one(
    "`test_agent_info_json`: names include `stackexchange,github,hn,discourse,gitlab,youtube,registries,reddit,x,xweb`; also `cache_fingerprint_version: \"q3\"` and `cached_entry_version: 1`",
    "`test_agent_info_json`: names include `stackexchange,github,hn,discourse,gitlab,youtube,registries,reddit,x,xweb`; also `cache_fingerprint_version: \"q3\"` and `cached_entry_version: 1`. Hardcoded `-p` `\"values\"` in `command_schemas.search.options` **must** contain that same id set (drift-guard; fail if a `KNOWN` / `build_providers` id is missing)",
    "W5",
)

# W6 — absent reddit lock is unlockable
one(
    "wait until each `q3_*.inflight` **and** `reddit-oauth-token.lock` is unlockable (`try_lock` succeeds).",
    "wait until each `q3_*.inflight` **and** `reddit-oauth-token.lock` is unlockable (`try_lock` succeeds). Absent `reddit-oauth-token.lock` is **unlockable** (do not require materialize; ENOENT counts as unlocked).",
    "W6",
)

# W7 — brave acquire test
one(
    "**xweb** unpaid HTTP skips without guest/cookies, acquires `xweb` bucket, never execs `twitter`/`opencli`/`bird`",
    "**xweb** unpaid HTTP skips without guest/cookies, acquires `xweb` bucket, never execs `twitter`/`opencli`/`bird`; **brave** `acquire(\"brave\", …, collector)` before HTTP (bucket exists under `--quota-dir`)",
    "W7",
)

# Ledger bullet on L85
one(
    "`src/doctor.rs` is on the §8.1/§8.4 Modify checklists (bounded doctor patch).",
    "`src/doctor.rs` is on the §8.1/§8.4 Modify checklists (bounded doctor patch). Human `--quota-dir` default is `~/.config/silver-bullet/search-quota/` (never ProjectDirs); `--allow-private` is last `stable_hash` field; `-d` canonicalized before `augment_query`; Reddit refresh double-checks TTL under lock; clap `-p` values drift-guard; absent reddit lock is unlockable; brave acquire test in §6.12.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
