# Dual-host agent delegation pilot rollup

**Date:** 2026-07-05  
**Gate:** Phase 4 `migration_map` flip requires both hosts **PASS** with `SB_AGENT_DELEGATE_V2=1` on AGENT-DELEGATE worker path  
**Plan:** Phase 3b — [agent-delegation-af plan](file:///Users/shafqat/.cursor/plans/agent-delegation-af_f2849554.plan.md)  
**Live rollups:** [AGENT-CURSOR-LIVE-VALIDATION.md](AGENT-CURSOR-LIVE-VALIDATION.md) · [AGENT-CODEX-LIVE-VALIDATION.md](AGENT-CODEX-LIVE-VALIDATION.md) · [AGENT-CLAUDE-LIVE-VALIDATION.md](AGENT-CLAUDE-LIVE-VALIDATION.md)

## Per-host results

| Host | Path | Status | Harness exit | Log (B) | Floor (512) | Product commit | Guard tier | Degraded fallback |
|------|------|--------|--------------|---------|-------------|----------------|------------|-------------------|
| **Cursor** | Worker + `SB_AGENT_DELEGATE_V2=1` | **PASS** | 0 | 52,453 | ✓ | `11bbf8f` | advise | absent |
| **Codex** | Worker + `SB_AGENT_DELEGATE_V2=1` | **PASS** | 0 | 27,066 | ✓ | `8437fb5` | block | absent |

### Cursor — PASS (V2 worker path, live 2026-07-05)

**AF live validation (2026-07-05):** [AGENT-CURSOR-LIVE-VALIDATION.md](AGENT-CURSOR-LIVE-VALIDATION.md) — branch `agent-cursor-af-live-20260705-live`, commit **`fb68b45`**, log **51,543 B**, exit **0**.

Prior direct-wrapper baseline (no V2): [silver-agent-cursor-pilot.md](silver-agent-cursor-pilot.md) — commit `54527d2`, 2026-07-04.

| Gate | Evidence |
|------|----------|
| V2 worker bootstrap | `sb_orchestrator_seed_delegation_directive` → `next_worker_template: AGENT-DELEGATE`, `atomic_flow_id: AF-AGENT-DELEGATE` |
| Delegate launch | `agent-cursor-delegate.sh` via worker path |
| Log floor | **52,453 B** >> `SB_AGENT_CURSOR_LOG_FLOOR=512` |
| Live session | Composer 2.5, `"apiKeySource":"login"`, session `88456429-…` |
| Product delta | **`11bbf8f55ca4df3f31b33a8569a52b85af35cdc6`** — `docs: agent-cursor V2 worker pilot marker`; README only (+2 lines) |
| Scope | `enterprise-grade-test-app-cursor` @ `round-agent-cursor-test` |
| Artifacts | [`.planning/agent-cursor/pilot-v2-20260705/`](agent-cursor/pilot-v2-20260705/) — `brief.md`, `cursor-run.log`, `result.md` |

**Command (representative):**

```bash
export SB_AGENT_DELEGATE_V2=1 SB_AGENT_CURSOR_LOG_FLOOR=512 CURSOR_AGENT_TIMEOUT=600
# seed directive + guard, then:
bash scripts/agent-cursor-delegate.sh \
  --work-dir /Users/shafqat/projects/enterprise-grade-test-app-cursor \
  --brief-file .planning/agent-cursor/pilot-v2-20260705/brief.md \
  --log .planning/agent-cursor/pilot-v2-20260705/cursor-run.log
```

### Codex — PASS (V2 worker path, re-run 2026-07-05)

**AF live validation (2026-07-05):** [AGENT-CODEX-LIVE-VALIDATION.md](AGENT-CODEX-LIVE-VALIDATION.md) — branch `agent-codex-af-live-20260705-live`, commit **`ec44459`**, log **76,436 B**, exit **0** (`--use-exec`, real `CODEX_HOME`).

Prior attempt: harness FAIL on exec log floor (231 B) despite product commit `05b60c2`.

| Gate | Evidence |
|------|----------|
| V2 worker bootstrap | `sb_orchestrator_seed_delegation_directive` codex → `AGENT-DELEGATE` |
| Delegate launch | `agent-codex-delegate.sh --use-exec` with `SB_AGENT_CODEX_SKIP_MCP=0` (real `CODEX_HOME`) |
| Harness exit | **0** |
| Log floor | **27,066 B** >> `SB_AGENT_CODEX_LOG_FLOOR=512` (exec stdout appended via `agent_delegate_append_invoke_output`) |
| Product delta | **`8437fb50a08140ee1b4eb6fa00292b3cb68a2f22`** — `docs: agent-codex V2 worker pilot re-run marker`; README only (+1 line) |
| Scope | `enterprise-grade-test-app-codex` @ `round-agent-codex-v2-pilot` |
| Fix applied | `scripts/lib/agent-delegate-common.sh` + `scripts/agent-codex-delegate.sh` — tee exec stdout into delegate log after header |
| Artifacts | [`.planning/agent-codex/pilot-v2-20260705/`](agent-codex/pilot-v2-20260705/) — `brief-rerun.md`, `codex-run-rerun.log`, `result.md` |

**Command (re-run PASS):**

```bash
export SB_AGENT_DELEGATE_V2=1 SB_AGENT_CODEX_LOG_FLOOR=512
export SB_AGENT_CODEX_SKIP_MCP=0 SB_AGENT_CODEX_LIGHTWEIGHT=0
export SB_AGENT_CODEX_DELEGATE=1 SB_ORCHESTRATOR_WORKER=1 SB_ORCHESTRATOR_PARENT=0
export CODEX_HOME="$HOME/.codex" CODEX_INTERACTIVE_TIMEOUT=900 CODEX_EXEC_TAIL_IDLE_TIMEOUT=30
bash scripts/agent-codex-delegate.sh --use-exec \
  --work-dir /Users/shafqat/projects/enterprise-grade-test-app-codex \
  --brief-file .planning/agent-codex/pilot-v2-20260705/brief-rerun.md \
  --log .planning/agent-codex/pilot-v2-20260705/codex-run-rerun.log
```

**Prior runs (historical):**

1. `codex-run.log` — exec, lightweight CODEX_HOME: exit 1, log 231 B, commit blocked.
2. `codex-run-retry.log` — interactive TUI, real CODEX_HOME: exit 0, log 19,615 B, no product commit.
3. `codex-run-exec.log` — exec, real CODEX_HOME: exit 1, log 231 B, product commit `05b60c2`, harness FAIL on floor.

## Structural gates (pre-pilot, unchanged)

| Test | Status |
|------|--------|
| `tests/scripts/test-agent-delegate-common.sh` | PASS |
| `tests/hooks/test-agent-delegation-guard.sh` | PASS |
| `tests/hooks/test-orchestrator-delegation-directive.sh` | PASS |
| `tests/scripts/test-agent-delegation-catalog-contract.sh` | PASS |

## Guard tier observed (live)

| Runtime | Tier | Source |
|---------|------|--------|
| Cursor parent | advise | `sb_agent_delegation_parent_host_tier` + live Cursor delegate |
| Codex parent | block | structural guard tests |

## Tri-host flip gate (Phase 3b)

| Host | V2 worker path | AF live rollup | Status |
|------|----------------|----------------|--------|
| Cursor | AGENT-DELEGATE | [AGENT-CURSOR-LIVE-VALIDATION.md](AGENT-CURSOR-LIVE-VALIDATION.md) | **PASS** |
| Codex | AGENT-DELEGATE | [AGENT-CODEX-LIVE-VALIDATION.md](AGENT-CODEX-LIVE-VALIDATION.md) | **PASS** |
| Claude | AGENT-DELEGATE | [AGENT-CLAUDE-LIVE-VALIDATION.md](AGENT-CLAUDE-LIVE-VALIDATION.md) | **PASS** |

## Phase 4 flip decision

**GATE SATISFIED** — All three hosts PASS with `SB_AGENT_DELEGATE_V2=1` on AGENT-DELEGATE worker path. **Do not flip `migration_map` in this change** — flip remains a separate user decision after structural tests stay green.

**Fix shipped (Codex exec log floor):**

1. `agent_delegate_append_invoke_output` in `scripts/lib/agent-delegate-common.sh`
2. `agent-codex-delegate.sh` appends exec stdout to delegate log when `--use-exec` (interactive path unchanged — still tees via `CLAUDE_INTERACTIVE_LOG_FILE`)

**Pilot env notes (Codex exec):**

- Use real `CODEX_HOME` (`SB_AGENT_CODEX_LIGHTWEIGHT=0`) when planning markers required
- `CODEX_INTERACTIVE_TIMEOUT=900` recommended when post-commit SB hooks active on `sb_initiated` test apps
- `SB_ORCHESTRATOR_WORKER=1` / `SB_ORCHESTRATOR_PARENT=0` reduces parent-orchestration hook noise during delegate runs

## Verdict

| Host | Phase 3b gate |
|------|---------------|
| Cursor | **PASS** — V2 worker path evidenced (supersedes 2026-07-04 direct-wrapper baseline for flip gate) |
| Codex | **PASS** — V2 worker path re-run 2026-07-05; exec log tee fix + product commit `8437fb5` |
