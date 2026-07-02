# Round 7 — Plan (draft)

**Status:** Plan only — **do not** start live matrix without operator direction.  
**Prior round:** [ROUND-6-GATES.md](./ROUND-6-GATES.md) — **FAIL / incomplete** (0/2 consecutive strict-clean).  
**Branch:** `enterprise-e2e/multi-host` @ `57d9042a` (required before Claude work).

---

## Preconditions

| Step | Action |
|------|--------|
| Branch | `git checkout enterprise-e2e/multi-host` — cherry-pick harness to main is **not** sufficient; run matrix from multi-host |
| Harness verify | `RTK_DISABLED=1 bash tests/scripts/test-outcome-assessment.sh` (expect ≥83/84) |
| Install | `RTK_DISABLED=1 bash scripts/install-claude.sh` |
| Ledger | Copy [ROUND-6-LEDGER.md](./ROUND-6-LEDGER.md) → `ROUND-7-LEDGER.md` or reset matrix table to **0/22** live-aligned |
| Log | Fresh `.e2e-matrix-round7-live.log` |

---

## FORCE row list (recommended priority)

### Tier 1 — blocking evidence + resume set

| Row | Slug | Why |
|-----|------|-----|
| 6 | `silver-fast` | Prior outcome FAIL (`OUT-KM-01`, `OUT-WORLD-01`) |
| 7 | `silver-test` | Missing `test-orders-integration.md` at FORCE run; outcome FAIL |
| 8 | `silver-refactor` | Missing `refactor-order-validation.md` at FORCE run; outcome FAIL |
| 11 | `silver-devops` | Missing `devops-terraform-validation.md` at FORCE run; outcome FAIL |

### Tier 2 — live outcome partial/fail (evidence present)

| Rows | Slugs | Dominant failures |
|------|-------|-------------------|
| 9–10 | benchmark, content | `OUT-SKILL-01`, `OUT-KM-01`, `OUT-WORLD-01` |
| 12–14 | deploy, canary, release | `OUT-AUTO-01`, `OUT-HANDOFF-01`, `OUT-WORLD-01` |
| 15 | review-triad | `OUT-REVIEW-01`, `OUT-HOOK-01`, planning-file-guard noise |
| 16–17 | ship-readiness, incident | `OUT-MEASURE-01`, `OUT-KM-01` |

### Tier 3 — verify / re-FORCE if multi-host scorer disagrees

| Rows | Slugs | Note |
|------|-------|------|
| 18–20 | retro, forensics, process-maintenance | Live PASS @ main; multi-host dry-run FAIL `OUT-AUTO-01` — confirm with live re-FORCE on multi-host |
| 21–22 | post-exec-gates, validate-substep | **Harness-only** on multi-host (`2d1dde43`, `0db42ac2`); no TUI if parent rows 3/4 logs + markers OK |

### Skip unless ledger drift

Rows **1–5**, **12–20** (if Tier 3 confirms PASS on multi-host live re-score): evidence SKIP acceptable only after `enterprise_e2e_outcome_row_passes` returns 0 on retained logs.

---

## Phase sequence (Round 7)

1. **Phase A** — ladder 8/8 (no new issues)
2. **Phase B** — matrix 22/22 LIVE TUI on multi-host; `SB_E2E_MATRIX_FORCE=1` for Tier 1→2→3
3. **Phase C** — `run-all-tests`, overlays dry-run, ledger reconcile **COMPLETE**, `enterprise_e2e_outcome_assess_round`, RCS ≥85
4. **Gate** — strict-clean → enables Round 8 as **1/2** consecutive (Round 5 was prior clean)

---

## Failure categories (Round 6 carry-forward)

| Class | Rows | Remediation |
|-------|------|-------------|
| **Harness** | 21, 22 | multi-host checkout (no live TUI) |
| **Missing evidence** | 7, 8, 11 | Live FORCE to completion; verify workflow files in test app |
| **Live TUI outcome** | 6, 9–17 | Live FORCE; autonomy (`OUT-AUTO-01`), KM, skill invocation in session |
| **Ledger drift** | all | Update matrix table from live log; reconcile |
| **Phase C infra** | — | `run-all-tests` 5 fail, `OUT-MEASURE-01` from `1be4447f` |

---

## Strict-clean via re-score?

**NO** for Round 6 closure. Re-score on multi-host: rows 7–17 **0/11 PASS**; rows 18–20 regress; only 21–22 improve with harness. Full strict-clean requires live Round 7 matrix on `enterprise-e2e/multi-host`.
