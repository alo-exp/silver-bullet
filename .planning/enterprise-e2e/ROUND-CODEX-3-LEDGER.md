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
| SB repo SHA | `4412bb01` (fixture branch lock + Tier B relaunch) |
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
| Structural suite | **PASS** 179/0 | [.codex-r3-tiera-offline.log](./.codex-r3-tiera-offline.log) |
| Outcome harness | **PASS** 79/0 | |
| Test-app branch | **PASS** 16/0 | round-9 @ 09f8d1a; excludes 826cb5c |
| Validation overlay (dry-run) | **PASS** 6/0 | |
| Pre-release overlay (dry-run) | **PASS** 40/0 | |
| Tri-host smoke (codex) | **PASS** 5/0 | |
| Hook delivery preflight | **PASS** 3/0 | |
| Host preflight | **PASS** | install in flight @ Tier B launch |
| Dry-run matrix | **PASS** 20/22 | rows 21–22 FAIL expected (no parent 3/4 evidence) |
| validate-host-install-surface | **SKIP** | script absent on codex branch |

**Tier A verdict:** **PASS** @ `25d373a6`

---

## Tier B — live smoke (rows 1, 3, 6)

**Driver:** tmux `codex-r3-real-tierb` pane **6228**; live-test lock **6358**; matrix **14143**; poll-exit → [.codex-r3-tierb-poll-exit.sh](./.codex-r3-tierb-poll-exit.sh) `6228`  
**Launch:** [codex-r3-real-driver.sh](./codex-r3-real-driver.sh) rows 1,3,6 @ `c8e2f002`  
**Launch log:** [.codex-r3-tierb-launch.nohup](./.codex-r3-tierb-launch.nohup)  
**Friction monitor:** PID **8072** — [.tui-monitor-agent-run.log](./.tui-monitor-agent-run.log)  
**Status:** **RUNNING** (Row 1 live invoke — past tui-watch stall)

### Poll checkpoint 2026-07-03T00:56Z (fixture branch lock + Tier B relaunch @ `4412bb01`)

| Field | Value |
|-------|-------|
| **Harness fix** | `4412bb01` — `enterprise_e2e_fixture_assert_branch_lock`; pre/post-invoke branch pin in matrix; duplicate-batch guard in driver |
| **Root cause** | Agent `git checkout` to `round-9-claude` @ `8482e60` during row 1 (826cb5c pre-seed §5b violation) |
| **SIGTERM 52051** | Duplicate driver relaunch @ `5002b568` killed prior batch mid-row 3 — operator relaunch, not matrix bug |
| **Remediation** | fixture hard-reset `enterprise-e2e/round-9-codex` @ `09f8d1a`; row logs 1/3 purged; stale workflow evidence cleared |
| **Tier B driver** | **RUNNING** tmux `codex-r3-real-tierb` pane **67803** @ `4412bb01` |
| **Poll-exit** | PID **68831** → [.codex-r3-tierb-poll-exit.sh](./.codex-r3-tierb-poll-exit.sh) `67803` |
| **Chain monitor** | PID **68833** — [.codex-r3-chain-monitor.log](./.codex-r3-chain-monitor.log) |
| **Friction monitor** | PID **68835** — [.tui-monitor-agent-run.log](./.tui-monitor-agent-run.log) |
| **§5b product gate** | **ON** — exempt rows 1,15,21,22 |

### Poll checkpoint 2026-07-03T00:28Z (FORCE_ALL harness fix + Tier B relaunch @ `5002b568`)

| Field | Value |
|-------|-------|
| **Harness fix** | `5002b568` — `matrix_force_rerun()` honors `SB_E2E_MATRIX_FORCE_ALL=1`; EXIT trap captures batch pid path |
| **Blockers cleared** | stale Codex-2 evidence skip; `_matrix_batch_pid_file` unbound on EXIT |
| **Remediation** | fixture reset `09f8d1a`; Tier B workflow evidence purged; row logs 1/3/6 cleared |
| **Tier B driver** | **RUNNING** tmux `codex-r3-real-tierb` pane **43664** cwd `/private/tmp/sb-codex-force4-wt` |
| **Matrix** | PID **52051** — Row 1 live invoke (no SKIP) |
| **Poll-exit** | PID **44643** → [.codex-r3-tierb-poll-exit.sh](./.codex-r3-tierb-poll-exit.sh) `43664` |
| **Friction monitor** | PID **44764** — [.tui-monitor-agent-run.log](./.tui-monitor-agent-run.log) |
| **§5b product gate** | **ON** — exempt rows 1,15,21,22 |

