#!/usr/bin/env python3
"""Apply RFL round-4 rung-1 ACCEPT pack to the canonical plan. Launcher-only."""
from pathlib import Path

PLAN = Path("/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md")
text = PLAN.read_text(encoding="utf-8")
orig = text

repls = [
    (
        "Dedup by tweet URL/id. Missing unofficial creds skip **that leg** (recorded); missing all X legs = `providers_missing` gap — not a silent skip and not a hard fail of the DR run.",
        "**Dedup (SB orchestrator, locked):** each X leg is a separate `search` process (fleet prefers one `-p` per process; fork never reads SB catalogs). Dedup lives in **`search_orchestrator.py`**, not the fork. Key: prefer tweet/status id; else canonical `x.com` / `twitter.com` status URL. xAI `-m social` hits join the same set when they carry an id or that URL; results without either stay undeduped (recorded). Missing unofficial creds skip **that leg** (recorded); missing all X legs = `providers_missing` gap — not a silent skip and not a hard fail of the DR run.",
    ),
    (
        "Union: `-p x` official v2 `GET /2/tweets/search/recent` (7 days) if bearer; `-p xweb` unpaid GraphQL/web HTTP if guest/cookies; `-p xai` with `-m social` when `XAI_API_KEY` is configured (fleet never `--x`); dedicated `-p serper` + `site:x.com` in `-q` last-resort complement (not incidental generic web). Dedup by tweet URL/id.",
        "Union: `-p x` official v2 `GET /2/tweets/search/recent` (7 days) if bearer; `-p xweb` unpaid GraphQL/web HTTP if guest/cookies; `-p xai` with `-m social` when `XAI_API_KEY` is configured (fleet never `--x`); dedicated `-p serper` + `site:x.com` in `-q` last-resort complement (not incidental generic web). **Catalog encoding (locked):** one X row; `provider` and `bucket` are **string or list** — X uses `provider: [x, xweb]` and `bucket: [x, xweb]` (plus xAI/Serper legs in the union, not extra must-search channel ids). Dedup is the SB orchestrator contract in §1.4 (not the fork).",
    ),
    (
        "`provider`, `fallback`, `site_query`, `bucket`, `sample_only`.",
        "`provider` (string or list of native `-p` ids), `fallback`, `site_query`, `bucket` (string or list of fork bucket ids; must match §6.4), `sample_only`. **X** is one catalog row with list-valued `provider`/`bucket` (`[x, xweb]`); do not invent a second must-search channel id for xweb.",
    ),
    (
        "3. **Per-source consent:** checklist from §2.8. Public/no-signup sources can default on; signup sources default off until Yes.",
        "3. **Per-source consent:** checklist from §2.8. Public/no-signup sources can default on; signup sources default off until Yes. **`site:` dependency (locked):** every Method B / `site:` row (Lobsters, Hashnode, Indie Hackers, InfoQ talks, TrustRadius, Capterra, LinkedIn MVP `site:`, dedicated `site:x.com`) **transitively requires** Serper consent, or Brave if Serper is declined and Brave is configured. The consent UI must surface that dependency; consenting a `site:` channel without a Method B key is a recorded `providers_missing` gap, not a silent skip.",
    ),
    (
        "Access = **Serper** (below) with a `site:` query. Brave optional second index.",
        "Access = **Serper** (below) with a `site:` query (requires Serper consent — §2.7 step 3). Brave optional second index if Serper is declined.",
    ),
    (
        "Do **not** pitch twitter-cli / OpenCLI / `bird` / desktop Chrome.",
        "Do **not** pitch twitter-cli / OpenCLI / `bird` / desktop Chrome. **xweb ban-risk (required copy, not skippable):** if the user enables `-p xweb`, tell them that guest token / exported cookies used for in-fork HTTP can get the X account banned or the unofficial API broken; ToS risk is accepted for this product lock; they can skip this leg.",
    ),
    (
        "Ban/maintenance risk accepted; **ToS ignored for this lock**.",
        "Ban/maintenance risk accepted; **ToS ignored for this lock**. `silver:init` **must** show the §2.7 xweb ban-risk required copy before recording xweb consent.",
    ),
    (
        "Claude / Codex / OpenCode are post-MVP: Phase 3 **prints manual URLs** and leaves those channels `providers_missing` — that is success, not a fail.",
        "Claude / Codex / OpenCode are post-MVP: Phase 3 **prints manual URLs** (the same obtain URLs as §2.8) and tells the user to run `search config set keys.<name> -` themselves. The agent still writes `consented_channels` for channels they accepted. `providers_configured` is set only after `search doctor` / `agent-info` sees the key; until then `providers_missing` is success, not a fail. Out-of-band paste is distinguishable: consented + missing key vs never consented.",
    ),
    (
        "xweb bucket/provider present on the X row (or catalog `bucket` includes `x` and `xweb`)",
        "xweb bucket/provider present on the **one** X row as list-valued `provider`/`bucket` including `x` and `xweb`",
    ),
    (
        "`--last` is **human convenience only**. Fleet / `search_orchestrator.py` **must not** pass `--last`.",
        "`--last` is **human convenience only**. Fleet / `search_orchestrator.py` **must not** pass `--last`. **Edge:** if a human passes `--cache-dir` equal to the fleet `SEARCH_CACHE_DIR`, a fleet write clobbers that dir’s `last.json`; `search --last` then replays a fleet query. Do not add a per-user namespace in Phase 1; document the surprise.",
    ),
    (
        "Optional later: `alo-exp/homebrew-tap`. SB CI does not `cargo install` on every job.",
        "Optional later: `alo-exp/homebrew-tap`. SB CI does not `cargo install` on every job. **No binary fallback (Phase 1):** if `alo-exp/search-cli` / tag `v0.9.0-sb.1` is unavailable (outage, yanked tag), `cargo install` fails; there is no cached-binary / mirror path. Record as install gap.",
    ),
    (
        "- No `search serve` in Phase 1 (not in 0.9.0 `Commands`; Phase 1b only if flock races)",
        "- No `search serve` in Phase 1 (not in 0.9.0 `Commands`; Phase 1b only if flock races). **Phase 2+ (optional evaluate, not a commitment):** a long-lived `search serve` / UDS daemon could cut spawn overhead (~10 workers × 5–10 processes) and hold `fleet-slots` in-process; trade-off is daemon crash recovery vs spawn cost. Do not implement in Phase 1.",
    ),
    (
        "alerts (YouTube remaining < 20, Serper remaining < 50, 429s, X credit 0 → stamp official `-p x` missing and fall back to xAI then dedicated `site:x.com`; incidental generic-web `x.com` is not coverage).",
        "alerts (YouTube remaining < 20, Serper remaining < 50, 429s, X credit 0 → stamp official `-p x` missing and fall back to xAI then dedicated `site:x.com`; incidental generic-web `x.com` is not coverage; also GitHub/GitLab PAT expiry, Stack Exchange key rotation, Reddit OAuth app-secret rotation, Brave remaining if configured). **Metrics (Phase 6 docs):** `search usage --json` plus `run_manifest` shards; no required per-channel latency/cache-hit/bucket-wait export in Phase 1 — diagnose slow channels from manifests; optional later structured JSON logs per `search` process.",
    ),
    (
        "After the `q3_` bump it must delete **all `q3_*`** (`q3_*.json` **and** `q3_*.inflight`), leftover `q2_*.json`, `last.json`, and orphaned `last.json.tmp.*`",
        "After the `q3_` bump it must delete **all `q3_*`** (`q3_*.json` **and** `q3_*.inflight`), leftover `q2_*.json`, **and any future `qN_*` prefix** (`q4_*` …) so a fingerprint bump does not orphan files, plus `last.json`, and orphaned `last.json.tmp.*`",
    ),
    (
        "### 6.3 Cache — layout, fingerprint, TTL, multi-process",
        "### 6.3 Cache — layout, fingerprint, TTL, multi-process\n\n**Trade-off (acknowledged, not a Phase 1 change):** per-hash `q3_{hash}.json` + `.inflight` flock matches upstream and stays simpler than one SQLite/sled WAL DB. N-file flock is the locked design; do not silently switch stores.",
    ),
    (
        "keep `[a-z0-9.-]` only.",
        "keep `[a-z0-9.-]` only. **Known limit:** non-ASCII / IDN Discourse hosts fail closed (`InvalidInput`); not reachable in Phase 1. List in §6.13.",
    ),
    (
        "### 6.13 Explicit non-goals (fork)",
        "### 6.13 Explicit non-goals (fork)\n\n- IDN / non-ASCII Discourse hosts (fail closed; see §6.4 sanitizer)\n",
    ),
]

