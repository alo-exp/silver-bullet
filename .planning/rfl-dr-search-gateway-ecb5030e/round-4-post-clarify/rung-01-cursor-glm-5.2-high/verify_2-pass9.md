model: composer-2.5

**Subagent:** `sb-composer-2-5-high`  
**Phase:** VERIFY-ONLY pass 2/2 (`verify_2`, independent of verify_1)  
**Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`  
**SHA-256:** `763b4ada2509833124c682bfa58c3308a41bd0d01a2f77242d4af3491364dcdb` (verified via `shasum -a 256`)  
**Graphify:** `graphify query "dr_search_gateway plan X1 X2 X3 quota-dir max-chars doctor"` (39 nodes; oriented quota-dir / doctor / fingerprint contract)  
**Apply ref:** X1–X3 / I-27–I-29 (round-4 post-clarify rung 1 pass 9)

## Verdict

**VERIFY_PASS** — Independent re-read at pinned SHA confirms all three X1–X3 ACCEPT-apply items (I-27–I-29) with file:line evidence. L85 rollup mentions §4.4 shared fleet quota, `--max-chars` emit/truncation test, and doctor.rs behavior tests. Facebook `must_search: false`, X/xweb/search-cli gateway, and `src/doctor.rs` §8.1/§8.4 checklists remain intact.

## SHA gate

| Check | Status | Evidence |
|-------|--------|----------|
| Plan SHA-256 matches charter | PASS | `shasum -a 256` → `763b4ada2509833124c682bfa58c3308a41bd0d01a2f77242d4af3491364dcdb` |

## X1 / I-27 — §4.4 doctor quota-dir default (shared fleet quota)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| L85 ledger records X1 | PASS | L85: `` §4.4 doctor risk is shared fleet quota (not `$HOME/.cache/search`) `` |
| §4.4 unset `--quota-dir` default | PASS | L344: `` unset-flag `--quota-dir` default is `~/.config/silver-bullet/search-quota/` (same as fleet) `` |
| §4.4 bare `search doctor` spends fleet tokens | PASS | L344: `` a bare `search doctor` spends **fleet** bucket tokens `` |
| §4.4 do not invent `$HOME/.cache/search` quota default | PASS | L344: `` Do not invent a `$HOME/.cache/search` quota default `` |
| §4.4 hazard is shared fleet quota | PASS | L344: `` a YouTube doctor ping spends 1 of 100 **in the fleet quota dir** `` |
| §6.2 CLI default echoes | PASS | L413: `` Default unset for humans → `~/.config/silver-bullet/search-quota/` (create 0700; **not** `$HOME/.cache/search` / ProjectDirs `"search"` `` |
| §2.2 SEARCH_QUOTA_DIR resolve | PASS | L125: `` `SEARCH_QUOTA_DIR` resolve: `~/.config/silver-bullet/search-quota/` (create 0700); override `--quota-dir` / `SEARCH_QUOTA_DIR`; **never** `$HOME/.cache/search` / ProjectDirs `"search"`. `` |

## X2 / I-28 — §6.12 `--max-chars` not a fingerprint field

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| L85 ledger records X2 | PASS | L85: `` `--max-chars` emit/truncation test in §6.12 `` |
| §6.6 `--max-chars` excluded from hash | PASS | L458: `` **Do not** put `--max-chars` in the hash (missing High+ item 10 M-4): truncation is applied at **emit** (after cache store/load), not before `CachedEntry` store — stored body is untruncated; a smaller `--max-chars` reader truncates locally. `` |
| §6.12 same query + two `--max-chars` → same `q3_` | PASS | L634: `` `--max-chars` is **not** a fingerprint field (same query + `-p` + `-d` + two `--max-chars` values → same `q3_`; stored body untruncated; emit truncates to the reader's `--max-chars`) `` |
| §8.1 cache.rs checklist echoes | PASS | L773: `` `q3_` fingerprint includes `-p`+canonicalized domains+filters+`--allow-private` (**not** count, **not** TTL, **not** `--max-chars`; intra-list `0x1F`) `` |

## X3 / I-29 — §6.12 doctor.rs behavior tests (~L641)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| L85 ledger records X3 | PASS | L85: `` doctor.rs behavior tests in §6.12 `` |
| §6.12 honors `--quota-dir` | PASS | L641: `` doctor: honors `--quota-dir` (does not invent a `$HOME/.cache/search` quota default) `` |
| §6.12 `doctor_skip_requires_domain` | PASS | L641: `` `doctor_skip_requires_domain` for discourse (no placeholder host) `` |
| §6.12 registries = 4 acquire | PASS | L641: `` registries doctor ping = 4 `acquire` `` |
| §6.12 `doctor_rate_limited` | PASS | L641: `` `RateLimited` → `doctor_rate_limited` (not false-unhealthy) `` |
| §6.12 YouTube doctor ping 1 of 100 | PASS | L641: `` YouTube doctor ping spends 1 of 100 under `--quota-dir` `` |
| §6.1 doctor.rs bounded patch | PASS | L369: `` **`src/doctor.rs`:** bounded patch only — pings go through `bucket::acquire`; **must honor `--quota-dir`**; slot-exempt; skip `-d`-requiring providers (`doctor_skip_requires_domain` …) `` |
| §8.1 Modify checklist | PASS | L743: `` **Modify** `src/doctor.rs` — bounded: pings through `bucket::acquire(..., collector)`; honor `--quota-dir`/`--cache-dir`; slot-exempt; `doctor_skip_requires_domain` for discourse; registries = 4 acquires; `doctor_rate_limited` warning (M5) `` |
| §8.4 item 8 checklist | PASS | L779: `` **`src/doctor.rs`** — bounded: acquire pings, honor `--quota-dir`/`--cache-dir`, slot-exempt, `doctor_skip_requires_domain`, registries=4, `doctor_rate_limited` `` |

## L85 rollup

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| §4.4 doctor risk is shared fleet quota (not `$HOME/.cache/search`) | PASS | L85: `` §4.4 doctor risk is shared fleet quota (not `$HOME/.cache/search`) `` |
| `--max-chars` emit/truncation test in §6.12 | PASS | L85: `` `--max-chars` emit/truncation test in §6.12 `` |
| doctor.rs behavior tests in §6.12 | PASS | L85: `` doctor.rs behavior tests in §6.12 `` |
| `src/doctor.rs` on §8.1/§8.4 Modify checklists | PASS | L85: `` `src/doctor.rs` is on the §8.1/§8.4 Modify checklists (bounded doctor patch) `` |

## Regression guard (Facebook / X / gateway / doctor.rs)

| Check | Status | Evidence (plan) |
|-------|--------|-----------------|
| Facebook `must_search: false` | PASS | L54: `` Facebook stays **not** must-search (cataloged exclude) ``; L198: `` Facebook: `must_search: false` ``; L339: `` facebook `must_search=false` `` |
| X / xweb intact | PASS | L54/L101: X `must_search: true`, `mvp: true`, union legs include `-p xweb`; L120: one X row with list `provider`/`bucket`; L339: xweb bucket/provider present on the **one** X row |
| search-cli gateway intact | PASS | L48: `` **one** gateway ``; L56: `` **Fork is the gateway.** No `search_gateway.py` adapters. ``; L55: `` pin exact binary `search` / `SB_SEARCH_BIN` `` |
| `src/doctor.rs` checklist not reverted | PASS | L85 ledger; L369 §6.1 bounded patch; L743 §8.1 Modify; L779 §8.4 item 8 |
| `"upstream already exposes"` absent | PASS | Full-plan scan: 0 hits |

## Leftover gaps vs X1–X3 APPLY charter

None.

## Notes

- Verify is **not** a Policy F streak.
- Independent of verify_1-pass9; separate re-read at SHA `763b4ada…`.
