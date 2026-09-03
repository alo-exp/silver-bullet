# ISSUE-LEDGER — DR search gateway plan (round 4 post-clarify)

**Artifact:** [`dr_search_gateway_prd_ecb5030e.plan.md`](/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md)  
**Current SHA:** `f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6`


Freeze SHA after APPLY: `f6ba43bb7d7d4d4ca394333ae5f7c15022059040edac9ec75585654630584cd6`

## Issue ledger (Policy G encoder)

| ID | Severity | Status | Summary |
|----|----------|--------|---------|
| I-1 | MED | ACCEPT | X union dedup in SB orchestrator (F1) |
| I-2 | MED | ACCEPT | site: rows require Serper/Brave consent (F2) |
| I-3 | MED | ACCEPT | xweb ban-risk required copy at init (F3) |
| I-4 | MED | ACCEPT | Non-Cursor init: URLs + search config set (F4) |
| I-5 | MED | ACCEPT | One X row; list provider/bucket (F5) |
| I-6 | LOW | ACCEPT | last.json clobber if human reuses fleet cache (F6) |
| I-7 | LOW | ACCEPT | No binary fallback if git tag missing (F7) |
| I-8 | LOW | ACCEPT | search serve Phase 2+ evaluate only (F8) |
| I-9 | LOW | ACCEPT | Ops alerts for PAT/secret rotation (F9) |
| I-10 | LOW | ACCEPT | cache clear also deletes future qN_* (F10) |
| I-11 | NIT | ACCEPT | Flat-file vs SQLite acknowledged (F11) |
| I-12 | NIT | ACCEPT | IDN Discourse known limit (F12) |
| I-13 | NIT | ACCEPT | Metrics = usage + run_manifest (F13) |
| I-14 | LOW | ACCEPT | Inline superseded on historical X must_search:false (R1) |
| I-15 | NIT | ACCEPT | Official-JSON site: fallbacks best-effort degrade (R2) |
| I-16 | LOW | ACCEPT | `--allow-private` in cache fingerprint (S1) |
| I-17 | NIT | ACCEPT | `--cache-ttl` is a Phase 1 fork ADD, not upstream-exposed (U1) |
| I-18 | NIT | ACCEPT | `SB_DR_FLEET_SLOTS` is orchestrator-only; fork does not read it (U2) |
| I-19 | NIT | ACCEPT | `src/doctor.rs` on §8.1/§8.4 Modify checklists (V1) |
| I-20 | MED | ACCEPT | Human `--quota-dir` default is `~/.config/silver-bullet/search-quota/` never ProjectDirs (W1) |
| I-21 | LOW | ACCEPT | `--allow-private` is last `stable_hash` field after lang (W2) |
| I-22 | LOW | ACCEPT | `-d` canonicalized before `augment_query` (W3) |
| I-23 | LOW | ACCEPT | Reddit refresh double-checks TTL under lock (W4) |
| I-24 | LOW | ACCEPT | clap `-p` values drift-guard vs agent-info ids (W5) |
| I-25 | NIT | ACCEPT | Absent `reddit-oauth-token.lock` is unlockable (W6) |
| I-26 | NIT | ACCEPT | Brave bucket acquire test in §6.12 (W7) |
| I-27 | LOW | ACCEPT | §4.4 doctor risk is shared fleet quota, not `$HOME/.cache/search` (X1) |
| I-28 | NIT | ACCEPT | `--max-chars` emit/truncation test in §6.12 (X2) |
| I-29 | NIT | ACCEPT | `doctor.rs` behavior tests in §6.12 (X3) |
| I-30 | LOW | ACCEPT | §1.2 H1 `SB_DR_FLEET_SLOTS` fork-read superseded (Y1) |
| I-31 | LOW | ACCEPT | §6.12 serper/x acquire tests (AA1) |
| I-32 | NIT | ACCEPT | Human-run `cache_ttl_default_300s` negative test (AA2) |
| I-33 | LOW | ACCEPT | §3 X-union dedup test (AB1) |
| I-34 | NIT | ACCEPT | clap `--cache-ttl` in `--help` (AB2) |
| I-35 | NIT | ACCEPT | Reddit OAuth no-stampede test (AB3) |
| I-36 | NIT | ACCEPT | `clear()` removes future `qN_*` (AB4) |
| I-37 | NIT | ACCEPT | `clear()` removes orphaned `last.json.tmp.*` (AC1) |
| I-38 | NIT | ACCEPT | Held reddit lock drives `cache_clear_busy`; absent is unlockable (AC2) |
| I-39 | NIT | ACCEPT | Token-endpoint does not consume reddit search bucket (AC3) |
| I-40 | NIT | ACCEPT | `clear()` preserves query-cache `.gitignore` (AD1) |
| I-41 | NIT | ACCEPT | §4.1/§5/§8.1/§8.4 `clear()` preserve rosters include query-cache `.gitignore` (AE1) |
| I-42 | NIT | ACCEPT | §4.1/§5/§8.1/§8.4 `clear()` delete-set rosters include future `qN_*` (AF1) |
| I-43 | NIT | ACCEPT | §6.3/§6.4 markdown sub-bullets start on their own lines (AG1) |
| I-44 | NIT | ACCEPT | §1.2 L85 rollup cites §4.3 for X-union dedup test (AH1) |
| I-45 | NIT | ACCEPT | §6.4 Serper free 2,500 vs Starter 50k credits (K1) |
| I-46 | NIT | ACCEPT | §3.2 `partial_success` not `partial` (K2) |
| I-47 | LOW | ACCEPT | §2.7 step 4 keys via `search config set` only (K3) |
| I-48 | NIT | ACCEPT | §2.2 probe native list includes `x`/`xweb` (K4) |
| I-49 | NIT | ACCEPT | cargo-install `SB_SEARCH_BIN` is `$HOME/.cargo/bin/search` (K5) |
| I-50 | NIT | ACCEPT | §4.4 X-credit-0 alert includes xweb (K6) |
| I-51 | NIT | ACCEPT | §7 mermaid quota includes reddit-oauth-token.json+.lock (K7) |
| I-52 | LOW | ACCEPT | §6.12 config.example.toml X keys Phase-2-gated (K8) |
| I-53 | NIT | ACCEPT | §2.3 fingerprint includes --allow-private (K9) |
| I-54 | NIT | ACCEPT | researched-project (not SB-only) root .gitignore (K10) |
| I-55 | NIT | ACCEPT | §7 mermaid providers include x/xweb (K11) |
| I-56 | NIT | ACCEPT | §2.2 bucket short-names include x/xweb (R2P3-1) |
| I-57 | LOW | ACCEPT | xweb envs via resolve_keys not figment SEARCH_KEYS_XWEB_GUEST (R2P3-2) |
| I-58 | LOW | ACCEPT | X site:x.com in -q is locked exception to bare-host -d (R2P4-1) |
| I-59 | NIT | ACCEPT | §2.8 X search/all stamps signup_automation manual_only (R2P4-2) |
| I-60 | NIT | ACCEPT | frontmatter overview no longer claims autonomous signup (R2P4-3) |
| I-61 | LOW | ACCEPT | §6.1 fleet never --x shorthand; xAI leg still -m social -p xai (R2P5-1) |
| I-62 | NIT | ACCEPT | §1.2 X dedup orchestrator-only not fork (R2P5-2) |
| I-63 | NIT | ACCEPT | §6.3 quota files buckets/{id} not <host> (R2P5-3) |
| I-64 | NIT | ACCEPT | §7 Serper node names -d bare-host and -q exceptions (R2P5-4) |
IDs: `I-1` … sequential. Do not reuse numbers.