### Poll checkpoint 2026-07-02T14:18Z (Round Codex-3 REAL Tier B relaunch @ `c8e2f002`)

| Field | Value |
|-------|-------|
| **Blockers cleared** | stale lock PID 2916; orphan monitors 6454/7280/59054; misbound batch.pid |
| **Remediation** | `install-codex.sh --purge-legacy-skills` PASS; fixture reset `09f8d1a` |
| **Tier B driver** | **RUNNING** tmux `codex-r3-real-tierb` pane **6228** cwd `/private/tmp/sb-codex-force4-wt` |
| **Poll-exit** | PID bound → [.codex-r3-tierb-poll-exit.sh](./.codex-r3-tierb-poll-exit.sh) `6228` |
| **§5b product gate** | **ON** — exempt rows 1,15,21,22 |
| **Tier C chain** | On fresh **3/3** rescore → auto-launch [codex-r3-matrix-driver.sh](./codex-r3-matrix-driver.sh) + [.codex-r3-matrix-poll-exit.sh](./.codex-r3-matrix-poll-exit.sh) |

| # | WF slug | Pass/Fail | log_bytes | live_invoke | commit_sha | Notes |
|---|---------|-----------|-----------|-------------|------------|-------|
| 1 | `silver-router` | *pending* | | | | routing-only — commit gate exempt |
| 3 | `silver-feature` | *pending* | | | | **product commit required** |
| 6 | `silver-fast` | *pending* | | | | **product commit required** |

**Tier B verdict:** *pending* (force36 relaunch @ `4412bb01` — row 1 frozen PASS; FORCE 3,6)

### Poll checkpoint 2026-07-03T01:10Z (force36 relaunch @ `4412bb01`)

| Field | Value |
|-------|-------|
| **Root cause rows 3,6** | Codex wrote planning-only evidence; **0 fixture commits** — §5b FAIL |
| **Poll-exit 68831** | Early death — `pipefail` + `pgrep` no-match; fixed in tierb/force36 poll scripts |
| **Harness fix** | `matrix_product_commit_clause` in invoke prompts (codex implement rows); [codex-r3-force36-driver.sh](./codex-r3-force36-driver.sh) + [.codex-r3-force36-poll-exit.sh](./.codex-r3-force36-poll-exit.sh) tmux-stable |
| **Policy** | One pass — frozen row **1** PASS; FORCE rows **3,6** only |
| **Tier B driver** | tmux `codex-r3-force36:driver` @ `4412bb01` |
| **Poll-exit** | tmux `codex-r3-force36:poll` → [.codex-r3-force36-poll-exit.sh](./.codex-r3-force36-poll-exit.sh) |
| **§5b product gate** | **ON** — exempt rows 1,15,21,22 |
| **Tier C chain** | On **3/3** rescore → auto [codex-r3-matrix-driver.sh](./codex-r3-matrix-driver.sh) |

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
| Tier A offline | **PASS** @ `25d373a6` |
| Tier B smoke 1,3,6 | **RUNNING** (lock PID 6358, matrix 14143 @ `c8e2f002`) |
| Full matrix 22/22 | *pending* |
| Phase C | *pending* |
| Product audit | *pending* |

### Poll checkpoint 2026-07-02T14:21:48Z (Round Codex-3 REAL Tier B exit)

| Field | Value |
|-------|-------|
| **Driver** | EXITED PID **6228** |
| **Tier B rescore** | **0/3** — [.codex-r3-tierb-rescore.log](./.codex-r3-tierb-rescore.log) |
| **Tier C** | **BLOCKED** — fix Tier B failures first |

### Poll checkpoint 2026-07-02T14:46:44Z (Round Codex-3 REAL Tier B exit)

| Field | Value |
|-------|-------|
| **Driver** | EXITED PID **43664** |
| **Tier B rescore** | **1/3** — [.codex-r3-tierb-rescore.log](./.codex-r3-tierb-rescore.log) |
| **Tier C** | **BLOCKED** — fix Tier B failures first |
| 1 | blocker | hook | Stage enforcer | tui-watch 2026-07-02T15:04:54Z |
| 1 | blocker | hook | Stage enforcer | tui-watch 2026-07-02T15:04:54Z |
| 1 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:04:54Z |
| 1 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:04:54Z |
| 1 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:04:55Z |
| 1 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:04:55Z |
| 3 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:06:03Z |
| 3 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:06:04Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:06:04Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:06:04Z |
| 3 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:15:33Z |
| 3 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:15:33Z |
| 6 | blocker | hook | Stage enforcer | tui-watch 2026-07-02T15:28:32Z |
| 6 | blocker | hook | Stage enforcer | tui-watch 2026-07-02T15:28:32Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:28:32Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:28:32Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:28:32Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:28:32Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:28:32Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:28:32Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:28:32Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:28:32Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:28:32Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T15:28:32Z |

