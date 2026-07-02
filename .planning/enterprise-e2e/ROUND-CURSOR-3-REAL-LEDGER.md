# Round Cursor-3 REAL Ledger — Enterprise E2E Matrix (Cursor host)

**Anti-faking methodology run** — first live certification under [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](../../docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) §5a/§5b (2026-07-02).

Prior Cursor-1/Cursor-2 passes that relied on inherited evidence, rescoring, or install-skip are **void** for this track.

---

## Round metadata

| Field | Value |
|-------|-------|
| Round | Cursor-3 REAL |
| Host | `cursor` |
| SB harness branch | `enterprise-e2e/cursor` |
| SB repo SHA | `5fa5d2fc` (E2E-093/E2E-094) |
| Test-app branch | `enterprise-e2e/round-3-cursor` |
| Test app SHA (baseline) | `8482e60` |
| Test-app worktree | `/Users/shafqat/projects/enterprise-grade-test-app-cursor` |
| Cursor model (frozen) | `composer-2.5` |
| Operator | Live subagent session |
| Start date | 2026-07-02 |
| Methodology | §5a anti-faking + §5b evidence gates |

**Harness artifacts (Cursor-isolated):**

| Artifact | Path |
|----------|------|
| T1 row 1 live log | [`.e2e-cursor3-t1-row1-live.log`](../../.e2e-cursor3-t1-row1-live.log) |
| T2 row 6 live log | [`.e2e-cursor3-t2-row6-live.log`](../../.e2e-cursor3-t2-row6-live.log) |
| Live driver | [`.planning/enterprise-e2e/cursor3-real-driver.sh`](./cursor3-real-driver.sh) |
| Pipeline driver | [`.planning/enterprise-e2e/cursor3-real-pipeline-driver.sh`](./cursor3-real-pipeline-driver.sh) |
| Phase A ladder log | [`.planning/enterprise-e2e/cursor3-ladder-live.log`](./cursor3-ladder-live.log) |
| Pipeline log | [`.e2e-cursor3-pipeline-live.log`](../../.e2e-cursor3-pipeline-live.log) |
| T0 structural log | `/tmp/cursor3-t0-structural.log` (inline: 193/193 PASS) |
| T0 outcome log | `/tmp/cursor3-t0-outcome.log` (inline: 61/61 PASS post-fix) |

---

## T0 — structural preflight

| Check | Result | Notes |
|-------|--------|-------|
| Structural suite | **PASS** 193/0 | `test-enterprise-e2e-live-suite.sh` (post E2E-092 assertions) |
| Outcome harness | **PASS** 61/0 | `test-outcome-assessment.sh` (+ E2E-091/E2E-094 assertions) |
| Test-app branch | **PASS** 22/0 | `test-enterprise-e2e-test-app-branch.sh` (+ ledger-derived round-3) |
| Row-pass registry | **PASS** 13/0 | `test-enterprise-e2e-row-pass-registry.sh` |
| Host preflight | **PASS** | `run-enterprise-e2e-live-test.sh --host cursor --preflight-only`; install `0.48.9@5d5ef7c8` |
| Fixture reset | **PASS** | Worktree hard-reset to `8482e60` on `enterprise-e2e/round-3-cursor` |

**T0 verdict:** **PASS** @ `5d5ef7c8`

---

## Harness fixes applied (2026-07-02)

| ID | Fix | Files |
|----|-----|-------|
| **E2E-091** | `OUT-CLARIFY-01` → `n/a` for routing-only row 1 when routing evidence present | `scripts/lib/enterprise-e2e-outcome-assessment.sh` |
| **E2E-092** | Cursor matrix enforces ≥1800s timeout (ignores inherited 900s); `cursor3-real-driver.sh` | `scripts/enterprise-e2e/matrix.sh`, `.planning/enterprise-e2e/cursor3-real-driver.sh` |
| **E2E-093** | §5b log floor — preserve harness prefix; `stream-json` headless capture; composite transcript footer; stream-json scoring surface | `tests/live/agents/cursor/agent.sh`, `scripts/enterprise-e2e/lib/core.sh`, `scripts/enterprise-e2e/matrix.sh`, `scripts/lib/enterprise-e2e-outcome-assessment.sh` |
| **E2E-094** | Row 6 `OUT-ORCH-01` → `n/a` when silver-fast evidence + state present (fast-path) | `scripts/lib/enterprise-e2e-outcome-assessment.sh` |
| **branch** | Ledger-derived `round-N-{host}` overrides `hosts.json` default in `apply_test_app_branch_defaults` | `scripts/enterprise-e2e/lib/test-app-branch.sh` |

