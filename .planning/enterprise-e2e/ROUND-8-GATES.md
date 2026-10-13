# Round 8 — Gate checklist

**Updated:** 2026-07-01T06:15Z  
**SB HEAD:** `156630f6` (`enterprise-e2e/multi-host`)  
**Test app HEAD:** `565e825`  
**Ledger:** [ROUND-8-LEDGER.md](./ROUND-8-LEDGER.md) *(create at round start)*  
**Prior round:** [ROUND-7-GATES.md](./ROUND-7-GATES.md) — 22/22 matrix, strict-clean **NO** (`OUT-SURFACE-01` skipped)

## Status: **PENDING** — matrix **not launched** (install-surface merge blocker)

Round 8 targets **2× consecutive strict-clean** (Round 8 + Round 9). Round 7 closed with `OUT-SURFACE-01` **SKIP** (`SB_E2E_SURFACE_SKIP=1`) — Round 8 **must not** skip surface.

### Round gates

| Gate | Status |
|------|--------|
| `test-claude-agent-surface-isolation.sh` | **PASS** 6/6 @ `156630f6` (pristine checkout; no SKIP) |
| `OUT-SURFACE-01` live (`SB_E2E_SURFACE_SKIP=0`) | **BLOCKED** — host-bundles install fix on `main` only; not in multi-host ancestry |
| Claude lock (`.e2e-live-test.lock`) | **CLEAR** — no lock file |
| Matrix ledger 22/22 | **PENDING** |
| Ledger reconcile | **PENDING** |
| `test-outcome-assessment.sh` | **PENDING** |
| `OUT-MEASURE-01` | **PENDING** |
| review-fix-ladder 8/8 | **PENDING** |
| New issues vs baseline | **PENDING** (baseline 76) |
| Round strict-clean | **PENDING** |
| 2 consecutive strict clean rounds | **0 / 2** (R6+R7 not strict-clean) |

### Strict-clean requirements (Round 8)

Per [ROUND-N-GATES.md](./ROUND-N-GATES.md):

1. **Matrix 22/22** — every row PASS with graphify + agentmemory refs.
2. **All applicable outcome criteria** pass per row (`partial` = FAIL).
3. **Blocking autonomy gates** per row: `OUT-AUTO-01`, `OUT-CLARIFY-01`, `OUT-NOOP-01`, `OUT-WORLD-01`.
4. **Zero new issues** vs baseline 76.
5. **`OUT-SURFACE-01` live** — `SB_E2E_SURFACE_SKIP=0` **required**; `validate-host-install-surface.sh` + token budget must pass at round preflight and in `enterprise_e2e_outcome_assess_round`.

**Round 7 honesty carry-forward:** skipping `OUT-SURFACE-01` disqualified strict-clean. Round 8 cannot repeat that skip.

### Install-surface / host-bundles branch audit

| Commit / branch | On `enterprise-e2e/multi-host` @ `156630f6`? |
|-----------------|-----------------------------------------------|
| `4ccea894` fix(install): cross-host surface audit, host-bundles isolation | **NO** — `main` only |
| `f99eae52` fix(install): align codex tests and bundles with host-bundles layout | **NO** — `main` only |
| `95c50892` fix(release): host-bundles smoke paths | **NO** — `main` only |
| `33e9523d` fix(ci): align bundle tests with host-bundles layout | **NO** — `main` only |
| `fix/claude-agent-surface-cross-env` | **NO** — separate branch; other session owns merge |
| `68c137ee` harness + `validate-host-install-surface.sh` on multi-host line | **YES** — in ancestry |

Pristine-repo `test-claude-agent-surface-isolation.sh` **PASS**es @ `156630f6`, but **post-`install-claude.sh` surface** may regress until main install fix is merged to `enterprise-e2e/multi-host`. **Do not implement install fix in this session.**

### Full matrix (22 rows)

