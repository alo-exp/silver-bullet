# Agent-Codex Smoke Retry 2 — 2026-07-04

| Field | Value |
|-------|-------|
| **SB branch** | `feature/silver-agent-codex-skill` |
| **Test app branch** | `feature/agent-codex-smoke-20260704` |
| **Mode** | `--use-exec` + `SB_AGENT_CODEX_LIGHTWEIGHT=1` (default) |
| **Verdict** | **PASS** (product); harness tail timeout noted |

## Result

- **Commit:** `c542184715ab18576cc97746f74b44c35a5511fd` — `chore: agent-codex smoke retry2 comment`
- **File:** `README.md` first line `# agent-codex smoke retry2`
- **Log:** [codex-run.log](codex-run.log) — delegate exit 0; codex exec emitted `ERROR: timed out waiting for codex exec after 600s` after work completed (hook tail)

## Fixes validated

1. **Lightweight MCP strip** — ephemeral `CODEX_HOME` without `[mcp_servers.*]` (no agentmemory/context-mode boot stall)
2. **Orchestrator bypass** — `SB_ORCHESTRATOR_WORKER=1` on Codex child; direct edit+commit, no parent Task spawn
3. **Exec env propagation** — worker/delegate flags passed through `codex exec` subprocess

## failure_class

`none` (product). Harness: `exec-tail-timeout` — cosmetic; consider shorter post-commit quiet detection in a follow-up.
