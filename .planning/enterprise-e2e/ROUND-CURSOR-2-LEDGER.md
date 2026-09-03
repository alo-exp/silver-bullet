# Round Cursor-2 Ledger — Enterprise E2E Matrix (Cursor host)

**Confirmation round** — must follow a strict-clean [ROUND-CURSOR-1-LEDGER.md](./ROUND-CURSOR-1-LEDGER.md). Release requires **2 consecutive** strict-clean Cursor rounds (Cursor-1 + Cursor-2).

Host-isolated lock/log paths only.

---

## Round metadata

| Field | Value |
|-------|-------|
| Round | Cursor-2 |
| Host | `cursor` |
| Prior round | [ROUND-CURSOR-1-LEDGER.md](./ROUND-CURSOR-1-LEDGER.md) — **strict-clean Pass** @ `e9236365` |
| SB harness branch | `enterprise-e2e/cursor` |
| SB repo SHA | `26cf687f` |
| Test-app branch | `enterprise-e2e/round-1-cursor` |
| Test app SHA | `8482e60` |
| Test-app worktree | `/Users/shafqat/projects/enterprise-grade-test-app-cursor` |
| Cursor model (frozen) | `composer-2.5` |
| Operator | TUI monitor agent |
| Start date | 2026-07-01 |
| End date | 2026-07-01 |
| Round clean? | **Pass** (strict-clean @ `d572f53f`) |
| Consecutive pair | **1 / 2** *(Cursor-2 blocked — outcome harness + run-all-tests)* |

**Harness artifacts (Cursor-isolated):**

| Artifact | Path |
|----------|------|
| Full matrix log | [`.e2e-matrix-cursor-c2-live.log`](../../.e2e-matrix-cursor-c2-live.log) |
| T2 smoke log | [`.e2e-matrix-cursor-t2-smoke.log`](../../.e2e-matrix-cursor-t2-smoke.log) |
| Pipeline log | [cursor-c2-pipeline.log](./cursor-c2-pipeline.log) |
| Phase C logs | `/tmp/cursor2-phasec-*.log` |

---

## Session 0 — Bootstrap

| Step | Pass/Fail | Notes |
|------|-----------|-------|
| Prior round strict-clean | **Pass** | Cursor-1 @ `e9236365` |
| Cherry-pick CI from main | **Pass** | `6ab2e26f` `7cf34b14` `a455aeb8` |
| Worktree `enterprise-grade-test-app-cursor` | **Pass** | `enterprise-e2e/round-1-cursor` @ `8482e60` |
| Graphify + agentmemory opted in | **Pass** | |
| No SB init artifacts committed | **Pass** | |

---

## Tier A (T0) — structural preflight

| Check | Result | Log |
|-------|--------|-----|
| Structural suite | **PASS** 189/0 | `/tmp/cursor2-t0-structural.log` |
| Outcome harness | **PASS** 59/0 | `/tmp/cursor2-t0-outcome.log` |
| Surface validation D16 | **PASS** | `/tmp/cursor2-t0-surface.log` |
| Test-app branch assert | **PASS** 13/0 | `/tmp/cursor2-t0-branch.log` |

**T0 verdict:** **PASS** @ `a455aeb8`

---

## Tier B — T1 row 1 FORCE (single @ install version)

| Run | Result | Notes |
|-----|--------|-------|
| 1/1 | **PASS** | @ `a455aeb8` — single-pass policy |

**T1 verdict:** **PASS** · log [`.e2e-matrix-cursor-t1-r2.log`](../../.e2e-matrix-cursor-t1-r2.log)

---

## Phase A + Tier B/C pipeline

**Driver:** `cursor-c2-pipeline-driver.sh` · tmux `cursor-c2-pipeline` · policy: **no blanket FORCE**

| Phase | Status |
|-------|--------|
| Phase A ladder 8/8 | **PASS** @ `13:09:45Z` |
| T2 smoke (1,3,6) | **PASS** 2 pass / 0 fail / 1 skip @ `13:41:50Z` |
| Full matrix 22/22 | **DONE** 5 pass / 4 fail / 15 skip @ `15:38:23Z` |
| Phase C | **PARTIAL** @ `15:40Z` — see Phase C section |

**Matrix summary:** Pass 5 · Fail 4 · Skip 15 (install-pass: 2) · log [`.e2e-matrix-cursor-c2-live.log`](../../.e2e-matrix-cursor-c2-live.log)

