# Round 9 — Gate checklist (Claude host)

**Updated:** 2026-07-03  
**Ledger:** [ROUND-9-LEDGER.md](./ROUND-9-LEDGER.md)  
**Policy:** [TEST-APP-BRANCH-POLICY.md](./TEST-APP-BRANCH-POLICY.md)

## Fixture

| Check | Status |
|-------|--------|
| Branch `enterprise-e2e/round-9-claude` from `8482e60` | **PASS** (isolated worktree `enterprise-grade-test-app-round9-claude`) |
| Main clone not used for Claude R9 smoke | **PASS** (main on `round-9-codex` — parallel codex lane) |
| R8 registry smoke-seeds not reused for credit | **PASS** (new install FP @ Gate 0) |

## Gate 0 — install surface (honest)

| Check | Status |
|-------|--------|
| `SB_E2E_SKIP_INSTALL_CLAUDE` unset | **PASS** |
| `RTK_DISABLED=1 bash scripts/install-claude.sh` | **PASS** (2026-07-03) |
| `validate-host-install-surface.sh --host claude` | **PASS** (claude OK; codex/cursor host-bundles absent in FP worktree — expected) |
| `run-tri-host-install-smoke.sh --host claude` | **PASS** (5/5) |

## Gate 1 — harness (Tier A subset)

| Check | Status |
|-------|--------|
| `test-enterprise-e2e-live-suite.sh` | **PASS** (140/140) |
| `test-outcome-assessment.sh` | **PASS** (67/67 on main @ harness commit) |
| `run-enterprise-e2e-live-test.sh --preflight-only` | **PASS** |

## Gate 2 — live smoke (attempt 1)

Rows 1, 3, 6, 11, 21, 22 with `SB_E2E_SURFACE_SKIP=0`.

| Check | Status | Notes |
|-------|--------|-------|
| Smoke matrix | **FAIL** | 2 pass / 4 fail |
| Session 0 / code-intel preflight | **FAIL (honesty)** | Skipped via `SB_E2E_SESSION0_SKIP` + `--skip-code-intel-preflight` |
| Test-app branch at run time | **FAIL** | Main clone `round-9-codex` vs expected `round-9-claude` |
| §5b product commits | **FAIL** | 0 commits on `8482e60..HEAD` |
| Rows 21–22 internal | **PASS** | harness-only |

### Per-row Gate 2 outcome (attempt 1)

| Row | Evidence gate | Outcome gate | `OUT-WORLD-01` | `OUT-CODEINT-01` | `OUT-KM-01` |
|-----|---------------|--------------|----------------|------------------|-------------|
| 1 | PASS | **FAIL** | fail | pass (workflow) | n/a |
| 3 | PASS | **FAIL** | fail | partial | partial |
| 6 | PASS | **FAIL** | fail | partial | partial |
| 11 | PASS | **FAIL** | fail | partial | partial |
| 21 | n/a | **PASS** | n/a | n/a | n/a |
| 22 | n/a | **PASS** | n/a | n/a | n/a |

## Gate 2 — live smoke (attempt 2 / retry)

| Check | Status |
|-------|--------|
| Isolated fixture + opt-in | **PASS** (worktree; graphify+agentmemory enabled; `graph.json` seeded) |
| Branch assert in live runner | **PASS** (patched SB_ROOT) |
| No Session0 / code-intel skip | **PASS** (driver updated) |
| Matrix run (attempt 2) | **SUPERSEDED** — smoke closed GREEN; full 22 deferred to Gate 3 |

## Gate 2 — live smoke (closure) — **GREEN**

**Date:** 2026-07-03  
**Install FP:** `claude@ba77d1b0ed19+596e99deab17`  
**Registry:** **6/22** (smoke subset **6/6**)

| Check | Status | Notes |
|-------|--------|-------|
| Smoke rows 1, 3, 6, 11, 21, 22 | **PASS** | [`.row-pass-registry.json`](.row-pass-registry.json) |
| Row 3+11 outcome re-pilot | **PASS** | [`.e2e-r9-pilot-row3-then-11-live.log`](../../.e2e-r9-pilot-row3-then-11-live.log); `OUT-WORLD-01` composite pass both rows |
| §5b cumulative policy | **PASS** | `SB_E2E_PRODUCT_WORK_CUMULATIVE=1`; **5** fixture commits since `8482e60` (see ledger §5b summary) |
| `test-enterprise-e2e-matrix-prompt.sh` | **PASS** | 15/15 pre full-matrix |
| `test-outcome-assessment.sh` | **PASS** | 67/67 pre full-matrix |
| Full matrix 22 rows | **NOT STARTED** | **Next gate** — intentional hold until smoke harness committed + SB_ROOT @ main HEAD |

### Next step (Gate 3 — full matrix)

**One command (canonical @ main HEAD):**

```bash
RTK_DISABLED=1 bash scripts/enterprise-e2e/round9-gate3-driver.sh --preflight-only
RTK_DISABLED=1 bash scripts/enterprise-e2e/round9-gate3-driver.sh --tmux
```

1. **SB_ROOT** resolves to main checkout via [`scripts/lib/enterprise-e2e-sb-root-resolve.sh`](../../scripts/lib/enterprise-e2e-sb-root-resolve.sh) — legacy `/private/tmp/sb-main-row11-fp` only if still present.
2. Optional smoke migrate when surface hash unchanged: `SB_E2E_REGISTRY_MIGRATE_FROM=claude@ba77d1b0ed19+596e99deab17` (see [`registry-migrate-install.sh`](../../scripts/enterprise-e2e/registry-migrate-install.sh)).
3. Driver runs remaining rows @ current `install_fp`; updates [ROUND-9-LEDGER.md](./ROUND-9-LEDGER.md) via matrix harness; target **22/22** + `strict-clean-check.sh` exit 0 before certification upgrade.

Legacy smoke driver: [`round9-matrix-driver.sh`](round9-matrix-driver.sh) (rows 1,3,6,11,21,22 only).