### Poll checkpoint 2026-07-02T15:29:34Z (force36 exit @ 2909294e)

| Field | Value |
|-------|-------|
| **Policy** | One pass — frozen row **1** PASS; FORCE rows **3,6** only |
| **Driver** | EXITED PID **4291** |
| **Tier B rescore** | **1/3** — [.codex-r3-force36-rescore.log](./.codex-r3-force36-rescore.log) |
| **Tier C** | **BLOCKED** — fix Tier B failures first |

### Diagnosis — force36 effective 1/3 @ `2909294e` (2026-07-03)

| Row | Root cause | Evidence |
|-----|------------|----------|
| **1** | **Frozen PASS** @ `4412bb01` — do not re-run | [.codex-r3-tierb-rescore.log](./.codex-r3-tierb-rescore.log) |
| **3** | Codex wrote **84B stub** [feature-currency.md](file:///Users/shafqat/projects/enterprise-grade-test-app/.planning/workflows/feature-currency.md) only; **0 api/currency commits** despite `matrix_product_commit_clause` in prompt. Row log **15KB** — session queued prompt then exited before worker implementation. `planning-file-guard` blocked evidence writes (tui-watch). Outcomes: `OUT-PLAN-01` `OUT-TRACE-01` `OUT-CLARIFY-01` `OUT-VLOOP-01` partial → `OUT-WORLD-01` fail. | [.e2e-row3-codex-attempt.log](../../.e2e-row3-codex-attempt.log) |
| **6** | **Product commit** `b22b730` README landed. Outcome FAIL: `OUT-KM-01` partial — `graphify-out/graph.json` absent on fixture; `enabled_by_user: null` for graphify/agentmemory (`SB_E2E_SESSION0_SKIP=1`). `OUT-WORLD-01` fail (composite). | [.e2e-row6-codex-attempt.log](../../.e2e-row6-codex-attempt.log) |

**Harness fixes (force3 relaunch):**

| Fix | Implementation |
|-----|----------------|
| §5b early fail | `matrix.sh` — product delta check **before** outcome scorer on evidence-only rows |
| §5b rescore | `enterprise_e2e_assert_row_product_commit_rescore` in `core.sh`; poll-exit scripts |
| Row 6 outcome-only | `SB_E2E_OUTCOME_ONLY_ROWS=6` + frozen commit `b22b730` — §5b without new delta |
| Row 3 product anchor | commits required **after** `b22b730` (row-6 README preserved) |
| Session 0 | `SB_E2E_SESSION0_SKIP=0` on [codex-r3-force3-driver.sh](./codex-r3-force3-driver.sh) for KM opt-in |
| Driver | [codex-r3-force3-launch.sh](./codex-r3-force3-launch.sh) → tmux `codex-r3-force3` |

**Next:** force3+6 relaunch; on **3/3** rescore → auto [codex-r3-matrix-driver.sh](./codex-r3-matrix-driver.sh) (22/22 chain).

### Poll checkpoint 2026-07-02T15:35Z (force3 launch @ `8a077b1a`)

| Field | Value |
|-------|-------|
| **Harness** | `fb889d61` — §5b early gate + outcome-only row 6 + force3 driver + fixture Session0 opt-in |
| **Policy** | Frozen row **1** PASS; FORCE rows **3,6**; fixture pinned @ `b22b730` |
| **Session 0** | **ON** (`SB_E2E_SESSION0_SKIP=0`) for graphify/agentmemory opt-in |
| **Tier B driver** | tmux `codex-r3-force3:driver` PID **31332** |
| **Poll-exit** | tmux `codex-r3-force3:poll` → [.codex-r3-force3-poll-exit.sh](./.codex-r3-force3-poll-exit.sh) |
| **Chain monitor** | tmux `codex-r3-force3:chain` |
| **Tier C** | On **3/3** rescore → auto [codex-r3-matrix-driver.sh](./codex-r3-matrix-driver.sh) |