missing = []
for i, (old, new) in enumerate(repls, 1):
    if old not in text:
        missing.append(i)
        continue
    text = text.replace(old, new, 1)

if missing:
    raise SystemExit(f"missing replacements: {missing}")
if text == orig:
    raise SystemExit("no changes applied")

# Round-4 ACCEPT lead-in after last §1.2 RFL bullet if not already present
marker = "- **RFL round 4 post-clarify rung 1 ACCEPTs (2026-08-31, GLM 5.2 High):**"
if marker not in text:
    needle = "- **RFL missing High+ item 10 ACCEPTs"
    idx = text.find(needle)
    if idx < 0:
        raise SystemExit("cannot find §1.2 insert point")
    # insert after that bullet line
    end = text.find("\n", idx)
    insert = (
        "\n- **RFL round 4 post-clarify rung 1 ACCEPTs (2026-08-31, GLM 5.2 High):** "
        "X dedup in SB orchestrator (tweet id else canonical status URL); "
        "`site:` rows require Serper/Brave consent (UI must say so); "
        "xweb ban-risk required copy at init; "
        "non-Cursor hosts print §2.8 URLs + `search config set` and still write `consented_channels`; "
        "one X catalog row with list `provider`/`bucket`; "
        "`last.json` clobber if human reuses fleet cache dir; "
        "no binary fallback if git tag missing; "
        "`search serve` Phase 2+ evaluate only; "
        "ops alerts include PAT/secret rotation; "
        "`cache clear` also deletes future `qN_*`; "
        "flat-file cache vs SQLite acknowledged; "
        "IDN Discourse is a known limit; "
        "Phase 6 metrics = usage + run_manifest (no required latency export)."
    )
    text = text[:end] + insert + text[end:]

PLAN.write_text(text, encoding="utf-8")
print(f"wrote {PLAN} ({len(text)} bytes, {text.count(chr(10))+1} lines)")
