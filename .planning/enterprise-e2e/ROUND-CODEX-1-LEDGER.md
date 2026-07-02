# Round Codex-1 Ledger — Enterprise E2E Matrix (Codex host)

Copy from template at round start. Host track runs **in parallel** with Claude Round 6 — use host-isolated lock/log paths only.

---

## Round metadata

| Field | Value |
|-------|-------|
| Round | Codex-1 |
| Host | `codex` |
| SB repo SHA | `959de0ea` |
| Codex plugin install | `959de0ea` *(install-codex.sh post-harness)* |
| Codex model (frozen) | gpt-5.4 / gpt-5.5 (ladder rungs 1–8) |
| Operator | Cursor Composer (Codex E2E subagent) |
| Start date | 2026-06-30 |
| End date | YYYY-MM-DD |
| Round clean? | Pass / Fail |
| Consecutive pair | ___ / 2 *(release requires 2/2 — see ROUND-CODEX-1-GATES.md)* |

**Harness artifacts (Codex-isolated):**

| Artifact | Path |
|----------|------|
| Matrix log | `.e2e-matrix-codex-live.log` |
| Batch PID | `.e2e-matrix-codex-batch.pid` |
| Live-test lock | `.e2e-live-test-codex.lock` |
| Row attempt log | `.e2e-row{N}-codex-attempt.log` |
| Monitor status | `.e2e-matrix-codex-monitor-status.txt` |
| TUI findings | `.e2e-tui-watch-codex-findings.jsonl` |

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

**Scope:** repo-wide (enterprise E2E: routes, hooks, skills, orchestrator, live wiring)

| Rung | Model / reasoning | Codex slug | audit_fix | verify_1 | orchestrator grep | verify_2 | Advanced |
|------|-------------------|------------|-----------|----------|-------------------|----------|----------|
| 1 | gpt-5.4 / low | PASS | PASS | PASS | PASS | PASS | PASS |
| 2 | gpt-5.4 / medium | PASS | PASS | PASS | PASS | PASS | PASS |
| 3 | gpt-5.4 / high | PASS | PASS | PASS | PASS | PASS | PASS |
| 4 | gpt-5.4 / xhigh | PASS | PASS | PASS | PASS | PASS | PASS |
| 5 | gpt-5.5 / low | PASS | PASS | PASS | PASS | PASS | PASS |
| 6 | gpt-5.5 / medium | PASS | PASS | PASS | PASS | PASS | PASS |
| 7 | gpt-5.5 / high | PASS | PASS | PASS | PASS | PASS | PASS |
| 8 | gpt-5.5 / xhigh | PASS | PASS | PASS | PASS | PASS | PASS |

**Ladder progress:** 8 / 8 rungs complete *(Phase A @761c7429)*

---

## Workflow matrix (22 rows)

| # | WF slug | Session date | Codex model | Pass/Fail | failure_class | Issues | SB fix commit | graphify_query_ref | agentmemory_export_ref |
|---|---------|--------------|-------------|-----------|---------------|--------|---------------|--------------------|------------------------|
| 1 | `silver-router` | 2026-06-30 | | **Pass** | — | FORCE row1 @78406; OUT-SKILL-01 fix ac4b9322 | ac4b9322 | graphify query "silver-router routes hooks skills orchestrator" | mem_mr0flf2a |
| 2 | `silver-research` | 2026-06-30 | | **Fail** | scorer-false-negative | transcript KM/ORCH pass @959de0ea; FORCE retry post-DRIVER_DONE_R3 | 959de0ea | graphify query "silver-research routes hooks skills orchestrator" | mem_mr0ghyhm |
| 3 | `silver-feature` | 2026-06-30 | | *(in flight)* | stop-hook-stall / quota | R3 PID 54793; retry #2 invoke 41641 (429→retry); harness 959de0ea for new invocations only | 959de0ea | graphify query "silver-feature routes hooks skills orchestrator" | mem_mr0iqx2q |
| 4 | `silver-bugfix` | 2026-06-30 | | **Fail** | hook-trust | resume pending | d24207e3 | | |
| 5 | `silver-ui` | 2026-06-30 | | **Fail** | hook-trust | resume pending | d24207e3 | | |
| 6 | `silver-fast` | 2026-06-30 | | **Pass** | — | strict-clean @ batch 65528 | | | |
| 7 | `silver-test` | 2026-06-30 | | **Pass** | — | strict-clean @ batch 65528 | | | |
| 8 | `silver-refactor` | 2026-06-30 | | **Fail** | km-gap | OUT-ORCH-01 partial OUT-KM-01 partial @860abb7c harness | | | |
| 9 | `silver-benchmark` | 2026-06-30 | | **Fail** | km-gap | OUT-KM-01 partial @860abb7c harness | | | |
| 10 | `silver-content` | 2026-06-30 | | **Fail** | km-gap | OUT-KM-01 partial @860abb7c harness | | | |
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

**Pass count:** 3 / 22 *(rows 1,6,7 strict-clean — hung batch 21441 killed; FORCE driver PID 29579 rows 4→2,3,5,8-22; rows 8-10 rescored FAIL km-gap @860abb7c)*

**Harness fixes (enterprise-e2e/codex):**
- *(pending commit)* — `CODEX_INTERACTIVE_IDLE_TIMEOUT` watchdog + non-blocking PTY read in `codex-interactive-invoke.py` (prevents 9h+ hung invoke)
- `959de0ea` — stop-hook quiet timeout (spinner-immune last_activity + completion without prompt return); CLAUDE→CODEX quiet timeout forward; SB_E2E_MATRIX_EVIDENCE_PATH scorer (75 tests)
- `b4f471b3` — TUI-aware KM/ORCH/HEAL outcome scoring (Codex mem_mr* + graphify query evidence path)
- `33c22980` — preserve CODEX_AUTO_TRUST_HOOKS from matrix spawn env
- `d24207e3` — hook trust auto-select + per-row seed + row_log append
- `ac4b9322` — OUT-SKILL-01 ANSI-normalized scoring (row 1)
- `f6c4843e` — `$silver` route prompt + outcome scorer backfill

**Prior harness fix:** `5796b145` — `trust_runtime_workspace()` in `setup_workspace()`.

Outcome companions: `.planning/enterprise-e2e/outcomes/codex-row-{N}-outcomes.md` (when host prefix enabled).

---

## Defects filed

| Issue | Label | WF slug | SB fix commit | Status |
|-------|-------|---------|---------------|--------|
| | `enterprise-test-app` | review-triad, ship-readiness | `5796b145` | fixed — trust seeding in setup_workspace |

---

## Round summary

**Graphify post-round:** `graphify update .` in SB repo.

**Next action:**

- If **not** strict-clean → fix SB, re-run failed Phase A/B/C rows in **Round Codex-1** (do not advance).
- If **strict-clean** → mark [ROUND-CODEX-1-GATES.md](./ROUND-CODEX-1-GATES.md) **1/2**, start **Round Codex-2** (fresh ledger, full Phase A–C per [CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md) §Two-round release gate).
- **Release sign-off** only after Round Codex-2 strict-clean + gates **2/2** — not after Round Codex-1 alone.
