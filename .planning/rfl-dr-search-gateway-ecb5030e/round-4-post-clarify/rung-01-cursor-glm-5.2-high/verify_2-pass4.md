model: composer-2.5

**Subagent:** `sb-composer-2-5-high`  
**Phase:** VERIFY-ONLY pass 2/2 (`verify_2`, independent of verify_1)  
**Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`  
**SHA-256:** `1412d8c9d18e1e2204c8b5011906fc341fb19b1b7a77df9b708e51e47b175db4` (verified via `shasum -a 256`)  
**Graphify:** `graphify query "allow-private cache fingerprint human writer fleet" --budget 2000` (143 nodes; oriented S1/F6/fingerprint contract)  
**Apply ref:** S1 / I-16 (`--allow-private` in `stable_hash`)

## Verdict

**VERIFY_PASS** — Independent re-read at pinned SHA confirms S1 / I-16 APPLY; all fingerprint-contract checks present with file:line evidence; Facebook `must_search: false` unchanged; I-1–I-15 substance retained.

## SHA gate

| Check | Status | Evidence |
|-------|--------|----------|
| Plan SHA-256 matches charter | PASS | `shasum -a 256` → `1412d8c9d18e1e2204c8b5011906fc341fb19b1b7a77df9b708e51e47b175db4` |

## S1 / I-16 — `--allow-private` in `stable_hash`

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| `--allow-private` IS a `stable_hash` boolean field (default false) | PASS | L84 (missing High+ item 10 M-4): `` **`--allow-private` IS a `stable_hash` field** (boolean; default false) ``; L458 §6.3: `` **`--allow-private` IS in the hash** (boolean field; default false; round-4 pass 4 S1) ``; L771 §8.4: `` fingerprint includes … + `--allow-private` `` |
| `--max-chars` stays OUT of the hash | PASS | L84: `` `--max-chars` is **not** a `stable_hash` field ``; L330 §4.1: `` (**not** `count`, **not** TTL, **not** `--max-chars` …) ``; L458 §6.3: `` **Do not** put `--max-chars` in the hash ``; L771 §8.4: `` (**not** count, **not** TTL, **not** `--max-chars` …) `` |
| Human `--allow-private --cache-dir "$SEARCH_CACHE_DIR"` writer must not satisfy fleet reader (different `q3_`) | PASS | L84: `` a human `--allow-private --cache-dir "$SEARCH_CACHE_DIR"` writer must not satisfy a later fleet reader (no `--allow-private`) via a shared `q3_` hit ``; L458 §6.3: `` must produce a **different** `q3_` than a fleet reader (default false) ``; L634 §6.12: `` human `--allow-private --cache-dir` writer must not satisfy a fleet reader `` |
| Distinct from I-6 `last.json` clobber | PASS | L84: `` Distinct from `last.json` clobber ``; L458 §6.3: `` Distinct from I-6 (`last.json` write clobber) ``; I-6 edge documented separately at L420 §6.2 |
| §6.12 test: `--allow-private` true vs default false → different `q3_` names | PASS | L634 §6.12: `` `--allow-private` true vs default false are **different** `q3_` names `` |
| §8.4 updated (`src/cache.rs` fingerprint list) | PASS | L771 §8.4 item 2 |
| §4.1 updated | PASS | L330 §4.1 |
| §6.3 updated (full `stable_hash` field contract) | PASS | L432 `### 6.3 Cache — layout, fingerprint, TTL, multi-process`; L458 full field list |
| Historical M-4 ledger superseded for this flag only | PASS | L84: `` **supersedes** the 2026-08-18 “not in hash” clause for this flag only `` |
| Round-4 post-clarify ACCEPT bullet (I-16 substance) | PASS | L85: `` `--allow-private` is a `stable_hash` boolean (human writer must not poison fleet `q3_` hits) `` |

## Facebook + I-1–I-15 regression guard

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| Facebook `must_search: false` | PASS | L54: `` Facebook stays **not** must-search ``; L198: `` Facebook: `must_search: false` ``; L339 §4.3: `` facebook `must_search=false` `` |
| I-1 X dedup in SB orchestrator | PASS | L85 ACCEPT; L101 §1.4 |
| I-2 `site:` rows require Serper/Brave consent | PASS | L85 ACCEPT; L219 §2.7 |
| I-3 xweb ban-risk required copy | PASS | L85 ACCEPT; L218 §2.7 |
| I-4 Non-Cursor init URLs + `search config set` | PASS | L85 ACCEPT; L90 §1.3 |
| I-5 One X row; list `provider`/`bucket` | PASS | L85 ACCEPT; L178 §2.5 |
| I-6 `last.json` clobber if human reuses fleet cache | PASS | L85 ACCEPT; L420 §6.2 |
| I-7 No binary fallback if git tag missing | PASS | L85 ACCEPT; L324 §3.4 |
| I-8 `search serve` Phase 2+ evaluate only | PASS | L85 ACCEPT; L660 §6.13 |
| I-9 Ops alerts PAT/secret rotation | PASS | L85 ACCEPT; L344 §4.4 |
| I-10 `cache clear` deletes future `qN_*` | PASS | L85 ACCEPT; L462 §6.3 |
| I-11 Flat-file vs SQLite acknowledged | PASS | L85 ACCEPT; L434 §6.3 trade-off |
| I-12 IDN Discourse known limit | PASS | L85 ACCEPT; L481 §6.4 |
| I-13 Metrics = usage + run_manifest | PASS | L85 ACCEPT; L344 §4.4 |
| I-14 Historical X `must_search: false` superseded markers | PASS | L73–L84 ledger bullets carry `(superseded 2026-08-31; X is \`must_search: true\` per §1.2 lock)` |
| I-15 Official-JSON `site:` fallbacks best-effort degrade | PASS | L219 §2.7 step 3 |

## Leftover gaps vs S1 / I-16 APPLY charter

None.

## Notes

- Verify is **not** a Policy F streak.
- Independent of [verify_1-pass4.md](verify_1-pass4.md); same pinned SHA, separate re-read.
- agentmemory: `VERIFY_PASS` saved (mem_mtg56byd_835babdfbf31).
