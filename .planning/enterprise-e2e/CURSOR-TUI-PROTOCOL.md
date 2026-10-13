# Cursor Agent TUI Supervised Protocol — Enterprise E2E Matrix

Operator protocol for executing 22 supervised Cursor agent workflow sessions against `enterprise-grade-test-app`. Evidence lands in [ROUND-CURSOR-1-LEDGER.md](./ROUND-CURSOR-1-LEDGER.md).

**Supervisor session:** Cursor Composer (parent orchestrator with `Task` tool, `composer-2.5` only).  
**Matrix child:** `cursor-agent` / `agent` CLI headless **or** in-session Composer when `SB_LIVE_CURSOR_IN_SESSION=1`.

**Working directory for SB fixes:** `/Users/shafqat/projects/silver-bullet/repo`  
**Working directory for matrix rows:** `/Users/shafqat/projects/enterprise-grade-test-app`

See also: [CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CURSOR-ENTERPRISE-E2E-EXECUTION-PROMPT.md)

---

## Prerequisites (each round)

1. SB repo harness tip; structural suite green.
2. `bash scripts/install-cursor.sh` from SB checkout; reload Cursor window after hook merge.
3. `CURSOR_API_KEY` for headless matrix (or `cursor-agent login`).
4. **Graphify** + **agentmemory** when opted in.

---

## Host-isolated harness env (mandatory)

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SILVER_BULLET_RUNTIME=cursor
export SB_E2E_LIVE_RUNTIME=cursor
export CURSOR_API_KEY="${CURSOR_API_KEY:?}"
export AGENT_CLI_CREDENTIAL_STORE=memory
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-CURSOR-1-LEDGER.md"
export SB_E2E_MATRIX_LOG="$SB_ROOT/.e2e-matrix-cursor-live.log"
export SB_E2E_MATRIX_BATCH_PID_FILE="$SB_ROOT/.e2e-matrix-cursor-batch.pid"
export SB_E2E_MATRIX_MONITOR_PID_FILE="$SB_ROOT/.e2e-matrix-cursor-monitor.pid"
export SB_E2E_MATRIX_MONITOR_STATUS_FILE="$SB_ROOT/.e2e-matrix-cursor-monitor-status.txt"
export SB_E2E_TUI_FINDINGS="$SB_ROOT/.e2e-tui-watch-cursor-findings.jsonl"
export SB_E2E_TUI_OFFSETS="$SB_ROOT/.e2e-tui-watch-cursor-offsets.json"
export SB_E2E_LIVE_TEST_LOCK_FILE="$SB_ROOT/.e2e-live-test-cursor.lock"
```

**Cross-host:** Do NOT touch Claude Round 6 `.e2e-live-test.lock` or `.e2e-row*-attempt.log` (no host suffix).

---

## Headless vs in-session

| Mode | When | Env |
|------|------|-----|
| Headless CLI | Matrix batch (default) | `CURSOR_API_KEY`, `agent -p` via `cursor/agent.sh` |
| In-session | IDE babysitting | `SB_LIVE_CURSOR_IN_SESSION=1` |

**Phase A strict-clean:** `SB_LIVE_REVIEW_FIX_LADDER_CURSOR_RESOLVER_ONLY=0` + live API turns (not resolver-only default).

**State root:** `${SB_RUNTIME_STATE_DIR:-$HOME/.cursor/.silver-bullet}`

**Clarify aliases for OUT-CLARIFY-01:** `silver-clarify`, `/silver:clarify`, `silver:clarify` in log or state.

---

## Quiet / timeout env

| Env | Default | Purpose |
|-----|---------|---------|
| `CURSOR_AGENT_TIMEOUT` | 1800 | Row hard timeout (adapter; matrix enforces ≥1800 for cursor — E2E-087/E2E-092) |
| `SB_E2E_WORKFLOW_QUIET_TIMEOUT` | 600 | Workflow rows quiet window |
| `SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL` | 60 | Rate-limit backoff |

Matrix CLI uses `--model composer-2.5` (never `composer-2.5-fast` for subagents).

---

## Session 0 — Bootstrap

Init via silver-init skill or `/silver:init` equivalent in test app CWD. Opt in Graphify + agentmemory.

---

## Sessions 1–22 — Workflow matrix

Routes: matrix runner maps `/silver:feature` → natural-language skill routing (`feature` slug prefix in prompt).

Per-row: graphify query → agent invoke → monitor `.e2e-row{N}-cursor-attempt.log` → outcome checklist → ledger + `failure_class`.

**Compaction:** allowed; **do not** `/clear`.

---

## Launch commands

```bash
# Dry-run row 1:
SB_E2E_MATRIX_DRY_RUN=1 SB_E2E_LIVE_RUNTIME=cursor bash scripts/run-enterprise-e2e-matrix.sh 1

# Live entrypoint:
SB_ENTERPRISE_E2E_LIVE=1 RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh --host cursor --resume
```
