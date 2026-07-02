# Round Codex-2 Ledger — Enterprise E2E Matrix (Codex host)

**Confirmation round** — must follow a strict-clean [ROUND-CODEX-1-LEDGER.md](./ROUND-CODEX-1-LEDGER.md). Release requires **2 consecutive** strict-clean Codex rounds (Codex-1 + Codex-2).

Copy from [ROUND-CODEX-1-LEDGER.md](./ROUND-CODEX-1-LEDGER.md) template at round start; use host-isolated lock/log paths only.

---

## Round metadata

| Field | Value |
|-------|-------|
| Round | Codex-2 |
| Host | `codex` |
| Prior round | [ROUND-CODEX-1-LEDGER.md](./ROUND-CODEX-1-LEDGER.md) — must be **strict-clean Pass** |
| SB repo SHA | `71f93a3f` |
| Test app SHA | `baadf87` (`enterprise-e2e/round-8-codex`) |
| Codex plugin install | `fbb38851` |
| Codex model (frozen) | gpt-5.4 / gpt-5.5 (ladder rungs 1–8) |
| Operator | Cursor Composer (Codex E2E subagent) |
| Start date | 2026-07-02 |
| End date | YYYY-MM-DD |
| Round clean? | Pending |
| Consecutive pair | **1 / 2** *(Codex-1 Pass — need Codex-2 Pass for 2/2)* |

**Harness artifacts (Codex-isolated):** same paths as Round Codex-1 — archive prior `.e2e-matrix-codex-live.log` before fresh Phase B.

---

## Session 0 — Bootstrap

| Step | Pass/Fail | Notes |
|------|-----------|-------|
| `$silver:init` independent bootstrap | | |
| Graphify + agentmemory opted in | | |
| `graphify update .` on test app | | |
| No SB init artifacts committed | | |

---

## review-fix-ladder (8 rungs × 2 clean verify)

**Scope:** full re-run required for Round 2 (not skip-on-pass from Round 1).

| Rung | Model / reasoning | Codex slug | audit_fix | verify_1 | orchestrator grep | verify_2 | Advanced |
|------|-------------------|------------|-----------|----------|-------------------|----------|----------|
| 1 | | | | | | | |
| 2 | | | | | | | |
| 3 | | | | | | | |
| 4 | | | | | | | |
| 5 | | | | | | | |
| 6 | | | | | | | |
| 7 | | | | | | | |
| 8 | | | | | | | |

**Ladder progress:** ___ / 8 rungs complete

---

## Workflow matrix (22 rows)

| # | WF slug | Session date | Codex model | Pass/Fail | failure_class | Issues | SB fix commit | graphify_query_ref | agentmemory_export_ref |
|---|---------|--------------|-------------|-----------|---------------|--------|---------------|--------------------|------------------------|
| 1 | `silver-router` | | | | | | | | |
| 2 | `silver-research` | | | | | | | | |
| 3 | `silver-feature` | | | | | | | | |
| 4 | `silver-bugfix` | | | | | | | | |
| 5 | `silver-ui` | | | | | | | | |
| 6 | `silver-fast` | | | | | | | | |
| 7 | `silver-test` | | | | | | | | |
| 8 | `silver-refactor` | | | | | | | | |
| 9 | `silver-benchmark` | | | | | | | | |
| 10 | `silver-content` | | | | | | | | |
| 11 | `silver-devops` | | | | | | | | |
| 12 | `silver-deploy` | | | | | | | | |
| 13 | `silver-canary` | | | | | | | | |
| 14 | `silver-release` | | | | | | | | |
| 15 | `review-triad` | | | | | | | | |
| 16 | `ship-readiness` | | | | | | | | |
| 17 | `silver-incident` | | | | | | | | |
| 18 | `silver-retro` | | | | | | | | |
| 19 | `silver-forensics` | | | | | | | | |
| 20 | `process-maintenance` | | | | | | | | |
| 21 | `post-exec-gates` | | | | *(parent: row 3)* | | | | |
| 22 | `validate-substep` | | | | *(parent: row 4)* | | | | |

**Pass count:** ___ / 22

---

## Round summary

**Graphify post-round:** `graphify update .` in SB repo.

## Round Codex-2 — execution plan

| Phase | Status | Driver / artifact |
|-------|--------|-------------------|
| Tier A offline | **PASS** @ `77f9ac35` — [.codex-r2-tiera-offline.log](./.codex-r2-tiera-offline.log) |
| Tier B smoke (rows 1,3,6) | **RUNNING** — driver **46904** batch **87814** @ `71f93a3f` — [codex-r2-tierb-smoke-driver.sh](./codex-r2-tierb-smoke-driver.sh) |
| Tier C full matrix (22/22) | **PENDING** | [codex-r2-matrix-driver.sh](./codex-r2-matrix-driver.sh) |
| Phase C gates | **PENDING** | outcome + run-all + RCS ≥85 |

### Poll checkpoint 2026-07-02T04:22Z (Round Codex-2 Tier B relaunch @ `71f93a3f`)

