# Codex Enterprise E2E — Test App Product Work Audit

**Scope:** `enterprise-grade-test-app` product delivery only — **not** SB harness fixes.  
**Session window:** 2026-06-30 → 2026-07-02 (Codex-1 + Codex-2).  
**Methodology:** [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](../../docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) §5a / §5b, [WORKFLOW_E2E_MATRIX.md](https://github.com/alo-exp/enterprise-grade-test-app/blob/8482e60/docs/WORKFLOW_E2E_MATRIX.md).  
**SB worktree:** `/private/tmp/sb-codex-force4-wt` (`enterprise-e2e/codex`).  
**Ledgers:** [ROUND-CODEX-1-LEDGER.md](./ROUND-CODEX-1-LEDGER.md), [ROUND-CODEX-2-LEDGER.md](./ROUND-CODEX-2-LEDGER.md).

---

## 1. Branch isolation

| Check | Result | Evidence |
|-------|--------|----------|
| Fixture branch | **PASS** | `enterprise-e2e/round-8-codex` @ `baadf87` (8482e60 lineage) — per [ROUND-CODEX-2-LEDGER.md](./ROUND-CODEX-2-LEDGER.md) L17, methodology §4 |
| Branch created from baseline | **PASS** | Reflog: branch created from `8482e60` @ 2026-07-01T16:04:57+1000 |
| No cross-host stomp | **PASS** | Separate from `enterprise-e2e/round-8-claude`; matrix CWD `~/projects/enterprise-grade-test-app` on codex branch |
| Wrong-branch contamination | **none observed** | No ledger evidence of Claude/Cursor rows on `round-8-codex` |
| Shared-clone dirty wrong branch | **unknown** | Clone checked out `round-8-claude` at audit time; codex branch verified via `git rev-parse enterprise-e2e/round-8-codex` |

**Verdict:** Branch isolation **adequate** for Codex track. Fixture pin honored; no E2E-090 disqualifier found.

---

## 2. Commits (test app only)

**Session window commits on `enterprise-e2e/round-8-codex`:** **1**

| SHA | Date (AEST) | Author | Message | Row mapping | Product? |
|-----|-------------|--------|---------|-------------|----------|
| `baadf87` | 2026-07-01 17:10:11 | Shafqat Ullah | `chore(e2e/codex): snapshot force4 fixture artifacts on round-codex-1` | **none** — operator snapshot after R1 matrix | **No** — 560 files, mostly `.alumnium/logs/`, `graphify-out/cache/`, E2E session artifacts; not row-scoped product delivery |

**Pre-session baseline (not Codex-session authorship):**

| SHA | Date | Message | Notes |
|-----|------|---------|-------|
| `8482e60` | 2026-06-30 10:32 | `docs(e2e): document blocking autonomy outcome criteria in matrix` | Codex fixture baseline SHA |
| `826cb5c` | 2026-06-30 04:23 | `feat(e2e): ship currency milestone app, orders API, and matrix evidence` | **All 22-row product touch surfaces pre-populated** (api/, ui/, docs/, infra/) |
| `b2546d6` | 2026-06-25 | Initial enterprise E2E fixture | Smoke-v2 seed |

**Uncommitted dirty tree (post-session, vs `8482e60`):** 4 modified docs + large untracked `.planning/*` tree (ship-readiness reports, completion audits, empty `triad-currency.md` stub). **No committed row-mapped product delta** from Codex TUI.

**SB harness commits:** explicitly **excluded** from this audit (e.g. `ac4b9322`, `181f174e`, `fe8a5589`, `dfa364c9` on `enterprise-e2e/codex`).

---

## 3. Full 22-row truth table

**Evidence type legend:**

| Type | Meaning |
|------|---------|
| `pre-existing-baseline` | Matrix artifact already at `826cb5c`/`8482e60` before live row (§5a #1) |
| `live-invoke-rescore` | Codex TUI ran; harness PASS after SB rescore at cited SHA |
| `harness-rescore-only` | PASS from rescore/harness fix; **no** live re-run (§5a #2) |
| `frozen-merge` | R2 one-pass: prior log/rescore merged without live re-invoke |
| `live-invoke-ledger-strict-clean` | Ledger claims live strict-clean (Tier B/C batch) |
| `internal-inherit` | Rows 21–22 scored from parent row 3/4 evidence |
| `audit-only` | Live session produced planning/docs evidence only; no product `src/` commit (§5a #4) |

**Log paths:** `.e2e-row{N}-codex-attempt.log` in SB worktree unless noted.

| # | WF slug | Harness PASS | log_bytes | live_invoke | test_app_commit | Evidence type | Product files (expected → session state) |
|---|---------|--------------|-----------|-------------|-----------------|---------------|------------------------------------------|
| 1 | `silver-router` | R1 Pass / R2 frozen | 1,605,667 | yes | none | R1: `live-invoke-rescore` @ `80e86693`; R2: `frozen-merge` @ `71f93a3f` | `.planning/workflows/router-session.md` → **pre-existing** / routing-only |
| 2 | `silver-research` | R1 Pass / R2 frozen | 5,561,037 | yes | none | R1: `live-invoke-ledger-strict-clean` @ `80e86693`; R2: `frozen-merge` | `docs/ADR-001-runtime.md` → **pre-existing** @ `826cb5c` |
| 3 | `silver-feature` | R1 Pass / R2 frozen | 5,234,303 | yes | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `api/`, `.planning/workflows/feature-currency.md` → **pre-existing** @ `826cb5c`; live session did not commit new api delta |
| 4 | `silver-bugfix` | R1 Pass / R2 frozen | 3,973,517 | yes | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `api/src/health.js` → **pre-existing** @ `826cb5c` |
| 5 | `silver-ui` | R1 Pass / R2 frozen | 3,372,163 | yes | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `ui/src/App.jsx` → **pre-existing** @ `826cb5c` |
| 6 | `silver-fast` | R1 Pass / R2 frozen | 2,874,467 | yes | none | R1: `live-invoke-ledger-strict-clean` @ batch 65528; R2: `frozen-merge` + Tier B live | `README.md` → **pre-existing** |
| 7 | `silver-test` | R1 Pass / R2 frozen | 3,534,541 | yes | none | R1: `live-invoke-ledger-strict-clean`; R2: `frozen-merge` | `api/src/` tests → **pre-existing** |
| 8 | `silver-refactor` | R1 Pass / R2 frozen | 4,003,037 | yes (×3 attempts) | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `api/src/domain/orders/` → **pre-existing** @ `826cb5c` |
| 9 | `silver-benchmark` | R1 Pass / R2 frozen | 12,968 | yes (truncated) | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `docs/benchmarks/health.md` → **pre-existing**; log archived early |
| 10 | `silver-content` | R1 Pass / R2 frozen | 4,528,143 | yes | none | R1: `live-invoke-ledger-strict-clean`; R2: `frozen-merge` | `docs/API.md` → **pre-existing** |
| 11 | `silver-devops` | R1 Pass / R2 frozen | 1,205,733 | yes | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `infra/terraform/main.tf` → **pre-existing** |
| 12 | `silver-deploy` | R1 Pass / R2 frozen | 158,291 | yes | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `docs/DEPLOY.md` → **pre-existing** |
| 13 | `silver-canary` | R1 Pass / R2 frozen | 201,009 | yes | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `docs/CANARY.md` → **pre-existing** |
| 14 | `silver-release` | R1 Pass / R2 frozen | 135,725 | yes | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `CHANGELOG.md`, `package.json` → **pre-existing** |
| 15 | `review-triad` | R1 Pass / R2 Pass | 204,756 | yes (FORCE ×2 rounds) | none | R1: `live-invoke-rescore` → frozen @ `181f174e`; R2: `live-invoke-rescore` after Phase A ladder @ `dfa364c9` | `.planning/reviews/triad-currency.md` → **0 B stub** (§5a #4 audit-only) |
| 16 | `ship-readiness` | R1 Pass / R2 Pass | 200,599 | yes (quota abort R1) | none | R1: `harness-rescore-only` @ `fe8a5589` (`SB_E2E_ENTERPRISE_MATRIX=1`); R2: `harness-rescore-only` frozen @ force1516 | `.planning/ship-readiness/*` → uncommitted reports; **no merge-ready product commit** |
| 17 | `silver-incident` | R1 Pass / R2 frozen | 13,029 | yes (truncated) | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `docs/incidents/INC-001.md` → **pre-existing** |
| 18 | `silver-retro` | R1 Pass / R2 frozen | 138,549 | yes | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `docs/retro/RETRO-001.md` → **pre-existing** |
| 19 | `silver-forensics` | R1 Pass / R2 frozen | 173,833 | yes | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `docs/forensics/CI-001.md` → **pre-existing** (+ 4 uncommitted doc edits post-session) |
| 20 | `process-maintenance` | R1 Pass / R2 frozen | 132,333 | yes | none | R1: `live-invoke-rescore`; R2: `frozen-merge` | `docs/WORKFLOW_E2E_MATRIX.md` → **pre-existing** |
| 21 | `post-exec-gates` | R1 Pass / R2 Pass | **MISSING** | unknown | none | `internal-inherit` (parent row 3) | Parent row 3 product **pre-existing** — gate evidence not independently live |
| 22 | `validate-substep` | R1 Pass / R2 Pass | **MISSING** | unknown | none | `internal-inherit` (parent row 4) | Parent row 4 product **pre-existing** |

**Rescore audit trail (SB, for cross-check):**

- R1 initial: 18/22 — [.codex-r3-force4-rescore.log](./.codex-r3-force4-rescore.log) (rows 6–7 initially SKIP no log; later logs exist)
- R1 closure: 22/22 — [.codex-r8-force16-postmortem-rescore.log](./.codex-r8-force16-postmortem-rescore.log) (row 16 `harness-rescore-only`)
- R2 Tier C: 20/22 — [.codex-r2-matrix-rescore.log](./.codex-r2-matrix-rescore.log)
- R2 closure: 22/22 — [.codex-r2-force15-rescore.log](./.codex-r2-force15-rescore.log) (row 15 live; row 16 frozen)

---

## 4. Anti-faking checklist (§5a / Appendix C)

| # | Gate | Codex-1 | Codex-2 | Notes |
|---|------|---------|---------|-------|
| 1 | Log > 2048 B (or waiver) | **partial** | **partial** | Rows 9, 17 ~13 KB (truncated but > floor); rows 21–22 **no log** |
| 2 | Live invoke @ install_fp (not rescore-only) | **no** | **no** | R1 row 16 **rescore-only**; R2 rows 1–14,16–22 mostly **frozen-merge** |
| 3 | Fixture **commit SHA** per row | **no** | **no** | Zero row-mapped product commits; only operator `baadf87` artifact snapshot |
| 4 | Outcome PASS (no blocking partial) | **ledger yes** | **ledger yes** | After harness rescoring; not same as §5b product certification |
| 5 | Row 16 ship-readiness ↔ merge state | **unknown** | **unknown** | Checklist artifacts exist uncommitted; merge-ready not verified on test-app branch |
| 6 | Rows 21–22: parent 3/4 live strict-clean | **no** | **no** | Parents rescored on **pre-existing** product; internal inherit only |
| 7 | Correct fixture branch | **yes** | **yes** | `enterprise-e2e/round-8-codex` |
| 8 | Host-agent authorship (not operator-only) | **partial** | **partial** | Codex TUI invoked; product deliverables authored **before** session @ `826cb5c` |

**§5a disqualifiers observed:**

| # | Category | Present? |
|---|----------|----------|
| 1 | Pre-existing evidence | **yes** — all implement-row touch surfaces @ `826cb5c` before Codex live |
| 2 | Harness rescoring without live rerun | **yes** — R1 row 16; R2 rows 1–14,16–22 frozen; many R1 rows `live-invoke-rescore` |
| 3 | Timeout / empty logs | **no** for scored rows (21–22 missing logs) |
| 4 | Audit-only sessions | **yes** — row 1 routing-only; row 15 stub triad; row 16 planning docs without product commit |
| 5 | Install-skip first certification | **no** (Codex used live TUI, not `ROW_ALREADY_PASSED` skip) |
| 6 | Internal gates without parent live work | **yes** — rows 21–22 inherit pre-existing parent product |

---

## 5. Cumulative product outcome (files per row)

All paths from [WORKFLOW_E2E_MATRIX.md](https://github.com/alo-exp/enterprise-grade-test-app/blob/8482e60/docs/WORKFLOW_E2E_MATRIX.md). **Authoring SHA** = git commit that created the artifact (not Codex session).

| # | Expected evidence path | Authoring SHA | Codex session delta |
|---|------------------------|---------------|---------------------|
| 1 | `.planning/workflows/router-session.md` | unknown / absent at `8482e60` | routing-only; no new commit |
| 2 | `docs/ADR-001-runtime.md` | `826cb5c` | none |
| 3 | `.planning/workflows/feature-currency.md`, `api/` | `826cb5c` | none committed |
| 4 | `.planning/workflows/bugfix-health.md`, `api/src/health.js` | `826cb5c` | none |
| 5 | `ui/src/App.jsx` | `826cb5c` | none |
| 6 | `README.md` | `826cb5c` | none |
| 7 | `api/src/` (integration tests) | `826cb5c` | none |
| 8 | `api/src/domain/orders/` | `826cb5c` | none |
| 9 | `docs/benchmarks/health.md` | `826cb5c` | none |
| 10 | `docs/API.md` | `826cb5c` | none |
| 11 | `infra/terraform/main.tf` | `826cb5c` | none |
| 12 | `docs/DEPLOY.md` | `826cb5c` | none |
| 13 | `docs/CANARY.md` | `826cb5c` | none |
| 14 | `CHANGELOG.md`, `package.json` | `826cb5c` | none |
| 15 | `.planning/reviews/triad-currency.md` | **0 B stub** (session) | audit-only stub |
| 16 | `.planning/ship-readiness/` | uncommitted reports | audit-only |
| 17 | `docs/incidents/INC-001.md` | `826cb5c` | none |
| 18 | `docs/retro/RETRO-001.md` | `826cb5c` | none |
| 19 | `docs/forensics/CI-001.md` | `826cb5c` | 4 doc files modified uncommitted |
| 20 | `docs/WORKFLOW_E2E_MATRIX.md` | `8482e60` | none |
| 21 | (internal — row 3 gates) | `826cb5c` parent | inherit only |
| 22 | (internal — row 4 substep) | `826cb5c` parent | inherit only |

**Net product commits attributable to Codex host-agent during session:** **0**.  
**Operator snapshot:** `baadf87` (E2E artifacts, not application code).

---

## 6. Gaps

1. **No row-scoped product commits** — §5b product-delta gate failed for all implement rows; matrix PASS rests on pre-seeded `826cb5c` + harness rescoring.
2. **R1 row 16** — PASS via `fe8a5589` LEDGER_MISMATCH harness fix without live re-run (quota wall); not product work.
3. **R2 confirmation round** — 20/22 rows **frozen-merge** from Tier C rescore; only row 15 had late live FORCE; row 16 frozen from R1 force1516 rescore.
4. **Row 15 triad** — `.planning/reviews/triad-currency.md` remains **0 bytes** after FORCE retries (ledger notes stub evidence).
5. **Rows 21–22** — no attempt logs; internal inherit from parents that did not live-author product at current baseline.
6. **Rows 9, 17** — ~13 KB logs suggest early session abort/archive; product artifacts pre-existing.
7. **Methodology doc in worktree** — older copy lacks §5a/§5b; canonical rules in main-repo [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](../../docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) @ `main`.
8. **Uncommitted `.planning/` sprawl** — ship-readiness, completion audits, SPEC/PLAN files not committed; cannot map cleanly to row SHAs.

---

## 7. Verdict

The Codex enterprise E2E session **validated SB harness and outcome scoring** on a **pre-seeded test app** (`826cb5c` / `8482e60`), not **fresh Codex-authored product delivery**. Harness ledgers record **22/22 PASS** for both Codex-1 and Codex-2, but under §5a/§5b **product-work certification** the session **does not qualify as strict-clean product delivery**: every implement-row touch surface existed before the first live Codex invoke; the only fixture-branch commit (`baadf87`) is an operator E2E artifact snapshot; row 16 passed on **harness-rescore-only** (`fe8a5589` / `SB_E2E_ENTERPRISE_MATRIX=1`); Codex-2 reused **frozen-merge** for 20/22 rows; rows 15–16 and 21–22 are **audit-only** or **internal-inherit** without committed product deltas. **Honest product-work score: 0/22 rows with Codex-session committed product authorship.** Harness matrix score (22/22 rescored/frozen) remains valid for SB release gating but must not be conflated with test-app product proof. For cross-host comparison, treat this like Cursor-1/2 void patterns documented in methodology Appendix D — a **Real certification** would require fixture reset to `8482e60`, live rows with **committed per-row deltas**, and no harness-rescore-only PASS claims.

---

*Audit generated 2026-07-02. Evidence: test-app git @ `/Users/shafqat/projects/enterprise-grade-test-app`, SB logs @ `/private/tmp/sb-codex-force4-wt/.e2e-row*-codex-attempt.log`, rescore logs @ `.planning/enterprise-e2e/.codex-r*.log`.*
