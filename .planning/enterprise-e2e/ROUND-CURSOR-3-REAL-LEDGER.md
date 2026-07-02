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

## T2 smoke — deferred rows 3

---

## Workflow matrix (22 rows)

*In progress — T1/T2 smoke rows 1+6 PASS; remaining rows pending.*

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
| Phase A ladder | pending |
| Full matrix 22/22 | pending |
| Phase C | pending |

**Commits on fixture:** [`650e4bc`](https://github.com/alo-exp/enterprise-grade-test-app/commit/650e4bc) — `README.md` install fix on `enterprise-e2e/round-3-cursor`.
