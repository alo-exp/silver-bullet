model: composer-2.5

**Subagent:** `sb-composer-2-5-high`  
**Phase:** VERIFY-ONLY pass 1/2 (`rung_1_verify_1`, post ACCEPT-apply of X1–X3 / I-27–I-29)  
**Artifact:** `/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md`  
**SHA-256:** `763b4ada2509833124c682bfa58c3308a41bd0d01a2f77242d4af3491364dcdb` (verified via `shasum -a 256`)  
**Graphify:** `graphify query "dr search gateway plan quota-dir max-chars doctor.rs X1 X2 X3"` (182 nodes; oriented quota/fingerprint/doctor contract)  
**Apply ref:** [APPLY.md](APPLY.md) pass 9 (X1–X3 / I-27–I-29) · **Prior verify:** [verify_1-pass8.md](verify_1-pass8.md)

## Verdict

**VERIFY_PASS** — X1–X3 / I-27–I-29 APPLY confirmed at pinned SHA. All three work items present at cited plan lines; regression guards (Facebook `must_search: false`, X/xweb/search-cli gateway, `doctor.rs` checklist) intact.

## SHA gate

| Check | Status | Evidence |
|-------|--------|----------|
| Plan SHA-256 matches charter | PASS | `shasum -a 256` → `763b4ada2509833124c682bfa58c3308a41bd0d01a2f77242d4af3491364dcdb` |

## X1–X3 / I-27–I-29 APPLY confirmation

| Item | Status | Evidence (plan) |
|------|--------|-----------------|
| X1/I-27 §4.4 — unset `--quota-dir` default `~/.config/silver-bullet/search-quota/`; bare `search doctor` spends fleet tokens; do **not** invent `$HOME/.cache/search` as doctor quota default; hazard is shared fleet quota | PASS | L344: `unset-flag --quota-dir default is ~/.config/silver-bullet/search-quota/ (same as fleet); a bare search doctor spends **fleet** bucket tokens. Do not invent a $HOME/.cache/search quota default` · L413: `Default unset for humans → ~/.config/silver-bullet/search-quota/ (create 0700; **not** $HOME/.cache/search / ProjectDirs "search"` |
| X2/I-28 §6.12 — `--max-chars` is **not** a fingerprint field; same query + `-p` + `-d` + two `--max-chars` values → same `q3_`; stored body untruncated; emit truncates to reader's `--max-chars` | PASS | L458: `**Do not** put --max-chars in the hash (missing High+ item 10 M-4): truncation is applied at **emit** (after cache store/load), not before CachedEntry store — stored body is untruncated; a smaller --max-chars reader truncates locally` · L634: `--max-chars is **not** a fingerprint field (same query + -p + -d + two --max-chars values → same q3_; stored body untruncated; emit truncates to the reader's --max-chars)` · L773: `q3_ fingerprint includes … (**not** count, **not** TTL, **not** --max-chars` |
| X3/I-29 §6.12 — doctor honors `--quota-dir`; `doctor_skip_requires_domain`; registries=4 acquire; `doctor_rate_limited`; YouTube doctor ping spends 1 of 100 | PASS | L641: `doctor: honors --quota-dir (does not invent a $HOME/.cache/search quota default); doctor_skip_requires_domain for discourse (no placeholder host); registries doctor ping = 4 acquire; RateLimited → doctor_rate_limited (not false-unhealthy); YouTube doctor ping spends 1 of 100 under --quota-dir` · L344: `registries ping is 4 acquire("registries", cost=1) (one per HTTP subrequest); a YouTube doctor ping spends 1 of 100 **in the fleet quota dir**; doctor_rate_limited is not a false-unhealthy key` · L743: `**Modify** src/doctor.rs — bounded: pings through bucket::acquire(..., collector); honor --quota-dir/--cache-dir; slot-exempt; doctor_skip_requires_domain for discourse; registries = 4 acquires; doctor_rate_limited warning (M5)` |

## L85 ledger rollup (pass 9 ACCEPT summary)

| Term | Status | Evidence |
|------|--------|----------|
| §4.4 doctor risk is shared fleet quota (not `$HOME/.cache/search`) | PASS | L85: `§4.4 doctor risk is shared fleet quota (not $HOME/.cache/search)` |
| `--max-chars` emit/truncation test in §6.12 | PASS | L85: `--max-chars emit/truncation test in §6.12` |
| doctor.rs behavior tests in §6.12 | PASS | L85: `doctor.rs behavior tests in §6.12` |

## Regression guard (not full W1 re-verify)

| Check | Status | Evidence (plan) |
|-------|--------|----------|
| Facebook `must_search: false` | PASS | L54: `Facebook stays **not** must-search (cataloged exclude)` · L198: `Facebook: must_search: false` · L339: `facebook must_search=false` |
| X / xweb intact | PASS | L54/L101: X `must_search: true`, `mvp: true`, union legs include `-p xweb`; L339: `xweb bucket/provider present on the **one** X row` |
| search-cli gateway intact | PASS | L55: `search-cli remains the only gateway` · L56: `Fork is the gateway` |
| `doctor.rs` checklist not reverted | PASS | L85: `src/doctor.rs is on the §8.1/§8.4 Modify checklists` · L743: `**Modify** src/doctor.rs` · L779: `**src/doctor.rs** — bounded: acquire pings, honor --quota-dir/--cache-dir, slot-exempt, doctor_skip_requires_domain, registries=4, doctor_rate_limited` |

## Leftover gaps vs X1–X3 APPLY charter

None.

## Notes

- Verify is **not** a Policy F streak.
- Parent may proceed to `verify_2` pass 9 + orchestrator greps.