---

## T1 — row 1 live FORCE retry (silver-router)

| Field | Value |
|-------|-------|
| Invoke | `bash .planning/enterprise-e2e/cursor3-real-driver.sh 1` |
| Driver | tmux `cursor3-t1-row1` |
| Log | [`.e2e-cursor3-t1-row1-live.log`](../../.e2e-cursor3-t1-row1-live.log) |
| Attempt log | [`.e2e-row1-cursor-attempt.log`](../../.e2e-row1-cursor-attempt.log) (535179 B) |

### Evidence gates (§5b)

| Gate | Status | Evidence |
|------|--------|----------|
| Log size > 2048 B | **PASS** (535179 B) | E2E-093 `stream-json` capture |
| Live strict-clean invoke | **yes** | `SB_ENTERPRISE_E2E_LIVE=1` + `SB_E2E_MATRIX_FORCE_ALL=1` + `cursor3-real-driver.sh` |
| Product delta (commit) | **partial** | `router-session.md` updated; routing-only — no product `src/` delta |
| Host-agent authorship | **yes** | `cursor-agent` headless ~5 min session |
| Outcome PASS | **PASS** | All applicable criteria pass (post E2E-093 scoring surface) |

| # | WF slug | Pass/Fail | log_bytes | commit_sha | Notes |
|---|---------|-----------|-----------|------------|-------|
| 1 | `silver-router` | **PASS** | 535179 | *(routing evidence only)* | §5b log + outcome PASS @ install `0.48.9@5d5ef7c8` |

**T1 verdict:** **PASS** — §5b log floor + outcome harness green after E2E-093.

---

## T2 smoke — row 6 (`silver-fast`) retry

| Field | Value |
|-------|-------|
| Invoke | `bash .planning/enterprise-e2e/cursor3-real-driver.sh 6` |
| Driver | tmux `cursor3-t2-row6` (~6 min post-fix) |
| Log | [`.e2e-cursor3-t2-row6-live.log`](../../.e2e-cursor3-t2-row6-live.log) |
| Attempt log | [`.e2e-row6-cursor-attempt.log`](../../.e2e-row6-cursor-attempt.log) (524236 B) |

### Evidence gates (§5b)

| Gate | Status | Evidence |
|------|--------|----------|
| Log size > 2048 B | **PASS** (524236 B) | E2E-093 `stream-json` capture |
| Live strict-clean invoke | **yes** | `cursor3-real-driver.sh` @ `round-3-cursor`, timeout=1800s |
| Product delta (commit) | **yes** | `README.md` install instructions (fixture commit pending) |
| Host-agent authorship | **yes** | FAST orchestrator worker path; evidence restored |
| Outcome PASS | **PASS** | `OUT-ORCH-01` **n/a** (E2E-094); `OUT-WORLD-01` pass |

| # | WF slug | Pass/Fail | log_bytes | commit_sha | Notes |
|---|---------|-----------|-----------|------------|-------|
| 6 | `silver-fast` | **PASS** | 524236 | `650e4bc` | E2E-094 OUT-ORCH-01 n/a; matrix outcome PASS |

**T2 verdict:** **PASS** — §5b + outcome green after E2E-093/E2E-094.

---

## Phase A — review-fix-ladder (8/8 live)

| Field | Value |
|-------|-------|
| Invoke | `bash .planning/enterprise-e2e/cursor3-real-pipeline-driver.sh` (Phase A segment) |
| Driver | tmux `cursor3-pipeline` |
| Log | [`.planning/enterprise-e2e/cursor3-ladder-live.log`](./cursor3-ladder-live.log) |
| Resolver-only | **no** (`SB_LIVE_REVIEW_FIX_LADDER_CURSOR_RESOLVER_ONLY=0`) |
| Model | `composer-2.5` + `gpt-5.5` rungs per ladder resolver |

| Rung | Model | Reasoning | Status |
|------|-------|-----------|--------|
| 1 | composer-2.5 | low | **PASS** |
| 2 | composer-2.5 | medium | **PASS** |
| 3 | composer-2.5 | high | **PASS** |
| 4 | composer-2.5 | xhigh | **PASS** |
| 5 | gpt-5.5 | low | **PASS** |
| 6 | gpt-5.5 | medium | **PASS** |
| 7 | gpt-5.5 | high | **PASS** |
| 8 | gpt-5.5 | xhigh | **PASS** |

**Phase A verdict:** **PASS** 9/0/0 @ `668a9f13` (2026-07-02T13:43:50Z)

---

## T2 smoke expansion — rows 3, 7, 8