| # | Slug | Route | Prompt (summary) | Evidence path |
|---|------|-------|------------------|---------------|
| 1 | `silver-router` | `/silver` | Add order validation — route me | `.planning/workflows/router-session.md` |
| 2 | `silver-research` | `/silver:research` | Postgres vs SQLite for orders | `docs/ADR-001-runtime.md` |
| 3 | `silver-feature` | `/silver:feature` | Currency field on orders API + tests | `.planning/workflows/feature-currency.md` |
| 4 | `silver-bugfix` | `/silver:bugfix` | Health 500 when version missing | `.planning/workflows/bugfix-health.md` |
| 5 | `silver-ui` | `/silver:ui` | API version in admin badge | `ui/src/App.jsx` |
| 6 | `silver-fast` | `/silver:fast` | Fix README install instructions | `.planning/workflows/fast-readme.md` |
| 7 | `silver-test` | `/silver:test` | Integration test for order creation | `.planning/workflows/test-orders-integration.md` |
| 8 | `silver-refactor` | `/silver:refactor` | Extract order validation to domain | `.planning/workflows/refactor-order-validation.md` |
| 9 | `silver-benchmark` | `/silver:benchmark` | Benchmark health p95 | `docs/benchmarks/health.md` |
| 10 | `silver-content` | `/silver:content` | Public API consumer docs | `docs/API.md` |
| 11 | `silver-devops` | `/silver:devops` | Terraform env validation | `.planning/workflows/devops-terraform-validation.md` |
| 12 | `silver-deploy` | `/silver:deploy` | Staging deploy procedure | `docs/DEPLOY.md` |
| 13 | `silver-canary` | `/silver:canary` | Canary rollout notes | `docs/CANARY.md` |
| 14 | `silver-release` | `/silver:release` | Ship v0.2.0 + changelog | `CHANGELOG.md` |
| 15 | `review-triad` | `/silver:review-triad` | Review currency change | `.planning/reviews/triad-currency.md` |
| 16 | `ship-readiness` | `/silver:ship-readiness` | Branch ready to merge? | `.planning/ship-readiness/checklist.md` |
| 17 | `silver-incident` | `/silver:incident` | CI failed on main | `docs/incidents/INC-001.md` |
| 18 | `silver-retro` | `/silver:retro` | Retro after v0.2.0 | `docs/retro/RETRO-001.md` |
| 19 | `silver-forensics` | `/silver:forensics` | Investigate verify-tests failure | `docs/forensics/CI-001.md` |
| 20 | `process-maintenance` | `/silver:process-maintenance` | Update workflow map | `docs/WORKFLOW_E2E_MATRIX.md` |
| 21 | `post-exec-gates` | *(internal)* | Parent row **3** | `feature-currency.md` markers |
| 22 | `validate-substep` | *(internal)* | Parent row **4** | `bugfix-health.md` markers |

### Environment (Round 8 launch)

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-8-LEDGER.md"
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app
export SB_E2E_SURFACE_SKIP=0          # REQUIRED — no skip
export SB_E2E_MONITOR_AUTO_RESTART=0
export RTK_DISABLED=1
git checkout enterprise-e2e/multi-host   # pin @ 156630f6+ after install fix merge
```

**Preflight (must pass before matrix):**

```bash
RTK_DISABLED=1 bash tests/scripts/test-claude-agent-surface-isolation.sh
RTK_DISABLED=1 bash scripts/install-claude.sh
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh --preflight-only
```

### 2× consecutive strict-clean tracker

| Round | Strict-clean |
|-------|--------------|
| Round 5 | **YES** |
| Round 6 | **NO** |
| Round 7 | **NO** — `OUT-SURFACE-01` SKIP |
| Round 8 | **PENDING** — blocked on install-surface merge |
| **Pair target** | R8+R9 both strict-clean |

## Release verdict

**Round 8:** **not launched** — merge host-bundles install fix from other session onto `enterprise-e2e/multi-host`, re-run surface test **after** `install-claude.sh`, then launch full matrix with `SB_E2E_SURFACE_SKIP=0`.
