# Codex & Cursor Enterprise E2E Prompts — Adversarial Review

**Date:** 2026-06-30  
**Reviewer lens:** Day-1 execution failure, strict-clean honesty, cross-host isolation vs Claude Round 6  
**Artifacts reviewed:**

- [CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md)
- [CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md)
- [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md)
- [ROUND-6-SESSION-HANDOFF.md](./ROUND-6-SESSION-HANDOFF.md)
- [ENTERPRISE-E2E-OPERATOR-PROMPT.md](../../scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md)
- [OUTCOME-ASSESSMENT-RUBRIC.md](./OUTCOME-ASSESSMENT-RUBRIC.md)
- [ENTERPRISE-E2E-LIVE-TEST.md](../../docs/ENTERPRISE-E2E-LIVE-TEST.md)
- [ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md](../../docs/testing/ENTERPRISE-E2E-EFFECTIVENESS-PLAN.md)
- [ENTERPRISE-E2E-SESSION-PROMPT.md](https://github.com/alo-exp/enterprise-grade-test-app/blob/main/docs/ENTERPRISE-E2E-SESSION-PROMPT.md)
- [CLAUDE-TUI-PROTOCOL.md](./CLAUDE-TUI-PROTOCOL.md)
- Harness: `run-enterprise-e2e-live-test.sh`, `run-enterprise-e2e-matrix.sh`, `monitor-enterprise-e2e-matrix.sh`, `watch-enterprise-e2e-tui.sh`, `tests/live/agents/{codex,cursor}/agent.sh`, `tests/e2e-live/helpers.sh`

---

## Executive verdict

### **READY WITH GAPS** (session launch allowed; strict-clean 2×22 still requires live proof)

Post-rearchitecture shared harness review: [SHARED-HARNESS-ADVERSARIAL-REVIEW.md](./SHARED-HARNESS-ADVERSARIAL-REVIEW.md) — **2 consecutive clean passes** (pass 2 + 3) after P0/P1 harness fixes. Structural suite **179/0**; outcome **69/0**.

**Honest current capability:** Phase A smoke/resolver + tri-host install; Phase B matrix driver **wired** for Codex/Cursor (dry-run verified); autonomous 2× strict-clean 22-row matrix still requires live sessions and M7 fixtures.

---

## Review run history

| Pass | Timestamp (UTC) | Verdict | Notes |
|------|-----------------|---------|-------|
| 0 (initial) | 2026-06-30 | **NOT READY** | P0-1–P0-10; harness Claude-only; shared locks/logs |
| 1 | 2026-06-30T12:00:00Z | **READY WITH GAPS** | M1–M6 done; prompts patched; structural suite 155/0; outcome 69/0; codex dry-run row 1 invokes Codex agent |
| 2 | 2026-06-30T12:15:00Z | **READY WITH GAPS** | Re-review: no new P0/P1; P2 follow-ups unchanged; consecutive clean |
| 3 (shared harness) | 2026-06-30T18:00:00Z | **NOT READY** | Post-reorg pass 1: P0 runtime leak (`live-test.sh:151`), P0 consecutive-rounds SB_ROOT, P1 monitor pgrep — see [SHARED-HARNESS-ADVERSARIAL-REVIEW.md](./SHARED-HARNESS-ADVERSARIAL-REVIEW.md) |
| 4 (shared harness) | 2026-06-30T18:30:00Z | **READY WITH GAPS** | Fixes applied; structural 179/0; outcome 69/0 |
| 5 (shared harness) | 2026-06-30T18:45:00Z | **READY WITH GAPS** | Confirmatory pass 3 — **2 consecutive clean** (no P0/P1) |

## M1–M6 acceptance (post-fix)

| ID | Status | Evidence |
|----|--------|----------|
| M1 | **DONE** | `enterprise_e2e_apply_matrix_host_defaults`; no `export SB_E2E_LIVE_RUNTIME=claude` overwrite; dry-run `Host: codex` + `/Applications/Codex.app/.../codex` |
| M2 | **DONE** | `helpers.sh` cursor case; `run-enterprise-e2e-live-test.sh --host codex\|cursor\|claude`; `enterprise_e2e_run_install_host` |
| M3 | **DONE** | `.e2e-live-test-{host}.lock`, `.e2e-matrix-{host}-*`, `.e2e-row{N}-{host}-attempt.log` (Claude keeps legacy names) |
| M4 | **DONE** | `matrix_agent_child_lines` / `kill_matrix_agent_children` host-scoped in monitor |
| M5 | **DONE** | `enterprise_e2e_routing_state_file` → `SB_RUNTIME_STATE_DIR`; outcome assess uses runtime state in matrix |
| M6 | **DONE** | `enterprise_e2e_matrix_host_route` — `/silver:feature` → `$silver:feature` (Codex); skill slug (Cursor) |
| M8 | **DONE** | `ROUND-CODEX-1-LEDGER.md`, `ROUND-CURSOR-1-LEDGER.md` with ladder tables |
| M9 | **PARTIAL** | `$silver:clarify` grep added; `SB_E2E_RCS_TRIHOST=full` documented in prompts, not auto in `enterprise-e2e-rcs.sh` |
| M10 | **DONE** | `CODEX-TUI-PROTOCOL.md`, `CURSOR-TUI-PROTOCOL.md` linked from prompts |

---

## Remaining P2 follow-up (non-blocking for session launch)

| # | Item | Notes |
|---|------|-------|
| P2-7 | M7 — one full row live CI fixture per host | `test-enterprise-e2e-live-suite.sh` structural only |
| P2-10 | Codex matrix expect parity suite | No `tests/enterprise-e2e-live/*codex*` yet |
| P2-11 | Host-prefixed outcome companion paths | `row-N-outcomes.md` not yet `{host}-row-N` |
| P2-15 | RCS auto `SB_E2E_RCS_TRIHOST=full` | Manual export in Phase C prompts |
| — | Parallel tracks mutating same test-app fixture | Document serial mutation or branch-per-host for rows 21–22 |

---

## Critical blockers (P0) — RESOLVED in pass 1

| # | Gap | Resolution |
|---|-----|------------|
| P0-1 | Matrix runner Claude-only | `enterprise_e2e_apply_matrix_host_defaults` honors pre-set runtime |
| P0-2 | No `--host` on live-test | `--host codex\|cursor\|claude` + `enterprise_e2e_run_install_host` |
| P0-3 | helpers.sh no cursor | `cursor/agent.sh` sourced |
| P0-4 | Shared lock | Per-host lock files (Claude keeps `.e2e-live-test.lock`) |
| P0-5 | Shared row logs | `enterprise_e2e_row_attempt_log` host prefix |
| P0-6 | Monitor Claude-only pkill | `matrix_agent_child_lines` host-scoped |
| P0-7 | No host ledgers | Templates added |
| P0-8 | Wrong batch PID paths | Defaults + prompt env blocks |
| P0-9 | `/silver:*` literals only | `enterprise_e2e_matrix_host_route` |
| P0-10 | Claude-only routing state | `enterprise_e2e_routing_state_file` |

---

## Prior executive verdict (pass 0 — superseded)

### ~~NOT READY~~ (2026-06-30 initial review)

1. **Fail Phase B immediately** — matrix runner hardcodes Claude and overwrites `SB_E2E_LIVE_RUNTIME` / `SILVER_BULLET_RUNTIME`.
2. **Corrupt or block Claude Round 6** — shared `.e2e-live-test.lock`, `.e2e-row{N}-attempt.log`, default `.e2e-matrix-batch.pid`, and monitor `pkill` patterns are not host-isolated.
3. **Cannot score strict-clean honestly** — outcome harness, routing state, clarify markers, and RCS tri-host defaults are Claude-centric; Cursor lacks `helpers.sh` runtime wiring; ledger templates for host tracks do not exist.

**Honest current capability:** Phase A **partial** (resolver/smoke for Cursor; Codex ladder smoke exists), tri-host **install smoke** per host, manual TUI sessions with operator babysitting — **not** autonomous 2× strict-clean 22-row matrix.

---

## Critical blockers (P0) — must fix before sessions launch

| # | Gap | Evidence | Impact |
|---|-----|----------|--------|
| P0-1 | **Matrix runner is Claude-only; env override is a lie** | `run-enterprise-e2e-matrix.sh:40-41` **assigns** `SB_E2E_LIVE_RUNTIME=claude` and `SILVER_BULLET_RUNTIME=claude` after caller export. Lines 334, 458-468 say "launching interactive Claude session", `bootstrap_claude_dependencies`, `claude_matrix_export_settings_env`. Codex/Cursor prompts Phase B §1–3 claim `SB_E2E_LIVE_RUNTIME=codex|cursor` is sufficient. | Day-1: matrix always spawns Claude; Codex/Cursor tracks never start. |
| P0-2 | **`run-enterprise-e2e-live-test.sh` has no `--host`; always Claude install/auth** | `run-enterprise-e2e-live-test.sh:146-147` `enterprise_e2e_run_install_claude` + `enterprise_e2e_preflight_claude_token_gateway`. Prompts acknowledge gap (Known harness gaps table) but Mission still requires full live entrypoint parity. | Cannot use canonical live driver for Codex/Cursor; pre-matrix validation gate + monitor/watch spawn remain Claude-bound. |
| P0-3 | **`tests/e2e-live/helpers.sh` has no `cursor` runtime** | `helpers.sh:96-112` — `case` supports `claude`, `codex`, `kay` only; `*)` exits 2. `cursor/agent.sh` exists but is **never sourced** by matrix path. | Cursor matrix cannot invoke `agent_invoke` through shared live harness. |
| P0-4 | **Shared lock file blocks parallel tracks** | `enterprise-e2e-live-common.sh:203` `.e2e-live-test.lock` is global. Codex/Cursor resume §2 `rm -f .e2e-live-test.lock` would **steal or clear Claude Round 6 lock** ([ROUND-6-SESSION-HANDOFF.md](./ROUND-6-SESSION-HANDOFF.md) active driver). | Parallel Codex/Cursor + Claude Round 6 is unsafe; resume instructions are hostile to Round 6. |
| P0-5 | **Shared row attempt logs** | `run-enterprise-e2e-matrix.sh:326-329` writes `${SB_ROOT}/.e2e-row${row_num}-attempt.log` with **no host prefix**. | Parallel tracks overwrite each other's evidence/outcome inputs → false PASS/FAIL, strict-clean impossible. |
| P0-6 | **Monitor kills only Claude children** | `monitor-enterprise-e2e-matrix.sh:101-102,263-269,369-370,532-541` — `claude_child_lines`, `kill_claude_children`, "no claude child" restart logic. | Codex/Cursor batches appear hung; monitor may restart wrong batch or never detect stall; **risk of killing Claude Round 6 children** if patterns broaden without host filter. |
| P0-7 | **Host ledger files do not exist** | Glob: no `ROUND-CODEX-1-LEDGER.md`, `ROUND-CURSOR-1-LEDGER.md`. Only [ROUND-N-LEDGER.md](./ROUND-N-LEDGER.md) (Claude-centric: "Claude model", `/silver:init`). | Fresh session has no scoring template, no ladder table, reconcile/RCS read wrong ledger. |
| P0-8 | **Batch PID paths in prompts are wrong** | Prompts resume: `kill -0 "$(cat .e2e-matrix-codex-batch.pid)"` / `.e2e-matrix-cursor-batch.pid`. Harness: `enterprise_e2e_matrix_batch_pid_file()` defaults to `.e2e-matrix-batch.pid` unless `SB_E2E_MATRIX_BATCH_PID_FILE` set — **not documented** in Dual-role monitoring or Resume sections. | Operator thinks driver dead when PID file is empty; may spawn duplicate drivers. |
| P0-9 | **MATRIX_ROWS routes are Claude `/silver:*` literals** | `run-enterprise-e2e-matrix.sh:77-98` embed `/silver`, `/silver:feature`, etc. `build_matrix_prompt:160-161` documents "Native /silver:* subcommands are not registered in Claude TUI". | Even after host wiring, Codex (`$silver:*`) and Cursor (skills/natural language) need **host-aware route column** or prompts mis-route. |
| P0-10 | **Routing/outcome state hardcoded to Claude path** | `run-enterprise-e2e-matrix.sh:164-165` `claude_routing_state_file` → `~/.codex/.silver-bullet/state`. `enterprise-e2e-matrix-quiesce.sh:53` same. Outcome scoring uses passed `state_dir` but matrix always passes Claude default (`:374-386`). | Row 1 PASS and OUT-SKILL/OUT-ORCH/OUT-CLARIFY false negatives on Codex/Cursor state roots. |

---

## High gaps (P1) — prompt edits needed

| # | Gap | File:section | Fix |
|---|-----|--------------|-----|
| P1-1 | **No standalone TUI protocol docs** (Claude has [CLAUDE-TUI-PROTOCOL.md](./CLAUDE-TUI-PROTOCOL.md)) | Codex §"Codex TUI protocol" (~L277); Cursor §"Cursor agent TUI protocol" (~L301) — 15–30 lines inline only | Add `CODEX-TUI-PROTOCOL.md`, `CURSOR-TUI-PROTOCOL.md` mirroring Claude checklist depth (Session 0, per-row, pass/fail, graphify/agentmemory, quiet timeouts). |
| P1-2 | **Parent orchestrator host ambiguous for Codex track** | Codex §"Parent orchestrator ops" (~L313) assumes Cursor `Task` tool | State explicitly: **supervisor runs in Cursor Composer** (parent), matrix TUI is Codex CLI; Codex TUI cannot spawn `Task`. |
| P1-3 | **Watch/monitor env repoint incomplete** | Codex Dual-role (~L232-238); Cursor (~L254-260) | Document full isolation bundle: `SB_E2E_MATRIX_LOG`, `SB_E2E_LEDGER_FILE`, `SB_E2E_MATRIX_BATCH_PID_FILE`, `SB_E2E_MATRIX_MONITOR_PID_FILE`, `SB_E2E_MATRIX_MONITOR_STATUS_FILE`, `SB_E2E_TUI_FINDINGS`, `SB_E2E_TUI_OFFSETS`, `SB_E2E_TUI_WATCH_PID`, `SB_E2E_MATRIX_DRIVER_LOG`. |
| P1-4 | **Cross-host isolation policy missing** | Both prompts §"Parallel track" (~L5-6) | Add **do-not-touch** list: never `rm .e2e-live-test.lock` while Round 6 alive; never `pkill -f claude` from Codex/Cursor monitor; never share `.e2e-row*-attempt.log`; pin separate tmux session names (`codex-e2e` / `cursor-e2e` vs `round6-force`). |
| P1-5 | **OUT-CLARIFY-01 host markers incomplete** | `enterprise-e2e-outcome-assessment.sh:192` greps `/silver:clarify\|silver:clarify` only; not `$silver:clarify` | Prompts must require post-row re-score + document harness gap; patch scorer for Codex `$silver:clarify` until harness fixed. |
| P1-6 | **Phase C RCS tri-host not wired in commands** | Codex Phase C (~L269-270); Cursor (~L293-294) run `run-tri-host-install-smoke.sh --host` but **never** `SB_E2E_RCS_TRIHOST=full` (`enterprise-e2e-rcs.sh:121` defaults `claude-only` → 3/10) | Add explicit `SB_E2E_RCS_TRIHOST=full` when host smoke passes; else RCS ≥85 is **unreachable** (max tri-host 3). |
| P1-7 | **Validation overlay pre-matrix gate omitted** | [ENTERPRISE-E2E-OPERATOR-PROMPT.md](../../scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md) §Validation (~L70-80); absent from Codex/Cursor Phase B bootstrap | Add gate before matrix: `run-enterprise-e2e-validation-overlay.sh --dry-run` with host ledger path. |
| P1-8 | **failure_class taxonomy missing** | Operator prompt §Failure classification (~L123-135) | Require ledger column on every FAIL row (`harness` \| `product` \| `environmental`) + `matrix-failure-class.sh` helper. |
| P1-9 | **WBS / OUT-SUPER-01 supervision thin** | ROUND-6 addendum §F (~L70-81); rubric OUT-SUPER-01 | Add per-row check: `wbs-supervisor` in log, `current_flow` empty at boundary, composition log worker completion. |
| P1-10 | **Session 0 programmatic path underspecified** | Operator prompt §Operator autonomy (~L209-214) | Copy verbatim: fixture `.silver-bullet.json` opt-in, `SB_E2E_SESSION0_SKIP_REASON`, agentmemory health URL, no TUI block. |
| P1-11 | **Round 2 / ledger ladder section** | Prompts Phase A gate (~L165-166) reference ladder in ledger; [ROUND-N-LEDGER.md](./ROUND-N-LEDGER.md) has **no ladder table** | Host ledger templates need 8-rung audit_fix/verify_1/verify_2 table (OUT-REVIEW-01). |
| P1-12 | **OUTCOME companion files** | Rubric Harness usage (~L356-373) `row-N-outcomes.md` | Mandate `enterprise_e2e_outcome_write_workflow_checklist` per row into `.planning/enterprise-e2e/outcomes/` with host prefix. |
| P1-13 | **Compaction policy** | ROUND-6 addendum §E (~L67) "Compaction on context full — **not** `/clear`" | Missing from both host prompts — fresh session may `/clear` and lose worker resume ID. |
| P1-14 | **Cursor Phase A overclaims live 8/8** | `test-live-review-fix-ladder-full-ladder.sh:190-204` defaults `SB_LIVE_REVIEW_FIX_LADDER_CURSOR_RESOLVER_ONLY=1` → skips API turns | Prompt must state strict-clean requires `SB_LIVE_REVIEW_FIX_LADDER_CURSOR_RESOLVER_ONLY=0` + `CURSOR_API_KEY` + live turns, or Phase A is structural-only. |

---

## Medium gaps (P2) — harness work in SB repo

| # | Work item | Location | Notes |
|---|-----------|----------|-------|
| P2-1 | Honor `SB_E2E_LIVE_RUNTIME` / `SILVER_BULLET_RUNTIME` if pre-set; stop overwriting | `run-enterprise-e2e-matrix.sh:40-41` | `${SB_E2E_LIVE_RUNTIME:=claude}` pattern |
| P2-2 | Host-aware agent bootstrap (`install-{codex,cursor}.sh`, drop `claude_matrix_export_settings_env` for non-Claude) | matrix runner + live-test entrypoint | |
| P2-3 | Add `cursor` case to `helpers.sh` agent `case` | `tests/e2e-live/helpers.sh:96-112` | Source `tests/live/agents/cursor/agent.sh` |
| P2-4 | `run-enterprise-e2e-live-test.sh --host codex\|cursor\|claude` | new flag + skip Claude-only preflight per host | |
| P2-5 | Host-prefixed row logs: `.e2e-{host}-row{N}-attempt.log` or `SB_E2E_MATRIX_ROW_LOG_PREFIX` | matrix runner | |
| P2-6 | Per-host lock: `.e2e-live-test-{host}.lock` or `SB_E2E_LIVE_TEST_LOCK_FILE` default by runtime | `enterprise-e2e-live-common.sh` | |
| P2-7 | Monitor/watch host child detection (`codex-interactive-invoke`, `cursor-agent`, `agent -p`) | `monitor-enterprise-e2e-matrix.sh`, `watch-enterprise-e2e-tui.sh` | Scope `pkill` by `SB_E2E_LIVE_RUNTIME` |
| P2-8 | `SB_RUNTIME_STATE_DIR` resolution per host in matrix verify paths | matrix runner, quiesce lib | `~/.codex/`, `~/.cursor/`, etc. |
| P2-9 | Host-aware MATRIX_ROWS route column or `matrix_host_route()` | matrix runner | Map slug → `$silver:*` / skill name / NL |
| P2-10 | Codex matrix expect parity | prompts cite `codex-interactive-invoke.expect`; no `tests/enterprise-e2e-live/*codex*` suite | Fork row-completion patterns from Claude expects |
| P2-11 | `enterprise_e2e_outcome_score_clarify` — `$silver:clarify`, Cursor skill aliases | `enterprise-e2e-outcome-assessment.sh` | |
| P2-12 | CI structural tests for host matrix wiring | `test-enterprise-e2e-live-suite.sh` — **zero** codex/cursor host references | |
| P2-13 | `ROUND-CODEX-1-LEDGER.md`, `ROUND-CURSOR-1-LEDGER.md` templates | `.planning/enterprise-e2e/` | Host metadata, ladder section, model column |
| P2-14 | `hook-delivery-preflight.sh` host docs | prompts set `SB_E2E_LIVE_AGENT=codex|cursor` but script has no visible host branches | Verify + document |
| P2-15 | RCS: auto-set `SB_E2E_RCS_TRIHOST=full` when `--host` smoke passes in Phase C | `enterprise-e2e-rcs.sh` | |

---

## Per-prompt scorecard

Scoring: **0–10** per success criterion (10 = prompt + harness fully aligned). **Harness-adjusted** = what happens if operator follows prompt literally today.

### Codex — [CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md)

| # | Criterion | Prompt | Harness-adjusted | Notes |
|---|-----------|--------|------------------|-------|
| 1 | 2× strict-clean rounds | 8 | **1** | Mission clear; not achievable |
| 2 | Phase A ladder 8/8 × 2 verify | 7 | **5** | Smoke/full scripts exist for codex; ledger template missing |
| 3 | Phase B 22/22 + 27 criteria | 7 | **0** | Known gaps table honest; Mission contradicts |
| 4 | Phase C gates + RCS ≥85 | 6 | **4** | Missing `SB_E2E_RCS_TRIHOST=full`; live-test still Claude |
| 5 | Parent orchestrator ONE worker 60–90s | 9 | **8** | Mirrors Round 6; Task tool host unclear |
| 6 | Never pause; 429 1min; no claude login | 9 | **7** | Good; lock removal endangers Round 6 |
| 7 | Recommended tools enforced | 7 | **5** | Listed; no code-intel preflight in bootstrap |
| 8 | WBS supervision outcomes | 4 | **3** | Rubric not operationalized |
| 9 | Autonomous / world-class | 6 | **2** | Blocked by harness |
| 10 | Issues baseline 76 / 0 new | 8 | **8** | Pinned correctly |
| 11 | Single driver / no duplicate subagents | 8 | **3** | Shared PID/log paths defeat this |
| 12 | Codex TUI E2E runnable | 6 | **2** | Adapter exists; matrix never calls it |
| | **Average** | **7.0** | **3.2** | |

### Cursor — [CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md)

| # | Criterion | Prompt | Harness-adjusted | Notes |
|---|-----------|--------|------------------|-------|
| 1 | 2× strict-clean rounds | 8 | **1** | Same matrix blocker |
| 2 | Phase A ladder 8/8 × 2 verify | 7 | **3** | Resolver-only default; not 8 live rungs |
| 3 | Phase B 22/22 + 27 criteria | 7 | **0** | helpers.sh no cursor |
| 4 | Phase C gates + RCS ≥85 | 7 | **4** | Extra CLI smoke; tri-host RCS still capped |
| 5 | Parent orchestrator | 9 | **8** | composer-2.5 policy explicit (+1 vs Codex) |
| 6 | Never pause; 429; no claude login | 9 | **7** | CURSOR_API_KEY headless documented |
| 7 | Recommended tools enforced | 7 | **5** | Same as Codex |
| 8 | WBS supervision | 4 | **3** | Same gap |
| 9 | Autonomous / world-class | 6 | **2** | |
| 10 | Issues baseline 76 | 8 | **8** | |
| 11 | Single driver | 8 | **3** | |
| 12 | Cursor agent TUI E2E | 7 | **2** | CLI `--print` path exists; matrix unwired; in-session needs human |
| | **Average** | **7.3** | **3.0** | |

**Codex vs Cursor:** Cursor prompt is marginally stronger on auth (API key, `AGENT_CLI_CREDENTIAL_STORE`), subagent model policy, and CLI smoke in Phase C. Codex prompt is stronger on TUI invoke table (`$silver:*`). **Both fail the same harness wall.**

---

## What will fail on day 1

| Order | Failure | Root cause |
|-------|---------|------------|
| 1 | `bash scripts/run-enterprise-e2e-matrix.sh` with `SILVER_BULLET_RUNTIME=codex` still runs Claude | P0-1 hardcode + overwrite |
| 2 | Cursor track: `helpers.sh` unsupported runtime if matrix ever fixed | P0-3 |
| 3 | Resume `kill -0 .e2e-matrix-codex-batch.pid` → empty / wrong PID | P0-8 |
| 4 | Parallel launch trips `.e2e-live-test.lock` or corrupts row 6/7/8/11 logs | P0-4, P0-5 vs Round 6 handoff |
| 5 | Monitor reports hung, suggests kill — wrong process class | P0-6 |
| 6 | Row 1 "PASS" in Claude state while Codex session ran | P0-10 |
| 7 | Phase A "8/8" for Cursor without `CURSOR_API_KEY` live turns | P1-14 |
| 8 | Phase C RCS stuck ≤~83 even on perfect ledger | P1-6 (`claude-only` tri-host) |
| 9 | OUT-CLARIFY false fail on Codex rows 1–3 | P1-5 (`$silver:clarify` not in grep) |
| 10 | Ledger reconcile / monitor COMPLETE mismatch | No host ledger file (P0-7) |

---

## Missing vs Claude canonical stack

| Claude source | Codex prompt | Cursor prompt |
|---------------|--------------|---------------|
| [CLAUDE-TUI-PROTOCOL.md](./CLAUDE-TUI-PROTOCOL.md) (full) | 30-line inline | 35-line inline |
| [ENTERPRISE-E2E-OPERATOR-PROMPT.md](../../scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md) failure_class | ❌ | ❌ |
| Validation overlay pre-matrix default | ❌ | ❌ |
| `SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT` semantics | N/A (Codex) | ❌ |
| OAuth "Not logged in" cosmetic banner | N/A | ❌ |
| Network backoff 120–300s | ❌ | ❌ |
| `enterprise_e2e_outcome_row_passes` per-row FORCE retry | Mentioned in gaps table only | Same |
| [ROUND-N-OUTCOMES.md](./ROUND-N-OUTCOMES.md) companion | ❌ | ❌ |
| Round ledger ladder 8-rung table | ❌ | ❌ |
| Cherry-pick branch (`enterprise-e2e/round6`) | Generic link | Generic link |
| Code-intel preflight (`graphify query` recorded) | Partial | Partial |
| Compaction-not-/clear | ❌ | ❌ |

---

## Ambiguous — fresh session misinterpretation

1. **"Extend harness if Claude-only"** (one-liner, Phase B) — sounds optional; Mission treats 22/22 as mandatory. **Fix:** separate **MVP smoke** (tri-host + ladder smoke) from **strict-clean** (blocked on P2 list).

2. **Who is "this chat" for parent orchestrator?** Codex prompt in Codex TUI vs Cursor Composer. **Fix:** "Supervisor session = Cursor Composer with silver-orchestrator parent; matrix child = Codex/Cursor CLI."

3. **Watch "repoint log env"** — operators set only `SB_E2E_MATRIX_LOG`. **Fix:** copy-paste env block (P1-3).

4. **`tmux new-session -d -s codex-e2e`** — `SB_ROOT` not exported inside `bash -lc` quote in resume snippet (`CODEX:376-380`). **Fix:** `export SB_ROOT=...` inside tmux command.

5. **Rows 21–22 "via parents"** — matrix internal verify still checks parent row artifacts in shared fixture; parallel tracks mutating same test app → **fixture state collision**. **Fix:** document serial test-app mutation or branch-per-host policy.

6. **Evidence PASS vs outcome PASS** — strict-clean defined but no step-by-step "re-score row N after FORCE" command block.

7. **Phase B Option A vs B** — both shown as equal; Option A cannot work pre-P2-1.

---

## Overclaimed

| Claim | Reality |
|-------|---------|
| "Phase B: 22-row matrix via `SILVER_BULLET_RUNTIME=codex\|cursor`" | Runtime export ignored by matrix runner |
| "Live matrix 22/22 evidence PASS" as strict-clean component | No host matrix driver; DRY_RUN/SKIP rows exist in Claude runs |
| "tri-host includes Codex/Cursor" for RCS Phase C | Smoke yes; RCS tri-host score defaults 3/10 |
| "Parallel to Claude Round 6" without isolation spec | Shared lock, logs, default PIDs — **not parallel-safe** |
| Cursor "Phase A: 8/8" via `test-live-review-fix-ladder-full-ladder.sh` | Default resolver-only skips live rungs |
| "Known harness gaps" table implies operator can patch inline | Correct policy says SB repo — but prompts still present runnable-looking commands that fail silently |

---

## Recommended prompt patches (specific sections)

### Both prompts — add after §Session workspace

**§Cross-host isolation (mandatory when Round 6 Claude active)**

```markdown
- Do NOT remove `.e2e-live-test.lock` unless Round 6 Claude driver is confirmed dead.
- Set before any matrix/monitor/watch launch:
  export SB_E2E_MATRIX_BATCH_PID_FILE=.e2e-matrix-{HOST}-batch.pid
  export SB_E2E_MATRIX_MONITOR_PID_FILE=.e2e-matrix-{HOST}-monitor.pid
  export SB_E2E_MATRIX_MONITOR_STATUS_FILE=.e2e-matrix-{HOST}-monitor-status.txt
  export SB_E2E_TUI_FINDINGS=.e2e-tui-watch-{HOST}-findings.jsonl
  export SB_E2E_TUI_OFFSETS=.e2e-tui-watch-{HOST}-offsets.json
  export SB_E2E_LIVE_TEST_LOCK_FILE=.e2e-live-test-{HOST}.lock  # when harness supports
- Never run monitor pkill helpers from Claude track against Codex/Cursor PIDs.
```

### Both prompts — replace Phase B opening

```markdown
### Phase B status: BLOCKED on harness (see P2 minimum list)

Until `run-enterprise-e2e-matrix.sh` honors `SB_E2E_LIVE_RUNTIME`, do NOT claim 22/22.
Allowed pre-wire work: tri-host smoke, single-row manual TUI proof (`SB_E2E_MATRIX_FORCE=1` row N), harness PR on SB repo.
```

### Codex §Codex TUI protocol — add

- Quiet timeout env mapping (`CODEX_INTERACTIVE_TIMEOUT` vs Claude names)
- `$silver:clarify` for OUT-CLARIFY-01
- Link to future `CODEX-TUI-PROTOCOL.md`
- State root: `${SB_RUNTIME_STATE_DIR:-$HOME/.codex/.silver-bullet}` (when wired)

### Cursor §Cursor agent TUI protocol — add

- Headless vs `SB_LIVE_CURSOR_IN_SESSION=1` matrix mode selection
- `SB_LIVE_REVIEW_FIX_LADDER_CURSOR_RESOLVER_ONLY=0` for strict-clean Phase A
- `--model composer-2.5` on CLI (already in spawn block — reference in Phase A)
- `silver-clarify` / `/silver` clarify aliases for outcome grep

### Both prompts — Phase C append

```bash
export SB_E2E_RCS_TRIHOST=full  # after --host smoke passes
SB_E2E_RCS_VALIDATION_OVERLAY=pass RTK_DISABLED=1 bash scripts/enterprise-e2e-rcs.sh
```

### Both prompts — §Parent orchestrator ops

- Add: context compaction allowed; **do not** `/clear` (lose worker resume)
- Add: after each row `enterprise_e2e_outcome_write_workflow_checklist` + blocking gate check

### ROUND-6-OPERATIONAL-ADDENDUM.md

- §C friction watch: split log paths by host (`SB_E2E_MATRIX_LOG`), not only `.e2e-matrix-round6-force.log`

---

## Minimum harness work before "22-row" is honest

**Gate label:** `enterprise-e2e-matrix-host-ready`

| Priority | Deliverable | Acceptance |
|----------|-------------|------------|
| M1 | Matrix runner respects `SB_E2E_LIVE_RUNTIME` | `SILVER_BULLET_RUNTIME=codex bash scripts/run-enterprise-e2e-matrix.sh 1` invokes `codex/agent.sh`, not Claude |
| M2 | `helpers.sh` + live-test `--host cursor\|codex\|claude` | Preflight installs correct plugin; no Claude token gateway on Codex/Cursor |
| M3 | Host-isolated artifacts (lock, batch PID, row logs, monitor status) | Parallel Claude Round 6 + Codex row 1 dry-run without collision |
| M4 | Monitor/watch host-aware child detection | No `kill_claude_children` when runtime=codex |
| M5 | `SB_RUNTIME_STATE_DIR` in matrix verify + outcome assess | Row 1 routing PASS reads Codex/Cursor state |
| M6 | Host MATRIX_ROWS or route translation | Row 3 prompt uses `$silver:feature` (Codex) or skill routing (Cursor) |
| M7 | One full row live PASS CI fixture (row 6 fast path) per host | Structural test in `test-enterprise-e2e-live-suite.sh` |
| M8 | Ledger templates `ROUND-CODEX-1-LEDGER.md`, `ROUND-CURSOR-1-LEDGER.md` | Reconcile + RCS read host ledger |
| M9 | Outcome clarify grep + RCS tri-host default | Strict-clean scoring neutral across hosts |
| M10 | `CODEX-TUI-PROTOCOL.md`, `CURSOR-TUI-PROTOCOL.md` | Linked from prompts + live runbook |

**Until M1–M6 land:** prompts must headline **"NOT READY — harness smoke + manual rows only."**

---

## Summary table: success criteria vs readiness

| Criterion | Codex | Cursor |
|-----------|-------|--------|
| 2× strict-clean | ❌ | ❌ |
| Phase A 8/8×2 verify | ⚠️ smoke | ⚠️ resolver-only default |
| Phase B 22/22 + 27 criteria | ❌ | ❌ |
| Phase C full | ⚠️ RCS tri-host | ⚠️ |
| Parent orchestrator ops | ✅ prompt | ✅ prompt |
| Autonomy / no pause | ✅ prompt | ✅ prompt |
| Tools opt-in | ⚠️ | ⚠️ |
| WBS outcomes | ❌ ops detail | ❌ |
| 76 baseline | ✅ | ✅ |
| Single driver | ❌ shared paths | ❌ |
| Host TUI E2E | ❌ unwired | ❌ unwired |

---

## Verdict (3-line) — pass 2 (final)

**READY WITH GAPS** — M1–M6 harness + host ledgers + protocols land on `enterprise-e2e/multi-host`; Codex/Cursor Phase B is honest; Claude Round 6 isolation preserved.

**Session launch:** allowed with host env blocks in prompts/TUI protocols. **Strict-clean 2×22:** still requires live matrix + ladder proof (M7 CI fixtures recommended).

**Scorecard:** Prompt + harness alignment ~8/10; remaining gaps P2 only (expect parity, outcome path prefix, RCS auto-trihost).

---

## 2-round gate audit (2026-06-30)

**User requirement:** Release needs **2 consecutive strict-clean rounds** per host — each round = ladder 8/8 × 2 clean verify + matrix 22/22 + all outcomes + 0 new issues + Phase C. Claude: Round 5 = first strict-clean; Round 6 = confirmation. Codex/Cursor: Codex-1/Cursor-1 then Codex-2/Cursor-2.

### Per-track explicitness

| Track | In prompt? | Round-2 ledger/gates | Transition procedure | Harness enforced? |
|-------|------------|----------------------|----------------------|-------------------|
| **Claude Round 6** | **YES** — [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) §A, [ROUND-6-GATES.md](./ROUND-6-GATES.md), [ROUND-6-LEDGER.md](./ROUND-6-LEDGER.md) | Round 5 + Round 6 ledgers/gates exist | §H evaluate release pair with Round 5 | **NO** — manual gate row only |
| **Codex** | **YES** (Mission + §Two-round release gate after patch) | **ADDED** `ROUND-CODEX-{1,2}-{LEDGER,GATES}.md` | 6-step table in prompt | **NO** |
| **Cursor** | **YES** (Mission + §Two-round release gate after patch) | **ADDED** `ROUND-CURSOR-{1,2}-{LEDGER,GATES}.md` | 6-step table in prompt | **NO** |

### Harness finding

| Script | 2-round enforcement |
|--------|---------------------|
| `run-enterprise-e2e-live-test.sh` | Prints **manual** checklist only (`[ ] 2 consecutive clean rounds before release tag`) — no ledger cross-check |
| `run-enterprise-e2e-validation-overlay.sh` | Single-round ledger scope |
| `enterprise-e2e-rcs.sh` | Single `--ledger` file; no consecutive-round logic |
| `test-enterprise-e2e-live-suite.sh` | Structural: runbook **mentions** "2 consecutive clean rounds" — does not validate pair |
| Gate scripts | **None** — operator + `ROUND-*-GATES.md` are authoritative |

**Recommendation (P2 harness):** add `scripts/lib/enterprise-e2e-consecutive-rounds-check.sh` accepting two gate file paths; fail release overlay if either round not strict-clean or pair broken.

### Gaps closed by this patch

- Codex/Cursor prompts: §Two-round release gate, pinned Round-2 paths, one-liner updated
- Ledgers: fixed inverted "Next action"; `Consecutive pair` metadata column
- Host gate files: `PENDING (1/2)` / `PASS (2/2)` on consecutive row
- Round-2 ledger templates with prior-round linkage

### Remaining gaps (not patched — out of scope / P2)

- No automated harness script for cross-round comparison
- [ENTERPRISE-E2E-LIVE-TEST.md](../../docs/ENTERPRISE-E2E-LIVE-TEST.md) is Claude-centric (no Codex/Cursor host tracks)
- [enterprise_e2e_iteration_30417faf.plan.md](file:///Users/shafqat/.cursor/plans/enterprise_e2e_iteration_30417faf.plan.md) references Claude-only Round 1/2 todos
- Tri-host release still requires **three** host pairs independently (Claude 5+6, Codex 1+2, Cursor 1+2) — no single RELEASE-READINESS rollup doc