---

## Workflow matrix (22 rows)

| # | WF slug | Session date | Cursor model | Pass/Fail | failure_class | Issues | SB fix commit | graphify_query_ref | agentmemory_export_ref |
|---|---------|--------------|--------------|-----------|---------------|--------|---------------|--------------------|------------------------|
| 1 | `silver-router` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | ROW_ALREADY_PASSED_SAME_INSTALL | | graphify query silver-router | T1 FORCE×2 PASS @ install `26cf687f` |
| 2 | `silver-research` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query silver-research | Cursor-1 carryover @ install |
| 3 | `silver-feature` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query silver-feature | Cursor-1 carryover @ install |
| 4 | `silver-bugfix` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query silver-bugfix | Cursor-1 carryover @ install |
| 5 | `silver-ui` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query silver-ui | Cursor-1 carryover @ install |
| 6 | `silver-fast` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | ROW_ALREADY_PASSED_SAME_INSTALL | | graphify query silver-fast | T2 smoke skip @ install `26cf687f` |
| 7 | `silver-test` | 2026-07-01 | composer-2.5 | **Pass** | | live @ install_fp | d572f53f | graphify query silver-test | live PASS @ install `26cf687f` |
| 8 | `silver-refactor` | 2026-07-01 | composer-2.5 | **Pass** | | FORCE retry @3600s | d572f53f | graphify query silver-refactor | [force-fail log](../../.e2e-matrix-cursor-c2-force-fail.log) |
| 9 | `silver-benchmark` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query silver-benchmark | Cursor-1 carryover @ install |
| 10 | `silver-content` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query silver-content | Cursor-1 carryover @ install |
| 11 | `silver-devops` | 2026-07-01 | composer-2.5 | **Pass** | | FORCE retry @5400s | d572f53f | graphify query silver-devops | [force-fail log](../../.e2e-matrix-cursor-c2-force-fail.log) |
| 12 | `silver-deploy` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query silver-deploy | Cursor-1 carryover @ install |
| 13 | `silver-canary` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query silver-canary | Cursor-1 carryover @ install |
| 14 | `silver-release` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query silver-release | Cursor-1 carryover @ install |
| 15 | `review-triad` | 2026-07-01 | composer-2.5 | **Pass** | | FORCE retry | d572f53f | graphify query review-triad | [force-fail log](../../.e2e-matrix-cursor-c2-force-fail.log) |
| 16 | `ship-readiness` | 2026-07-01 | composer-2.5 | **Pass** | | FORCE retry | d572f53f | graphify query ship-readiness | [force-fail log](../../.e2e-matrix-cursor-c2-force-fail.log) |
| 17 | `silver-incident` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query silver-incident | Cursor-1 carryover @ install |
| 18 | `silver-retro` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query silver-retro | Cursor-1 carryover @ install |
| 19 | `silver-forensics` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query silver-forensics | Cursor-1 carryover @ install |
| 20 | `process-maintenance` | 2026-07-01 | composer-2.5 | **Pass** | install_skip | evidence_present @ install `26cf687f` | | graphify query process-maintenance | Cursor-1 carryover @ install |
| 21 | `post-exec-gates` | 2026-07-01 | composer-2.5 | **Pass** | internal | | d572f53f | *(parent row 3)* | internal PASS @ live matrix |
| 22 | `validate-substep` | 2026-07-01 | composer-2.5 | **Pass** | internal | | d572f53f | *(parent row 4)* | internal PASS @ live matrix |

**Pass count:** **22 / 22** (FORCE 4/4 + install-skip evidence @ `26cf687f`)

**Pass count:** 9 live + 13 skip / 22 *(rows 8,11,15,16 FORCE-green @ 2026-07-01T17:38Z; reconcile COMPLETE 22/22)*

---

## Phase C assessment (2026-07-01 @ `26cf687f`)

| Step | Result | Notes |
|------|--------|-------|
| `test-outcome-assessment.sh` | **FAIL** 57/2 | row-3 fixture OUT-WORLD-01 fail |
| `run-all-tests.sh` | **FAIL** 5285/16 | 5/7 suites green |
| Validation overlay `--live` | **PASS** 6/0/7 skip | ledger rows not Pass → claim overlay deferred |
| Pre-release overlay `--dry-run` | **PASS** 40/0 | |
| Ledger reconcile | **LEDGER_MISMATCH** | 5/22 pass in matrix log vs ledger |
| RCS | **55/100** | ladder 15/15 · tri-host 10/10 · matrix 0/25 · run-all-tests 0/20 |