## Master inventory

| ID | Sev | Summary | First rung | ACCEPT | Applied |
|----|-----|---------|------------|--------|---------|
| I-1 | MED | X union dedup in SB orchestrator (F1) | rung-01 GLM 5.2 High | yes | yes |
| I-2 | MED | site: rows require Serper/Brave consent (F2) | rung-01 GLM 5.2 High | yes | yes |
| I-3 | MED | xweb ban-risk required copy at init (F3) | rung-01 GLM 5.2 High | yes | yes |
| I-4 | MED | Non-Cursor init: URLs + search config set (F4) | rung-01 GLM 5.2 High | yes | yes |
| I-5 | MED | One X row; list provider/bucket (F5) | rung-01 GLM 5.2 High | yes | yes |
| I-6 | LOW | last.json clobber if human reuses fleet cache (F6) | rung-01 GLM 5.2 High | yes | yes |
| I-7 | LOW | No binary fallback if git tag missing (F7) | rung-01 GLM 5.2 High | yes | yes |
| I-8 | LOW | search serve Phase 2+ evaluate only (F8) | rung-01 GLM 5.2 High | yes | yes |
| I-9 | LOW | Ops alerts for PAT/secret rotation (F9) | rung-01 GLM 5.2 High | yes | yes |
| I-10 | LOW | cache clear also deletes future qN_* (F10) | rung-01 GLM 5.2 High | yes | yes |
| I-11 | NIT | Flat-file vs SQLite acknowledged (F11) | rung-01 GLM 5.2 High | yes | yes |
| I-12 | NIT | IDN Discourse known limit (F12) | rung-01 GLM 5.2 High | yes | yes |
| I-13 | NIT | Metrics = usage + run_manifest (F13) | rung-01 GLM 5.2 High | yes | yes |
| I-14 | LOW | Inline superseded on historical X must_search:false (R1) | rung-01 GLM pass 2 | yes | yes |
| I-15 | NIT | Official-JSON site: fallbacks best-effort degrade (R2) | rung-01 GLM pass 2 | yes | yes |
| I-16 | LOW | `--allow-private` in cache fingerprint (S1) | rung-01 GLM pass 4 | yes | yes |
| I-17 | NIT | `--cache-ttl` is a Phase 1 fork ADD, not upstream-exposed (U1) | rung-01 GLM pass 6 | yes | yes |
| I-18 | NIT | `SB_DR_FLEET_SLOTS` is orchestrator-only; fork does not read it (U2) | rung-01 GLM pass 6 | yes | yes |
| I-19 | NIT | `src/doctor.rs` on §8.1/§8.4 Modify checklists (V1) | rung-01 GLM pass 7 | yes | yes |
| I-20 | MED | Human `--quota-dir` default is `~/.config/silver-bullet/search-quota/` never ProjectDirs (W1) | rung-01 GLM pass 8 | yes | yes |
| I-21 | LOW | `--allow-private` is last `stable_hash` field after lang (W2) | rung-01 GLM pass 8 | yes | yes |
| I-22 | LOW | `-d` canonicalized before `augment_query` (W3) | rung-01 GLM pass 8 | yes | yes |
| I-23 | LOW | Reddit refresh double-checks TTL under lock (W4) | rung-01 GLM pass 8 | yes | yes |
| I-24 | LOW | clap `-p` values drift-guard vs agent-info ids (W5) | rung-01 GLM pass 8 | yes | yes |
| I-25 | NIT | Absent `reddit-oauth-token.lock` is unlockable (W6) | rung-01 GLM pass 8 | yes | yes |
| I-26 | NIT | Brave bucket acquire test in §6.12 (W7) | rung-01 GLM pass 8 | yes | yes |
| I-27 | LOW | §4.4 doctor risk is shared fleet quota, not `$HOME/.cache/search` (X1) | rung-01 GLM pass 9 | yes | yes |
| I-28 | NIT | `--max-chars` emit/truncation test in §6.12 (X2) | rung-01 GLM pass 9 | yes | yes |
| I-29 | NIT | `doctor.rs` behavior tests in §6.12 (X3) | rung-01 GLM pass 9 | yes | yes |
| I-30 | LOW | §1.2 H1 `SB_DR_FLEET_SLOTS` fork-read superseded (Y1) | rung-01 GLM pass 10 | yes | yes |
| I-31 | LOW | §6.12 serper/x acquire tests (AA1) | rung-01 GLM pass 12 | yes | yes |
| I-32 | NIT | Human-run `cache_ttl_default_300s` negative test (AA2) | rung-01 GLM pass 12 | yes | yes |
| I-33 | LOW | §3 X-union dedup test (AB1) | rung-01 GLM pass 13 | yes | yes |
| I-34 | NIT | clap `--cache-ttl` in `--help` (AB2) | rung-01 GLM pass 13 | yes | yes |
| I-35 | NIT | Reddit OAuth no-stampede test (AB3) | rung-01 GLM pass 13 | yes | yes |
| I-36 | NIT | `clear()` removes future `qN_*` (AB4) | rung-01 GLM pass 13 | yes | yes |
| I-37 | NIT | `clear()` removes orphaned `last.json.tmp.*` (AC1) | rung-01 GLM pass 14 | yes | yes |
| I-38 | NIT | Held reddit lock drives `cache_clear_busy`; absent is unlockable (AC2) | rung-01 GLM pass 14 | yes | yes |
| I-39 | NIT | Token-endpoint does not consume reddit search bucket (AC3) | rung-01 GLM pass 14 | yes | yes |
| I-40 | NIT | `clear()` preserves query-cache `.gitignore` (AD1) | rung-01 GLM pass 15 | yes | yes |
| I-41 | NIT | §4.1/§5/§8.1/§8.4 `clear()` preserve rosters include query-cache `.gitignore` (AE1) | rung-01 GLM pass 16 | yes | yes |
| I-42 | NIT | §4.1/§5/§8.1/§8.4 `clear()` delete-set rosters include future `qN_*` (AF1) | rung-01 GLM pass 17 | yes | yes |
| I-43 | NIT | §6.3/§6.4 markdown sub-bullets start on their own lines (AG1) | rung-01 GLM pass 19 | yes | yes |
| I-44 | NIT | §1.2 L85 rollup cites §4.3 for X-union dedup test (AH1) | rung-01 GLM pass 20 | yes | yes |
| I-45 | NIT | §6.4 Serper free 2,500 vs Starter 50k credits (K1) | rung-02 Kimi K3 High | yes | yes |
| I-46 | NIT | §3.2 `partial_success` not `partial` (K2) | rung-02 Kimi K3 High | yes | yes |
| I-47 | LOW | §2.7 step 4 keys via `search config set` only (K3) | rung-02 Kimi K3 High | yes | yes |
| I-48 | NIT | §2.2 probe native list includes `x`/`xweb` (K4) | rung-02 Kimi K3 High | yes | yes |
| I-49 | NIT | cargo-install `SB_SEARCH_BIN` is `$HOME/.cargo/bin/search` (K5) | rung-02 Kimi K3 High | yes | yes |
| I-50 | NIT | §4.4 X-credit-0 alert includes xweb (K6) | rung-02 Kimi K3 High | yes | yes |
| I-51 | NIT | §7 mermaid quota includes reddit-oauth-token.json+.lock (K7) | rung-02 Kimi pass-2 | yes | yes |
| I-52 | LOW | §6.12 config.example.toml X keys Phase-2-gated (K8) | rung-02 Kimi pass-2 | yes | yes |
| I-53 | NIT | §2.3 fingerprint includes --allow-private (K9) | rung-02 Kimi pass-2 | yes | yes |
| I-54 | NIT | researched-project (not SB-only) root .gitignore (K10) | rung-02 Kimi pass-2 | yes | yes |
| I-55 | NIT | §7 mermaid providers include x/xweb (K11) | rung-02 Kimi pass-2 | yes | yes |
| I-56 | NIT | §2.2 bucket short-names include x/xweb (R2P3-1) | rung-02 Kimi pass-3 | yes | yes |
| I-57 | LOW | xweb envs via resolve_keys not figment SEARCH_KEYS_XWEB_GUEST (R2P3-2) | rung-02 Kimi pass-3 | yes | yes |
| I-58 | LOW | X site:x.com in -q is locked exception to bare-host -d (R2P4-1) | rung-02 Kimi pass-4 | yes | yes |
| I-59 | NIT | §2.8 X search/all stamps signup_automation manual_only (R2P4-2) | rung-02 Kimi pass-4 | yes | yes |
| I-60 | NIT | frontmatter overview no longer claims autonomous signup (R2P4-3) | rung-02 Kimi pass-4 | yes | yes |
| I-61 | LOW | §6.1 fleet never --x shorthand; xAI leg still -m social -p xai (R2P5-1) | rung-02 Kimi pass-5 | yes | yes |
| I-62 | NIT | §1.2 X dedup orchestrator-only not fork (R2P5-2) | rung-02 Kimi pass-5 | yes | yes |
| I-63 | NIT | §6.3 quota files buckets/{id} not <host> (R2P5-3) | rung-02 Kimi pass-5 | yes | yes |
| I-64 | NIT | §7 Serper node names -d bare-host and -q exceptions (R2P5-4) | rung-02 Kimi pass-5 | yes | yes |
