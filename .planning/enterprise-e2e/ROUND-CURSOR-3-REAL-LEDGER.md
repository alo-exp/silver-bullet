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
| SB repo SHA | `5d5ef7c8` (+ harness fixes pending commit) |
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
| T0 structural log | `/tmp/cursor3-t0-structural.log` (inline: 189/189 PASS) |
| T0 outcome log | `/tmp/cursor3-t0-outcome.log` (inline: 60/60 PASS post-fix) |

---

## T0 — structural preflight

| Check | Result | Notes |
|-------|--------|-------|
| Structural suite | **PASS** 193/0 | `test-enterprise-e2e-live-suite.sh` (post E2E-092 assertions) |
| Outcome harness | **PASS** 60/0 | `test-outcome-assessment.sh` (+ row 1 OUT-CLARIFY-01 n/a) |
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
| **branch** | Ledger-derived `round-N-{host}` overrides `hosts.json` default in `apply_test_app_branch_defaults` | `scripts/enterprise-e2e/lib/test-app-branch.sh` |

---

## T1 — row 1 live FORCE retry (silver-router)

| Field | Value |
|-------|-------|
| Invoke | `bash .planning/enterprise-e2e/cursor3-real-driver.sh 1` |
| Driver | tmux `cursor3-t1-row1` |
| Log | [`.e2e-cursor3-t1-row1-live.log`](../../.e2e-cursor3-t1-row1-live.log) |
| Attempt log | [`.e2e-row1-cursor-attempt.log`](../../.e2e-row1-cursor-attempt.log) (1690 B) |

### Evidence gates (§5b)

| Gate | Status | Evidence |
|------|--------|----------|
| Log size > 2048 B | **FAIL** (1690 B) | §5a #3 — disqualifying for strict-clean certification |
| Live strict-clean invoke | **yes** | `SB_ENTERPRISE_E2E_LIVE=1` + `SB_E2E_MATRIX_FORCE_ALL=1` + `cursor3-real-driver.sh` |
| Product delta (commit) | **partial** | `router-session.md` updated; **uncommitted** on fixture |
| Host-agent authorship | **yes** | `cursor-agent` headless ~3.5 min session |
| Outcome PASS | **PASS** | `OUT-CLARIFY-01` **n/a** (E2E-091 fix); `OUT-WORLD-01` pass |

| # | WF slug | Pass/Fail | log_bytes | commit_sha | Notes |
|---|---------|-----------|-----------|------------|-------|
| 1 | `silver-router` | **PARTIAL** | 1690 | *(uncommitted)* | Matrix outcome PASS; §5b log floor FAIL |

**T1 verdict:** **PARTIAL** — outcome harness PASS after E2E-091; §5b log bytes block strict-clean credit.

---

## T2 smoke — row 6 (`silver-fast`) retry

| Field | Value |
|-------|-------|
| Invoke | `bash .planning/enterprise-e2e/cursor3-real-driver.sh 6` |
| Driver | tmux `cursor3-t2-row6` (~25 min) |
| Log | [`.e2e-cursor3-t2-row6-live.log`](../../.e2e-cursor3-t2-row6-live.log) |
| Attempt log | [`.e2e-row6-cursor-attempt.log`](../../.e2e-row6-cursor-attempt.log) (736 B) |

### Evidence gates (§5b)

| Gate | Status | Evidence |
|------|--------|----------|
| Log size > 2048 B | **FAIL** (736 B) | No 900s timeout (E2E-092 fixed); log still under §5b floor |
| Live strict-clean invoke | **yes** | `cursor3-real-driver.sh` @ `round-3-cursor`, timeout=1800s |
| Product delta (commit) | **partial** | `fast-readme.md` + README artifacts; **uncommitted** |
| Host-agent authorship | **yes** | Agent completed; evidence PASS |
| Outcome PASS | **FAIL** | `OUT-ORCH-01` (session), `OUT-WORLD-01` (composite) |

| # | WF slug | Pass/Fail | log_bytes | commit_sha | Notes |
|---|---------|-----------|-----------|------------|-------|
| 6 | `silver-fast` | **FAIL** | 736 | *(uncommitted)* | E2E-092 timeout fixed; OUT-ORCH-01 real fail |

**T2 verdict:** **FAIL** — no 900s timeout (E2E-092 resolved); OUT-ORCH-01 + §5b log floor remain.

---

## T2 smoke — deferred rows 3

---

## Workflow matrix (22 rows)

*Not started — T1/T2 gates incomplete.*

---

## Defects / blockers

| ID | Item | Status |
|----|------|--------|
| | Prior round inherited evidence | **void** — fresh `round-3-cursor` @ `8482e60` |
| | Methodology doc update | **done** — §11a E2E-091/E2E-092 |
| **E2E-091** | Row 1 `OUT-CLARIFY-01` false fail on routing-only sessions | **fixed** — scorer returns `n/a`; T1 outcome PASS |
| **E2E-092** | Row 6 timeout @ 900s with 124 B log | **fixed** — 1800s enforced; T2 completed without timeout |
| **E2E-093** | §5b log floor (<2048 B) on rows 1+6 despite live agent work | **open** — E2E-086 buffering; separate from timeout |
| **E2E-094** | Row 6 `OUT-ORCH-01` session fail after live retry | **open** — orchestrator markers absent from 736 B log |

---

## Round summary

| Phase | Status |
|-------|--------|
| T0 structural | **PASS** |
| T1 row 1 live retry | **PARTIAL** (outcome PASS; §5b log 1690 B) |
| T2 row 6 smoke retry | **FAIL** (OUT-ORCH-01; log 736 B) |
| **T2 overall** | **FAIL** |
| Phase A ladder | pending |
| Full matrix 22/22 | pending |
| Phase C | pending |

**Commits on fixture:** none — rows did not meet full §5b PASS gates.