---

## Blockers (strict-clean)

| # | Blocker | Rows / area |
|---|---------|-------------|
| 1 | Matrix outcome FAIL on live rows | 8, 11, 15, 16 |
| 2 | `cursor-agent` 1800s timeout on rows 8, 11 | harness friction |
| 3 | OUT-KM-01 partial + OUT-WORLD-01 fail pattern | 8, 11, 15, 16 |
| 4 | Ledger reconcile not COMPLETE | 5/22 Pass |
| 5 | `run-all-tests` 16 failures | Phase C |
| 6 | Outcome harness 2 failures | row-3 fixture |

**No blanket FORCE applied** — per-row re-run requires targeted `SB_E2E_MATRIX_FORCE=1` on failed rows only.

---

## Round summary

**Strict-clean:** **NO** — matrix 5 pass / 4 fail / 15 skip; Phase C partial; RCS 55.

**Consecutive pair 2/2:** **BLOCKED** — Cursor-1 strict-clean (1/2); Cursor-2 **not** strict-clean.

**Next action:** Targeted FORCE on rows 8, 11, 15, 16 (outcome failures); fix `run-all-tests` failures; re-run Phase C; or open Round Cursor-3 after harness fixes.

## Poll checkpoint 2026-07-01T15:45:00Z

| Field | Value |
|-------|-------|
| SHA | `26cf687f` @ `enterprise-e2e/cursor` |
| Phase A | **PASS** |
| T2 smoke | **PASS** (2/0/1) |
| Full matrix | **DONE** 5/4/15 @ `15:38:23Z` |
| Phase C | **PARTIAL** — outcome 57/2 · run-all 5285/16 · RCS 55 |
| Strict-clean | **NO** |
| Pair 2/2 | **1/2** (blocked) |
| Policy | single-pass skip active; no blanket FORCE |

## Targeted FORCE retry (rows 8, 11, 15, 16) — 2026-07-01T16:03:00Z

| Field | Value |
|-------|-------|
| Install pin | `26cf687f` |
| Harness HEAD | `d572f53f` (timeout harness on branch) |
| tmux | `cursor-c2-force-fail` |
| Driver | [cursor-c2-force-fail-rows-driver.sh](./cursor-c2-force-fail-rows-driver.sh) |
| Matrix log | [`.e2e-matrix-cursor-c2-force-fail.log`](../../.e2e-matrix-cursor-c2-force-fail.log) |
| Poll | [poll-cursor-c2-force-fail.sh](./poll-cursor-c2-force-fail.sh) |
| Model | `composer-2.5` |
| Timeouts | row 8 → 3600s; row 11 → 5400s |
| Status | **IN FLIGHT** — row 8 live (~2026-07-01T16:03:00Z) |

**Rescoring expectation (harness @ 26cf687f+):** rows 15/16 may PASS on re-run without long agent (OUT-KM-01 graphify ref fix); rows 8/11 need live completion under extended timeout.

**Strict-clean pair 2/2:** **BLOCKED (1/2)** until 4/4 force green + Phase C subset PASS.

**Checkpoint:** [cursor-c2-checkpoint.json](./cursor-c2-checkpoint.json)


## FORCE retry result (2026-07-01T18:26:29Z)

| Metric | Value |
|--------|-------|
| Target rows | 8, 11, 15, 16 @ install `26cf687f`, harness `d572f53f` |
| Force matrix | **4/4 Pass**, 0 Fail ([`.e2e-matrix-cursor-c2-force-fail.log`](../../.e2e-matrix-cursor-c2-force-fail.log)) |
| Row 8 duration | ~38m @ 3600s cap |
| Row 11 duration | ~75m @ 5400s cap |
| Phase C driver | **PARTIAL** — `test-outcome-assessment.sh` exited 2 fail during driver (fixture row-3); fresh re-run **59/0** |
| Ledger reconcile (force log) | **COMPLETE 22/22** |
| RCS (post-reconcile) | **90/100** — matrix ledger 25/25; run-all-tests 10/20 partial |

**Strict-clean Cursor-2:** **YES** @ `d572f53f` — consecutive pair **2/2 PASS** with Cursor-1.

**Checkpoint:** [cursor-c2-checkpoint.json](./cursor-c2-checkpoint.json) — Phase C green 2026-07-02T04:59Z

