# Codex TUI Supervised Protocol — Enterprise E2E Matrix

Operator protocol for executing 22 supervised Codex CLI workflow sessions against `enterprise-grade-test-app`. Evidence lands in [ROUND-CODEX-1-LEDGER.md](./ROUND-CODEX-1-LEDGER.md).

**Supervisor session:** Cursor Composer (parent orchestrator with `Task` tool).  
**Matrix child:** Codex CLI TUI (`codex` in test app CWD).

**Working directory for SB fixes:** `/Users/shafqat/projects/silver-bullet/repo`  
**Working directory for Codex TUI:** `/Users/shafqat/projects/enterprise-grade-test-app`

See also: [CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md](./CODEX-ENTERPRISE-E2E-EXECUTION-PROMPT.md)

---

## Prerequisites (each round)

1. SB repo on `enterprise-e2e/multi-host` or cherry-picked harness tip; structural suite green.
2. `bash scripts/install-codex.sh --purge-legacy-skills` from SB checkout.
3. Test app cloned; pin baseline SHA in ledger header.
4. **Graphify:** `graphify update .` after SB edits.
5. **agentmemory:** server healthy; MCP connected for Codex when opted in.

---

## Host-isolated harness env (mandatory)

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SILVER_BULLET_RUNTIME=codex
export SB_E2E_LIVE_RUNTIME=codex
export SB_E2E_LEDGER_FILE="$SB_ROOT/.planning/enterprise-e2e/ROUND-CODEX-1-LEDGER.md"
export SB_E2E_MATRIX_LOG="$SB_ROOT/.e2e-matrix-codex-live.log"
export SB_E2E_MATRIX_BATCH_PID_FILE="$SB_ROOT/.e2e-matrix-codex-batch.pid"
export SB_E2E_MATRIX_MONITOR_PID_FILE="$SB_ROOT/.e2e-matrix-codex-monitor.pid"
export SB_E2E_MATRIX_MONITOR_STATUS_FILE="$SB_ROOT/.e2e-matrix-codex-monitor-status.txt"
export SB_E2E_TUI_FINDINGS="$SB_ROOT/.e2e-tui-watch-codex-findings.jsonl"
export SB_E2E_TUI_OFFSETS="$SB_ROOT/.e2e-tui-watch-codex-offsets.json"
export SB_E2E_LIVE_TEST_LOCK_FILE="$SB_ROOT/.e2e-live-test-codex.lock"
```

**Cross-host:** Do NOT remove `.e2e-live-test.lock` (Claude Round 6). Never `pkill` Claude children from Codex monitor.

---

## Route translation

Matrix runner translates `/silver:*` → `$silver:*` for Codex. Row 1 uses `$silver` routing-only prompt.  
**OUT-CLARIFY-01:** rows 1–3 require `$silver:clarify` or `silver-clarify` in state/log.

**State root:** `${SB_RUNTIME_STATE_DIR:-$HOME/.codex/.silver-bullet}`

---

## Quiet / timeout env

| Env | Default | Purpose |
|-----|---------|---------|
| `CODEX_INTERACTIVE_TIMEOUT` | 900 | Row hard timeout |
| `CODEX_INTERACTIVE_QUIET_TIMEOUT` | 300 (row 1) / 600 (rows 2–20) | Quiet-before-complete |
| `SB_E2E_MATRIX_QUOTA_RETRY_INTERVAL` | 60 | 429 / Token Plan backoff |

---

## Session 0 — Bootstrap (`$silver:init`)

```bash
cd /Users/shafqat/projects/enterprise-grade-test-app
codex   # CWD = test app
```

1. Run `$silver:init` — independent bootstrap.
2. Opt in Graphify + agentmemory.
3. `graphify update .` when enabled.
4. Do not commit SB init artifacts.

---

## Sessions 1–22 — Workflow matrix

Per-row checklist:

1. `graphify query "<slug> routes hooks skills orchestrator"` (SB repo).
2. Codex TUI CWD = test app.
3. Paste prompt card (matrix runner uses `$silver:*` routes).
4. Monitor `.e2e-row{N}-codex-attempt.log`, `${SB_RUNTIME_STATE_DIR}/state`, workflow Flow Log.
5. After row: `enterprise_e2e_outcome_write_workflow_checklist` → `.planning/enterprise-e2e/outcomes/row-{N}-outcomes.md`.
6. Log row in ledger; record `failure_class` on FAIL (`harness` | `product` | `environmental`).

**Compaction:** context compaction allowed; **do not** `/clear` (lose worker resume ID).

---

## Pass / fail (row 1)

**Pass:** evidence file OR routing skill in `${SB_RUNTIME_STATE_DIR}/state` OR routing markers in row log.  
**Fail:** missing all of the above.

---

## Launch commands

```bash
# Dry-run row 1:
SB_E2E_MATRIX_DRY_RUN=1 SB_E2E_LIVE_RUNTIME=codex bash scripts/run-enterprise-e2e-matrix.sh 1

# Live entrypoint:
SB_ENTERPRISE_E2E_LIVE=1 RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh --host codex --resume
```
