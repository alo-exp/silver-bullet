## Residual-only review (Policy G)

- Residual-only means **do not re-report ledger rows**, not "file only one new ID."
- File **all** valid residuals at the current SHA, **all severities** (HIGH / MED / LOW / nit). Valid nits must be filed. CLEAN only if nothing valid remains.
- Triage still REJECTS invalid items (already encoded, false cite, KEEP REJECT collision). All **ACCEPT**ed items — including nits — are **APPLY'd as a pack** that pass (order-dependent findings together).
- Policy F unchanged: 2 consecutive CLEAN on unchanged SHA; `accept-apply` still resets that rung's streak to 0.

## Issue ledger (already identified)

| ID | Severity | Decision | Resolved | SHA | One-line |
|----|----------|----------|----------|-----|----------|
| I-1 | MED | ACCEPT | yes | 44bf064c3381 | X union dedup in SB orchestrator (F1) |
| I-2 | MED | ACCEPT | yes | 44bf064c3381 | site: rows require Serper/Brave consent (F2) |
| I-3 | MED | ACCEPT | yes | 44bf064c3381 | xweb ban-risk required copy at init (F3) |
| I-4 | MED | ACCEPT | yes | 44bf064c3381 | Non-Cursor init: URLs + search config set (F4) |
| I-5 | MED | ACCEPT | yes | 44bf064c3381 | One X row; list provider/bucket (F5) |
| I-6 | LOW | ACCEPT | yes | 44bf064c3381 | last.json clobber if human reuses fleet cache (F6) |
| I-7 | LOW | ACCEPT | yes | 44bf064c3381 | No binary fallback if git tag missing (F7) |
| I-8 | LOW | ACCEPT | yes | 44bf064c3381 | search serve Phase 2+ evaluate only (F8) |
| I-9 | LOW | ACCEPT | yes | 44bf064c3381 | Ops alerts for PAT/secret rotation (F9) |
| I-10 | LOW | ACCEPT | yes | 44bf064c3381 | cache clear also deletes future qN_* (F10) |
| I-11 | NIT | ACCEPT | yes | 44bf064c3381 | Flat-file vs SQLite acknowledged (F11) |
| I-12 | NIT | ACCEPT | yes | 44bf064c3381 | IDN Discourse known limit (F12) |
| I-13 | NIT | ACCEPT | yes | 44bf064c3381 | Metrics = usage + run_manifest (F13) |
| I-14 | LOW | ACCEPT | yes | 44bf064c3381 | Inline superseded on historical X must_search:false (R1) |
| I-15 | NIT | ACCEPT | yes | 44bf064c3381 | Official-JSON site: fallbacks best-effort degrade (R2) |
| I-16 | LOW | ACCEPT | yes | 44bf064c3381 | `--allow-private` in cache fingerprint (S1) |
| I-17 | NIT | ACCEPT | yes | 44bf064c3381 | `--cache-ttl` is a Phase 1 fork ADD, not upstream-exposed (U1) |
| I-18 | NIT | ACCEPT | yes | 44bf064c3381 | `SB_DR_FLEET_SLOTS` is orchestrator-only; fork does not read it (U2) |
| I-19 | NIT | ACCEPT | yes | 44bf064c3381 | `src/doctor.rs` on §8.1/§8.4 Modify checklists (V1) |
| I-20 | MED | ACCEPT | yes | 44bf064c3381 | Human `--quota-dir` default is `~/.config/silver-bullet/search-quota/` never ProjectDirs (W1) |
| I-21 | LOW | ACCEPT | yes | 44bf064c3381 | `--allow-private` is last `stable_hash` field after lang (W2) |
| I-22 | LOW | ACCEPT | yes | 44bf064c3381 | `-d` canonicalized before `augment_query` (W3) |
| I-23 | LOW | ACCEPT | yes | 44bf064c3381 | Reddit refresh double-checks TTL under lock (W4) |
| I-24 | LOW | ACCEPT | yes | 44bf064c3381 | clap `-p` values drift-guard vs agent-info ids (W5) |
| I-25 | NIT | ACCEPT | yes | 44bf064c3381 | Absent `reddit-oauth-token.lock` is unlockable (W6) |
| I-26 | NIT | ACCEPT | yes | 44bf064c3381 | Brave bucket acquire test in §6.12 (W7) |
| I-27 | LOW | ACCEPT | yes | 44bf064c3381 | §4.4 doctor risk is shared fleet quota, not `$HOME/.cache/search` (X1) |
| I-28 | NIT | ACCEPT | yes | 44bf064c3381 | `--max-chars` emit/truncation test in §6.12 (X2) |
| I-29 | NIT | ACCEPT | yes | 44bf064c3381 | `doctor.rs` behavior tests in §6.12 (X3) |
| I-30 | LOW | ACCEPT | yes | 44bf064c3381 | §1.2 H1 `SB_DR_FLEET_SLOTS` fork-read superseded (Y1) |
| I-31 | LOW | ACCEPT | yes | 44bf064c3381 | §6.12 serper/x acquire tests (AA1) |
| I-32 | NIT | ACCEPT | yes | 44bf064c3381 | Human-run `cache_ttl_default_300s` negative test (AA2) |
| I-33 | LOW | ACCEPT | yes | 44bf064c3381 | §3 X-union dedup test (AB1) |
| I-34 | NIT | ACCEPT | yes | 44bf064c3381 | clap `--cache-ttl` in `--help` (AB2) |
| I-35 | NIT | ACCEPT | yes | 44bf064c3381 | Reddit OAuth no-stampede test (AB3) |
| I-36 | NIT | ACCEPT | yes | 44bf064c3381 | `clear()` removes future `qN_*` (AB4) |
| I-37 | NIT | ACCEPT | yes | 44bf064c3381 | `clear()` removes orphaned `last.json.tmp.*` (AC1) |
| I-38 | NIT | ACCEPT | yes | 44bf064c3381 | Held reddit lock drives `cache_clear_busy`; absent is unlockable (AC2) |
| I-39 | NIT | ACCEPT | yes | 44bf064c3381 | Token-endpoint does not consume reddit search bucket (AC3) |
| I-40 | NIT | ACCEPT | yes | 44bf064c3381 | `clear()` preserves query-cache `.gitignore` (AD1) |
| I-41 | NIT | ACCEPT | yes | 44bf064c3381 | §4.1/§5/§8.1/§8.4 `clear()` preserve rosters include query-cache `.gitignore` (AE1) |
| I-42 | NIT | ACCEPT | yes | 44bf064c3381 | §4.1/§5/§8.1/§8.4 `clear()` delete-set rosters include future `qN_*` (AF1) |
| I-43 | NIT | ACCEPT | yes | 44bf064c3381 | §6.3/§6.4 markdown sub-bullets start on their own lines (AG1) |
| I-44 | NIT | ACCEPT | yes | 44bf064c3381 | §1.2 L85 rollup cites §4.3 for X-union dedup test (AH1) |
| I-45 | NIT | ACCEPT | yes | 44bf064c3381 | §6.4 Serper free 2,500 vs Starter 50k credits (K1) |
| I-46 | NIT | ACCEPT | yes | 44bf064c3381 | §3.2 `partial_success` not `partial` (K2) |
| I-47 | LOW | ACCEPT | yes | 44bf064c3381 | §2.7 step 4 keys via `search config set` only (K3) |
| I-48 | NIT | ACCEPT | yes | 44bf064c3381 | §2.2 probe native list includes `x`/`xweb` (K4) |
| I-49 | NIT | ACCEPT | yes | 44bf064c3381 | cargo-install `SB_SEARCH_BIN` is `$HOME/.cargo/bin/search` (K5) |
| I-50 | NIT | ACCEPT | yes | 44bf064c3381 | §4.4 X-credit-0 alert includes xweb (K6) |
| I-51 | NIT | ACCEPT | yes | 44bf064c3381 | §7 mermaid quota includes reddit-oauth-token.json+.lock (K7) |
| I-52 | LOW | ACCEPT | yes | 44bf064c3381 | §6.12 config.example.toml X keys Phase-2-gated (K8) |
| I-53 | NIT | ACCEPT | yes | 44bf064c3381 | §2.3 fingerprint includes --allow-private (K9) |
| I-54 | NIT | ACCEPT | yes | 44bf064c3381 | researched-project (not SB-only) root .gitignore (K10) |
| I-55 | NIT | ACCEPT | yes | 44bf064c3381 | §7 mermaid providers include x/xweb (K11) |
| I-56 | NIT | ACCEPT | yes | 44bf064c3381 | §2.2 bucket short-names include x/xweb (R2P3-1) |
| I-57 | LOW | ACCEPT | yes | 44bf064c3381 | xweb envs via resolve_keys not figment SEARCH_KEYS_XWEB_GUEST (R2P3-2) |
| I-58 | LOW | ACCEPT | yes | 44bf064c3381 | X site:x.com in -q is locked exception to bare-host -d (R2P4-1) |
| I-59 | NIT | ACCEPT | yes | 44bf064c3381 | §2.8 X search/all stamps signup_automation manual_only (R2P4-2) |
| I-60 | NIT | ACCEPT | yes | 44bf064c3381 | frontmatter overview no longer claims autonomous signup (R2P4-3) |
| R2P4-1 | LOW | ACCEPT | yes | 44bf064c3381 | X site:x.com in -q vs §6.3/§6.9 bare-host -d rule |
| R2P4-2 | NIT | ACCEPT | yes | 44bf064c3381 | §2.8 X search/all omits signup_automation stamp |
| R2P4-3 | NIT | ACCEPT | yes | 44bf064c3381 | frontmatter overview overclaims autonomously signs up |

Do **not** re-file ledger IDs unless a residual defect remains in **this** freeze.
CLEAN only if the re-read finds nothing valid beyond the ledger.