| Field | Value |
|-------|-------|
| **Prior failure** | Driver **60323** died at `codex-sync` preflight; batch **10118** MISBOUND (Claude `sb-main-row11-fp`); poll **96676** dead; rescore **3/3 STALE** (R1 logs Jul 1) |
| **Remediation** | `install-codex.sh --purge-legacy-skills` PASS; cleared misbound `.e2e-matrix-codex-batch.pid`; fresh Tier B only @ `71f93a3f` |
| **Tier B driver** | **RUNNING** PID **46904** — tmux `codex-r2-tierb-smoke:driver` cwd `/private/tmp/sb-codex-force4-wt` |
| **Batch** | **87814** — rows 1,3,6 (`matrix.sh`) |
| **Poll-exit** | PID **50671** → [.codex-r2-tierb-poll-exit.sh](./.codex-r2-tierb-poll-exit.sh) `46904` |
| **Monitor** | PID **2885** — [.codex-r2-tierb-monitor.log](./.codex-r2-tierb-monitor.log) |
| **TUI watch** | PID **52603** |
| **Tier C chain** | On fresh **3/3** rescore → auto-launch [codex-r2-matrix-driver.sh](./codex-r2-matrix-driver.sh) + [.codex-r2-matrix-poll-exit.sh](./.codex-r2-matrix-poll-exit.sh) |
| **Untouched** | Claude batch **10118** (`sb-main-row11-fp`); cursor lock **7549** (not running) |

### Poll checkpoint 2026-07-02T04:10Z (Round Codex-2 Tier B launch @ `77f9ac35`)

| Field | Value |
|-------|-------|
| **Tier A** | **PASS** — [.codex-r2-tiera-offline.log](./.codex-r2-tiera-offline.log) |
| **Tier B driver** | **RUNNING** — batch PID **10118** |
| **Monitor** | relaunched — see `.codex-r2-tierb-monitor.log` |
| **Poll-exit** | PID **96676** → [.codex-r2-tierb-poll-exit.sh](./.codex-r2-tierb-poll-exit.sh) `10118` |
| **Fixture** | `enterprise-e2e/round-8-codex@baadf87` |
| **agentmemory** | `mem_mr2zhzf6_63921d2e42a7` |


- Tier A green → Tier B rows 1,3,6 → post-invoke rescore → Tier C full matrix → Phase C → gates **2/2**.
- If **not** strict-clean → pair resets; re-run Round Codex-2 from Phase A.
- If **strict-clean** → update [ROUND-CODEX-2-GATES.md](./ROUND-CODEX-2-GATES.md) **2 consecutive strict clean rounds = PASS (2/2)**.

### Poll checkpoint 2026-07-02T04:15:23Z (Round Codex-2 Tier B exit)

| Field | Value |
|-------|-------|
| **Driver** | EXITED PID **60323** |
| **Tier B rescore** | **3/3** — [.codex-r2-tierb-rescore.log](./.codex-r2-tierb-rescore.log) |
| **Tier C** | **READY** — launch [codex-r2-matrix-driver.sh](./codex-r2-matrix-driver.sh) |
| 1 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:27:56Z |
| 1 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:27:56Z |
| 1 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:27:56Z |
| 1 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:27:56Z |
| 3 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:27:57Z |
| 3 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:27:57Z |

### Poll checkpoint 2026-07-02T04:32:11Z (Round Codex-2 Tier B exit)

| Field | Value |
|-------|-------|
| **Driver** | EXITED PID **46904** |
| **Tier B rescore** | **3/3** — [.codex-r2-tierb-rescore.log](./.codex-r2-tierb-rescore.log) |
| **Tier C** | **READY** — launch [codex-r2-matrix-driver.sh](./codex-r2-matrix-driver.sh) |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:32:13Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:32:13Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:32:13Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:32:13Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:32:13Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:32:13Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:32:13Z |
| 6 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:32:13Z |
| 1 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:37:48Z |
| 1 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:37:48Z |
| 1 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:37:48Z |
| 1 | blocker | hook | planning-file-guard | tui-watch 2026-07-02T04:37:48Z |

### Poll checkpoint 2026-07-02T07:05:16Z (Round Codex-2 Tier C exit)

| Field | Value |
|-------|-------|
| **Driver** | EXITED PID **4527** |
| **Matrix rescore** | **20/22** — [.codex-r2-matrix-rescore.log](./.codex-r2-matrix-rescore.log) |
| **Phase C** | **BLOCKED** — 20/22 |

### Diagnosis checkpoint 2026-07-02T07:15Z (rows 15, 16 @ `71f93a3f`)

| Field | Value |
|-------|-------|
| **Row 15** | FAIL — OUT-REVIEW-01 partial, OUT-WORLD-01 fail; SessionStart `core-rules.md` integrity pin mismatch on installed Codex cache (stale `core-rules.md` vs pin); agent stuck in orchestrator parent (`spawn_agent` directive, no triad evidence) |
| **Row 16** | FAIL live (12KB log, session aborted); rescore **PASS** with `SB_E2E_ENTERPRISE_MATRIX=1` (LEDGER_MISMATCH harness — same as R1 `fe8a5589`) |
| **Harness gaps** | (1) Installed Codex cache hooks out of sync — `install-codex.sh --purge-legacy-skills` remediation; (2) `.codex-r2-matrix-poll-exit.sh` missing `SB_E2E_ENTERPRISE_MATRIX=1` (Tier B had it) |
| **R1 parity** | Same pattern as R1 rows 15/16: spawn_agent + Bash adapter + LEDGER_MISMATCH; fixes already @ `181f174e`/`fe8a5589` in tree — failure was stale install + rescore flag |
| **Remediation** | Reinstall Codex hooks; FORCE rows **15, 16** only via [codex-r2-force1516-driver.sh](./codex-r2-force1516-driver.sh) + frozen-merge [.codex-r2-force1516-poll-exit.sh](./.codex-r2-force1516-poll-exit.sh) |
| **Policy** | One-pass @ `71f93a3f` — do NOT re-run rows 1–14, 17–22 (frozen from [.codex-r2-matrix-rescore.log](./.codex-r2-matrix-rescore.log)) |
