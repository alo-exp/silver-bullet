model: composer-2.5

**Subagent:** `sb-composer-2-5-high`  
**Phase:** VERIFY-ONLY pass 2/2 (`verify_2`, independent of verify_1)  
**Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`  
**SHA-256:** `bd706ef2450092fcfe1e10aef788ffab290a8d761b6b87e0024c751155f6819c` (verified via `shasum -a 256`)  
**Graphify:** `graphify query "dr search gateway plan AA1 AA2 serper x acquire cache_ttl_default_300s SB_DR_FLEET"` (39 nodes; oriented AA1/AA2 acquire + cache_ttl fleet warning)  
**Apply ref:** AA1 / I-31, AA2 / I-32 (round-4 post-clarify rung 1 pass 12)

## Verdict

**VERIFY_PASS** — Independent re-read at pinned SHA confirms AA1 / I-31 and AA2 / I-32 APPLY: §6.12 (~L640) asserts `acquire("x", …, collector)` before HTTP and `acquire("serper", …, collector)` before POST with brave/xweb acquire assertions intact; §6.12 (~L645) requires the positive `SB_DR_FLEET=1` + unset TTL `cache_ttl_default_300s` case and the negative non-fleet unset-TTL must-not-emit case. L85 rollup records both. Regression guards (Facebook `must_search: false`, X/xweb/search-cli gateway, `SB_DR_FLEET_SLOTS` fork-read superseded by I-18) remain intact.

## SHA gate

| Check | Status | Evidence |
|-------|--------|----------|
| Plan SHA-256 matches charter | PASS | `shasum -a 256` → `bd706ef2450092fcfe1e10aef788ffab290a8d761b6b87e0024c751155f6819c` |

## AA1 / I-31 — §6.12 per-provider acquire (~L640)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| **x** `acquire("x", …, collector)` before HTTP | PASS | L640: `` **x** official `search/recent` skips without bearer, `acquire("x", …, collector)` before HTTP `` |
| **serper** `acquire("serper", …, collector)` before POST | PASS | L640: `` **serper** `acquire("serper", …, collector)` before POST `` |
| **brave** acquire assertion remains | PASS | L640: `` **brave** `acquire("brave", …, collector)` before HTTP (bucket exists under `--quota-dir`) `` |
| **xweb** acquire assertion remains | PASS | L640: `` **xweb** unpaid HTTP skips without guest/cookies, acquires `xweb` bucket, never execs `twitter`/`opencli`/`bird` `` |
| §8 bounded patches echo serper/x acquire | PASS | L732: `` `acquire("x", …, collector)` ``; L733: `` `acquire("xweb", …, collector)` ``; L741: `` call `bucket::acquire("serper", …, collector)` before POST `` |

## AA2 / I-32 — §6.12 `cache_ttl_default_300s` negative test (~L645)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| Positive fleet case: `SB_DR_FLEET=1` + unset TTL emits warning | PASS | L645: `` `SB_DR_FLEET=1` + unset TTL emits `cache_ttl_default_300s` in `warnings` `` |
| Negative human-run case: no `SB_DR_FLEET` + TTL unset must **not** emit | PASS | L645: `` a run without `SB_DR_FLEET` and with TTL unset must **not** emit `cache_ttl_default_300s` `` |
| main.rs fleet TTL warning wiring present | PASS | L737: `` `SB_DR_FLEET=1` + default 300s TTL → `warnings` `cache_ttl_default_300s` `` |

## L85 rollup

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| §6.12 serper/x acquire tests recorded | PASS | L85: `` §6.12 serper/x acquire tests; human-run `cache_ttl_default_300s` negative test. `` |
| Human-run `cache_ttl_default_300s` negative test recorded | PASS | L85 (same line): `` human-run `cache_ttl_default_300s` negative test. `` |
| brave acquire test in §6.12 (related rollup) | PASS | L85: `` brave acquire test in §6.12. `` |

## Regression guard (Facebook / X / gateway / I-18)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| Facebook `must_search: false` | PASS | L54: `` Facebook stays **not** must-search (cataloged exclude) ``; L198: `` Facebook: `must_search: false` ``; L339: `` facebook `must_search=false` `` |
| X must-search / xweb intact | PASS | L54: `` Catalog `x`: `must_search: true`, `mvp: true` ``; L101: union legs include `-p xweb`; L120: one X row with list `provider`/`bucket`; L339: xweb bucket/provider on the **one** X row |
| search-cli gateway intact | PASS | L55: `` pin exact binary `search` / `SB_SEARCH_BIN` ``; L56: `` **Fork is the gateway.** No `search_gateway.py` adapters. `` |
| `SB_DR_FLEET_SLOTS` fork-read superseded (I-18 / Y1) | PASS | L73: `` `SB_DR_FLEET_SLOTS` is orchestrator-only; the fork does **not** read it ``; L85: `` §1.2 H1 `SB_DR_FLEET_SLOTS` fork-read is superseded (I-18); fork does not read it. ``; L662: `` the fork does **not** read it `` |
| Forbidden phrase `` Fork may read `SB_DR_FLEET_SLOTS` `` absent | PASS | Full-plan scan: 0 hits |
| `src/doctor.rs` checklist not reverted | PASS | L85: `` `src/doctor.rs` is on the §8.1/§8.4 Modify checklists ``; L743 §8 Modify |
| `"upstream already exposes"` absent | PASS | Full-plan scan: 0 hits |

## Leftover gaps vs AA1–AA2 APPLY charter

None.

## Notes

- Verify is **not** a Policy F streak.
- Independent of verify_1-pass12; separate re-read at SHA `bd706ef2450092fcfe1e10aef788ffab290a8d761b6b87e0024c751155f6819c`.
- Y1 / I-30 verifies already PASS at prior SHA `f08aef05…`; not re-run in this pass.
