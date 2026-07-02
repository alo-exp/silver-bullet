# Round Codex-3 REAL Ledger — Enterprise E2E Matrix (Codex host)

**Anti-faking methodology run** — honest product certification under [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](../../docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) §5a/§5b (2026-07-02).

Prior Codex-1/Codex-2 **22/22 harness PASS** is **void** for product-work certification ([CODEX-TEST-APP-PRODUCT-AUDIT.md](./CODEX-TEST-APP-PRODUCT-AUDIT.md) — **0/22** real commits).

Contrast pattern: [ROUND-CURSOR-3-REAL-LEDGER.md](../../.planning/enterprise-e2e/ROUND-CURSOR-3-REAL-LEDGER.md) (main repo).

---

## Round metadata

| Field | Value |
|-------|-------|
| Round | Codex-3 REAL |
| Host | `codex` |
| SB harness branch | `enterprise-e2e/codex` |
| SB repo SHA | `c7816775` (start) → *(update per checkpoint)* |
| Test-app branch | `enterprise-e2e/round-9-codex` |
| Test app baseline SHA | `09f8d1a` (pre-`826cb5c` — **no matrix pre-seed**) |
| Test-app CWD | `/Users/shafqat/projects/enterprise-grade-test-app` |
| Codex model | gpt-5.4 / gpt-5.5 (ladder); matrix per install pin |
| Operator | Live subagent session |
| Start date | 2026-07-02 |
| Methodology | §5a anti-faking + §5b evidence gates + **product commit gate** |

**Why `09f8d1a` not `8482e60`:** `8482e60` lineage includes `826cb5c` which pre-populated all 22-row touch surfaces (audit root cause). Round-9 resets to minimal seed **before** that commit.

**Harness artifacts (Codex-isolated):**

| Artifact | Path |
|----------|------|
| Live driver | [codex-r3-real-driver.sh](./codex-r3-real-driver.sh) |
| Tier A log | [.codex-r3-tiera-offline.log](./.codex-r3-tiera-offline.log) |
| Tier B smoke log | `.e2e-matrix-codex-live.log` |
| Monitor status | `.e2e-matrix-codex-monitor-status.txt` |
| Gates | [ROUND-CODEX-3-GATES.md](./ROUND-CODEX-3-GATES.md) |

---

## Anti-faking controls (harness)

| Control | Implementation |
|---------|----------------|
| Fresh fixture branch | `enterprise-e2e/round-9-codex` @ `09f8d1a` (excludes `826cb5c`) |
| §5b product commit gate | `enterprise_e2e_assert_row_product_commit_delta` in `scripts/enterprise-e2e/lib/core.sh` — FAIL implement rows when fixture HEAD unchanged |
| Rows exempt from commit gate | 1 (routing), 15 (triad audit), 21–22 (internal inherit) |
| `SB_E2E_MATRIX_FORCE_ALL=1` | Required — no install-skip / frozen-merge on first REAL certification |
| `SB_E2E_PRODUCT_WORK_GATE=1` | Default on; disable only for structural dry-run |
| Post-row ledger columns | `log_bytes`, `live_invoke`, `commit_sha`, `host_agent_attestation` |

---

## Tier A — offline / structural

| Check | Result | Notes |
|-------|--------|-------|
| Structural suite | *pending* | `test-enterprise-e2e-live-suite.sh` |
| Outcome harness | *pending* | `test-outcome-assessment.sh` |
| Test-app branch | *pending* | `test-enterprise-e2e-test-app-branch.sh` (round-9 + no 826cb5c) |
| Host preflight | *pending* | `run-enterprise-e2e-live-test.sh --host codex --preflight-only` |
| Dry-run matrix | *pending* | `SB_E2E_MATRIX_DRY_RUN=1` |

**Tier A verdict:** *pending*

---

## Tier B — live smoke (rows 1, 3, 6)

| # | WF slug | Pass/Fail | log_bytes | live_invoke | commit_sha | Notes |
|---|---------|-----------|-----------|-------------|------------|-------|
| 1 | `silver-router` | *pending* | | | | routing-only — commit gate exempt |
| 3 | `silver-feature` | *pending* | | | | **product commit required** |
| 6 | `silver-fast` | *pending* | | | | **product commit required** |

**Tier B verdict:** *pending*

---

## Workflow matrix (22 rows)

| # | WF slug | Pass/Fail | log_bytes | live_invoke | commit_sha | product_gate | Notes |
|---|---------|-----------|-----------|-------------|------------|--------------|-------|
| 1 | `silver-router` | | | | | exempt | |
| 2 | `silver-research` | | | | | required | |
| 3 | `silver-feature` | | | | | required | |
| 4 | `silver-bugfix` | | | | | required | |
| 5 | `silver-ui` | | | | | required | |
| 6 | `silver-fast` | | | | | required | |
| 7 | `silver-test` | | | | | required | |
| 8 | `silver-refactor` | | | | | required | |
| 9 | `silver-benchmark` | | | | | required | |
| 10 | `silver-content` | | | | | required | |
| 11 | `silver-devops` | | | | | required | |
| 12 | `silver-deploy` | | | | | required | |
| 13 | `silver-canary` | | | | | required | |
| 14 | `silver-release` | | | | | required | |
| 15 | `review-triad` | | | | | exempt | audit-only |
| 16 | `ship-readiness` | | | | | required | |
| 17 | `silver-incident` | | | | | required | |
| 18 | `silver-retro` | | | | | required | |
| 19 | `silver-forensics` | | | | | required | |
| 20 | `process-maintenance` | | | | | required | |
| 21 | `post-exec-gates` | | | | | exempt | parent row 3 |
| 22 | `validate-substep` | | | | | exempt | parent row 4 |

**Pass count:** 0 / 22

---

## Phase C

| Step | Status |
|------|--------|
| `test-outcome-assessment.sh` | pending |
| `run-all-tests.sh` | pending |
| validation overlay `--live` | pending |
| pre-release overlay | pending |
| ledger reconcile | pending |
| RCS ≥ 85 | pending |

---

## Product audit

Target: [CODEX-3-TEST-APP-PRODUCT-AUDIT.md](./CODEX-3-TEST-APP-PRODUCT-AUDIT.md) — **>0** row-mapped product commits (vs Codex-1/2 **0/22**).

---

## Round summary

| Phase | Status |
|-------|--------|
| Fixture reset (round-9 @ 09f8d1a) | **PASS** |
| Harness §5b product gate | **landed** |
| Tier A offline | *pending* |
| Tier B smoke 1,3,6 | *pending* |
| Full matrix 22/22 | *pending* |
| Phase C | *pending* |
| Product audit | *pending* |
