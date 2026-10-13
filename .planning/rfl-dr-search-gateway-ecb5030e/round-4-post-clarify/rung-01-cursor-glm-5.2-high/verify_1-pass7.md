model: composer-2.5

**Subagent:** `sb-composer-2-5-high`  
**Phase:** VERIFY-ONLY pass 1/2 (`rung_1_verify_1`, post ACCEPT-apply of V1 / I-19)  
**Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`  
**SHA-256:** `a53d81dfd58d6969ba4984ef88a5d6ee1355c7b40dc1b64f05a87478ae387bd4` (verified via `shasum -a 256`)  
**Graphify:** `graphify query "doctor.rs bounded patch Modify checklist" --budget 2000` (98 nodes; oriented doctor/bounded-patch contract)  
**Apply ref:** [APPLY.md](APPLY.md) pass 7 (V1 / I-19) · **Prior verify:** [verify_1-pass6.md](verify_1-pass6.md)

## Verdict

**VERIFY_PASS** — V1 / I-19 APPLY confirmed at pinned SHA: `src/doctor.rs` is on §6.1 bounded patch, §8.1 Modify (~L742), and §8.4 item 8 (~L778) with the full bounded doctor contract. Facebook `must_search: false`, X/xweb/search-cli gateway, and U1/U2 locks remain intact.

## SHA gate

| Check | Status | Evidence |
|-------|--------|----------|
| Plan SHA-256 matches charter | PASS | `shasum -a 256` → `a53d81dfd58d6969ba4984ef88a5d6ee1355c7b40dc1b64f05a87478ae387bd4` |

## V1 / I-19 — `src/doctor.rs` on §8.1 / §8.4 Modify checklists (bounded doctor patch)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| L85 ACCEPT records I-19 | PASS | L85: `` `src/doctor.rs` is on the §8.1/§8.4 Modify checklists (bounded doctor patch). `` |
| §6.1 (~L369) bounded patch | PASS | L369: `` **`src/doctor.rs`:** bounded patch only — pings go through `bucket::acquire`; **must honor `--quota-dir`**; slot-exempt; skip `-d`-requiring providers (`doctor_skip_requires_domain`); registries = 4 acquires; `doctor_rate_limited` warning (M5). Not a rewrite. `` |
| §8.1 Modify (~L742) | PASS | L742: `` **Modify** `src/doctor.rs` — bounded: pings through `bucket::acquire(..., collector)`; honor `--quota-dir`/`--cache-dir`; slot-exempt; `doctor_skip_requires_domain` for discourse; registries = 4 acquires; `doctor_rate_limited` warning (M5) `` |
| §8.4 item 8 (~L778) | PASS | L778: `` **`src/doctor.rs`** — bounded: acquire pings, honor `--quota-dir`/`--cache-dir`, slot-exempt, `doctor_skip_requires_domain`, registries=4, `doctor_rate_limited` `` |

## Bounded contract (all required terms at L369, L742, L778)

| Term | Status | Evidence |
|------|--------|----------|
| acquire pings (`bucket::acquire`) | PASS | L369, L742, L778 |
| honor `--quota-dir` / `--cache-dir` | PASS | L369 (`--quota-dir`); L742/L778 (both flags) |
| slot-exempt | PASS | L369, L742, L778 |
| `doctor_skip_requires_domain` | PASS | L369, L742, L778 |
| registries = 4 acquires | PASS | L369, L742, L778 |
| `doctor_rate_limited` warning (M5) | PASS | L369, L742, L778 |

## Regression guard (not full U1/U2 re-verify)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| Facebook `must_search: false` | PASS | L54: `` Facebook stays **not** must-search ``; L198: `` Facebook: `must_search: false` ``; L339: `` facebook `must_search=false` `` |
| X / xweb intact | PASS | L54/L101: X `must_search: true`, `mvp: true`, union legs include `-p xweb`; L339: xweb bucket/provider on one X row |
| search-cli gateway intact | PASS | L55: `` search-cli remains the only gateway ``; L124 §2.2 orchestrator → `search` CLI |
| U1 (`--cache-ttl` fork ADD) not reverted | PASS | L85: `` `--cache-ttl` is a Phase 1 fork ADD (not upstream-exposed) `` |
| U2 (`SB_DR_FLEET_SLOTS` orchestrator-only) not reverted | PASS | L85: `` `SB_DR_FLEET_SLOTS` is orchestrator-only (fork does not read it) ``; L661 §6.13 same |

## Leftover gaps vs V1 / I-19 APPLY charter

None.

## Notes

- Verify is **not** a Policy F streak.
- Parent may proceed to `verify_2` pass 7 + orchestrator greps.