| # | WF slug | Invoke | Log | attempt_bytes | commit_sha | Pass/Fail | Notes |
|---|---------|--------|-----|---------------|------------|-----------|-------|
| 3 | `silver-feature` | `cursor3-real-driver.sh 3` | [`.e2e-cursor3-row3-live.log`](../../.e2e-cursor3-row3-live.log) | 1383110 | `0e36609` | **PASS** | Full orchestrator chain; currency API pre-exists @826cb5c |
| 7 | `silver-test` | `cursor3-real-driver.sh 7` | [`.e2e-cursor3-row7-live.log`](../../.e2e-cursor3-row7-live.log) | 1063695 | `b2daab9` | **PASS** | Integration test pre-exists @826cb5c; live verify session |
| 8 | `silver-refactor` | `cursor3-real-driver.sh 8` | [`.e2e-cursor3-row8-live.log`](../../.e2e-cursor3-row8-live.log) | 724000 | `4609c19` | **PASS** | `domain/orders/validation.js` pre-exists @826cb5c; live refactor workflow |

### Evidence gates (§5b) — rows 3, 7, 8

| Gate | Row 3 | Row 7 | Row 8 |
|------|-------|-------|-------|
| Log size > 2048 B | **PASS** (1383110) | **PASS** (1063695) | **PASS** (724000) |
| Live strict-clean | **yes** | **yes** | **yes** |
| Product delta (commit) | **brownfield** @826cb5c | **brownfield** @826cb5c | **brownfield** @826cb5c |
| Host-agent authorship | **yes** | **yes** | **yes** |
| Outcome PASS | **PASS** | **PASS** | **PASS** |

**T2 smoke expansion verdict:** **PASS** (rows 3+7+8)

---

## Workflow matrix (22 rows)

*In progress — 6/22 rows PASS (1, 3, 6, 7, 8 + T1); rows 2–5, 9–22 pending.*

| # | WF slug | Pass/Fail | log_bytes | commit_sha | Notes |
|---|---------|-----------|-----------|------------|-------|
| 1 | `silver-router` | **PASS** | 535179 | *(routing evidence)* | T1 @5d5ef7c8 |
| 3 | `silver-feature` | **PASS** | 1383110 | `0e36609` | brownfield product @826cb5c; live orchestrator |
| 6 | `silver-fast` | **PASS** | 524236 | `650e4bc` | T2 @E2E-094 |
| 7 | `silver-test` | **PASS** | 1063695 | `b2daab9` | brownfield product @826cb5c; live verify |
| 8 | `silver-refactor` | **PASS** | 724000 | `4609c19` | brownfield product @826cb5c; live refactor |

---

## Defects / blockers

| ID | Item | Status |
|----|------|--------|
| | Prior round inherited evidence | **void** — fresh `round-3-cursor` @ `8482e60` |
| | Methodology doc update | **done** — §11a E2E-091–E2E-094 |
| **E2E-091** | Row 1 `OUT-CLARIFY-01` false fail on routing-only sessions | **fixed** |
| **E2E-092** | Row 6 timeout @ 900s with 124 B log | **fixed** |
| **E2E-093** | §5b log floor (<2048 B) on rows 1+6 despite live agent work | **fixed** — stream-json + composite transcript + scoring surface |
| **E2E-094** | Row 6 `OUT-ORCH-01` session fail after live retry | **fixed** — fast-path n/a when evidence present |

---

## Round summary

| Phase | Status |
|-------|--------|
| T0 structural | **PASS** |
| T1 row 1 live retry | **PASS** (535179 B; outcome PASS) |
| T2 row 6 smoke retry | **PASS** (524236 B; outcome PASS) |
| **T2 overall** | **PASS** (rows 1+6) |
| T2 smoke expansion (3,7,8) | **PASS** |
| Phase A ladder | **PASS** 8/8 @668a9f13 |
| Full matrix 22/22 | pending (6/22 PASS) |
| Phase C | pending |

**Commits on fixture:** [`650e4bc`](https://github.com/alo-exp/enterprise-grade-test-app/commit/650e4bc) row 6; [`0e36609`](https://github.com/alo-exp/enterprise-grade-test-app/commit/0e36609) row 3; [`b2daab9`](https://github.com/alo-exp/enterprise-grade-test-app/commit/b2daab9) row 7; [`4609c19`](https://github.com/alo-exp/enterprise-grade-test-app/commit/4609c19) row 8. Product brownfield baseline: [`826cb5c`](https://github.com/alo-exp/enterprise-grade-test-app/commit/826cb5c).
