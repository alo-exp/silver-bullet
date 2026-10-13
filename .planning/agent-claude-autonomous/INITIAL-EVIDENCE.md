# Agent-Claude Autonomous — Initial Evidence (2026-07-06)

## Preflight

| Check | Result |
|-------|--------|
| install_fp | `claude@609ee0a1812c+2717f916398e` |
| sb_git_sha | `609ee0a1812c` |
| Claude CLI | 2.1.195 |
| Auth | OK |
| Fixture | `/Users/shafqat/projects/enterprise-grade-test-app` |
| Structural tests | 16/16 PASS |

## Run attempts

### Run 1: `20260705T171228Z-AUTO-C01` (interactive TUI, background)

| Field | Value |
|-------|-------|
| Mode | expect TUI (default) |
| claude-run.log | 0 B |
| Status | **BLOCKED** — background subshell lost delegate; no PTY output |
| failure_class | `harness` / `0-token` |

### Run 2: `20260705T171435Z-AUTO-C01` (--use-print, background)

| Field | Value |
|-------|-------|
| claude-run.log | 1274 B (TUI banner captured despite --use-print) |
| Harness signal | `[harness] 0-token mode banner — wake TUI with Enter (E2E-081)` |
| Status | **BLOCKED** — requires interactive terminal for Enter-wake |
| failure_class | `0-token` |

### Smoke: print one-liner (foreground)

| Field | Value |
|-------|-------|
| Prompt | `Reply with exactly: AGENT_CLAUDE_SMOKE_OK` |
| Response | `AGENT_CLAUDE_SMOKE_OK` |
| Note | Log floor fail at 512 B default; pass at 200 B floor |

## Certification impact

**None.** Claude host remains `live_e2e_partial` 6/22 per [CERTIFICATION-STATUS.json](../enterprise-e2e/CERTIFICATION-STATUS.json). Evidence pointer added only in [host-certification-sources.json](../../docs/testing/host-certification-sources.json).

## Operator next step

Run AUTO-C01 in an **interactive terminal** (not Cursor background shell):

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export CLAUDE_WORK_DIR=/Users/shafqat/projects/enterprise-grade-test-app
bash scripts/agent-claude-autonomous-test.sh preflight
bash scripts/agent-claude-autonomous-test.sh start --row AUTO-C01
# second terminal:
bash scripts/agent-claude/monitor.sh --log .planning/agent-claude-autonomous/runs/<run-id>/claude-run.log
```

After completion:

```bash
bash scripts/agent-claude-autonomous-test.sh score --run <run-id>
```
