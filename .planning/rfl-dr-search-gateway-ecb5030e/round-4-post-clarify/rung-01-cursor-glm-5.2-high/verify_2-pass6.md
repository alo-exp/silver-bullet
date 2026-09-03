model: composer-2.5

**Subagent:** `sb-composer-2-5-high`  
**Phase:** VERIFY-ONLY pass 2/2 (`verify_2`, independent of verify_1)  
**Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`  
**SHA-256:** `b71a7efdc0b70ea12b74bc485d740a76d927a15bd41fe8e84ea2c5fd62c3ee9f` (verified via `shasum -a 256`)  
**Graphify:** `graphify query "cache-ttl fork ADD SB_DR_FLEET orchestrator-only" --budget 2000` (290 nodes; oriented probe/fork/TTL/slot contract)  
**Apply ref:** U1 / I-17 (`--cache-ttl` Phase 1 fork ADD) · U2 / I-18 (`SB_DR_FLEET_SLOTS` orchestrator-only)

## Verdict

**VERIFY_PASS** — Independent re-read at pinned SHA confirms U1 / I-17 and U2 / I-18 APPLY; `"upstream already exposes"` absent; Facebook `must_search: false` intact; X / xweb / search-cli gateway present; I-1–I-16 substance retained.

## SHA gate

| Check | Status | Evidence |
|-------|--------|----------|
| Plan SHA-256 matches charter | PASS | `shasum -a 256` → `b71a7efdc0b70ea12b74bc485d740a76d927a15bd41fe8e84ea2c5fd62c3ee9f` |

## Grep gate

| Check | Status | Evidence |
|-------|--------|----------|
| `"upstream already exposes"` absent | PASS | Full-plan scan: 0 hits (only negated `not upstream-exposed` at L85) |

## U1 / I-17 — `--cache-ttl` is Phase 1 fork ADD / argv lock (not `wrong_binary` discriminator)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| `--cache-ttl` is a Phase 1 fork ADD (not upstream-exposed) | PASS | L85 ACCEPT: `` `--cache-ttl` is a Phase 1 fork ADD (not upstream-exposed) ``; L330 §4.1 Phase 1 must list `--cache-ttl` / `SEARCH_CACHE_TTL`; L377 §8.3: `` new global `--cache-dir` / `--quota-dir` / `--cache-ttl` only ``; L414 §6.2 defines `--cache-ttl <SECS>` / `SEARCH_CACHE_TTL`; L770 §8.4 item 1: add global `--cache-ttl`/`SEARCH_CACHE_TTL` |
| `--cache-ttl` is argv lock for orchestrator fleet argv (not probe discriminator) | PASS | L83 (M-1): `` `--cache-ttl` stays an argv lock (added by the fork in Phase 1 alongside `--cache-dir`/`--quota-dir`; not a `wrong_binary` discriminator — dir flags + fingerprint versions already reject upstream 0.9.0) ``; L124 §2.2 probe contract: same wording; L339 §4.3: probe stubs omit `--cache-dir` / `--quota-dir` / fork natives / `cache_fingerprint_version` → `wrong_binary` (no `--cache-ttl` in discriminator list) |
| `wrong_binary` probe uses `--cache-dir` + `--quota-dir` + fork natives + fingerprint versions | PASS | L124 §2.2: `` require `--cache-dir` **and** `--quota-dir` in `search --help` … `cache_fingerprint_version: "q3"` **and** `cached_entry_version: 1` ``; L339 §4.3: `` stub without `--cache-dir` / `--quota-dir` / fork natives / `cache_fingerprint_version` → `wrong_binary` ``; L83: `` Stub with `--cache-dir` but without `--quota-dir` → `wrong_binary` `` |
| Fleet argv must include `--cache-ttl` | PASS | L124 §2.2 orchestrator argv list includes `--cache-ttl`; L339 §4.3: fleet argv fixture **includes** `--cache-ttl`; L460 §6.3: `` Orchestrator argv **must** pass `--cache-ttl` `` |

## U2 / I-18 — `SB_DR_FLEET` fork-only; `SB_DR_FLEET_SLOTS` orchestrator-only; quiesce/clear ceiling-10

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| Fork **may** read `SB_DR_FLEET` only (TTL warning) | PASS | L84 (M-2): `` Fork may read `SB_DR_FLEET` for the TTL warning only ``; L460 §6.3: `` if `SB_DR_FLEET=1` and neither `--cache-ttl` nor `SEARCH_CACHE_TTL` is set … append envelope `warnings` string `cache_ttl_default_300s` ``; L523 §6.7 / L644 §6.12: same `cache_ttl_default_300s` contract |
| `SB_DR_FLEET_SLOTS` is orchestrator-only; fork does **not** read it | PASS | L85 ACCEPT: `` `SB_DR_FLEET_SLOTS` is orchestrator-only (fork does not read it) ``; L84 (M-2): `` `SB_DR_FLEET_SLOTS` is orchestrator-only (admission N); the fork does not read it ``; L661 §6.13: `` Fork **may** read `SB_DR_FLEET` for the fleet TTL warning only. `SB_DR_FLEET_SLOTS` is **orchestrator-only** … the fork does **not** read it `` |
| Quiesce/clear remains ceiling-10 (`0.lock`…`9.lock`), never `{N-1}` | PASS | L84 (M-2): `` Quiesce/clear is **always ceiling-10** (`0.lock`…`9.lock`), never `{N-1}` ``; L462 §6.3 / L661 §6.13: same ceiling-10 quiesce barrier |
| Admission N via orchestrator slot files (distinct from fork bucket locks) | PASS | L339 §4.3: `` Fleet-slots admission: with `SB_DR_FLEET_SLOTS=5`, a 6th spawn queues; clamp `4→5` and `11→10` ``; L604 §6.11 / L712 §7: orchestrator N-slot flock at `{SEARCH_QUOTA_DIR}/fleet-slots.lock/` |

## Facebook + X / xweb / gateway regression guard

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| Facebook `must_search: false` | PASS | L54: `` Facebook stays **not** must-search ``; L198 §2.5: `` Facebook: `must_search: false` ``; L339 §4.3: `` facebook `must_search=false` `` |
| X `must_search: true` / `mvp: true` with xweb union | PASS | L101 §1.4: `` `must_search: true`, `mvp: true` `` union legs; L178 §2.5: `` `provider: x` … **plus** `provider: xweb`, `bucket: xweb` ``; L339 §4.3: `` x `must_search=true` and `mvp=true`, xweb bucket/provider present on the **one** X row `` |
| search-cli remains the only gateway | PASS | L55: `` search-cli remains the only gateway (no second Python engine) ``; L124 §2.2 orchestrator → `search` CLI from catalog |

## I-1–I-16 remain present

| ID | Status | Evidence (plan) |
|----|--------|-----------------|
| I-1 X dedup in SB orchestrator | PASS | L85 ACCEPT; L101 §1.4 dedup in `search_orchestrator.py` |
| I-2 `site:` rows require Serper/Brave consent | PASS | L85 ACCEPT; L219 §2.7 step 3 `site:` dependency |
| I-3 xweb ban-risk required copy | PASS | L85 ACCEPT; L218 §2.7 step 2 |
| I-4 Non-Cursor init URLs + `search config set` | PASS | L85 ACCEPT; L220 §2.7 step 4 |
| I-5 One X row; list `provider`/`bucket` | PASS | L85 ACCEPT; L120 §2.2; L178 §2.5 |
| I-6 `last.json` clobber if human reuses fleet cache | PASS | L85 ACCEPT; L420 §6.2 |
| I-7 No binary fallback if git tag missing | PASS | L85 ACCEPT; L324 §3.4 |
| I-8 `search serve` Phase 2+ evaluate only | PASS | L85 ACCEPT; L660 §6.13 |
| I-9 Ops alerts PAT/secret rotation | PASS | L85 ACCEPT; L344 §4.4 |
| I-10 `cache clear` deletes future `qN_*` | PASS | L85 ACCEPT; L462 §6.3 |
| I-11 Flat-file vs SQLite acknowledged | PASS | L85 ACCEPT; L434 §6.3 trade-off |
| I-12 IDN Discourse known limit | PASS | L85 ACCEPT; L481 §6.4; L650 §6.13 |
| I-13 Metrics = usage + run_manifest | PASS | L85 ACCEPT; L344 §4.4 |
| I-14 Historical X `must_search: false` superseded markers | PASS | L73–L84 ledger bullets carry `(superseded 2026-08-31; X is \`must_search: true\` per §1.2 lock)` |
| I-15 Official-JSON `site:` fallbacks best-effort degrade | PASS | L219 §2.7 step 3 |
| I-16 `--allow-private` in `stable_hash` | PASS | L85 ACCEPT; L458 §6.3 fingerprint field list |

## Leftover gaps vs U1 / I-17 and U2 / I-18 APPLY charter

None blocking. **Note (non-blocking):** L73 (rung 10 historical ledger, 2026-08-16) still says `` Fork may read `SB_DR_FLEET_SLOTS` `` — superseded by L84 M-2 and operative L661 §6.13 (same historical-ledger pattern as I-14 `must_search: false` markers).

## Notes

- Verify is **not** a Policy F streak.
- Independent of [verify_1-pass6.md](verify_1-pass6.md); same SHA, same PASS criteria, separate re-read.
