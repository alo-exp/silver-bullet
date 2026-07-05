# Agent-Claude Autonomous Test — Runbook

## Prerequisites

| Requirement | Check |
|-------------|-------|
| SB checkout (dirty OK) | `SB_ROOT` points at silver-bullet repo |
| Claude CLI + OAuth | `claude auth status` not unauthenticated |
| expect harness | `scripts/claude-interactive-invoke.expect` executable |
| Test app fixture | `enterprise-grade-test-app` clone exists |
| Recommended tools | graphify, agentmemory opted in per `.silver-bullet.json` |

## Phase 0 — Orientation

```bash
cd /Users/shafqat/projects/silver-bullet/repo
graphify query "silver agent-claude autonomous test mechanism command skill"
```

## Phase 1 — Preflight

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
bash scripts/agent-claude-autonomous-test.sh preflight
```

Preflight verifies:

- `install_fp` for `claude@<sha>+<surface>`
- `scripts/agent-claude/preflight.sh`
- Matrix env cleared (no `SB_E2E_ENTERPRISE_MATRIX` bleed)
- Structural harness tests (`test-agent-claude-autonomous-test.sh` subset)
- Recommended-tools gates (advisory if stale)

## Phase 2 — Start row (AUTO-C01 default)

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export CLAUDE_WORK_DIR=/Users/shafqat/projects/enterprise-grade-test-app

# Interactive TUI (preferred)
bash scripts/agent-claude-autonomous-test.sh start --row AUTO-C01

# Print fallback (automation / no PTY)
bash scripts/agent-claude-autonomous-test.sh start --row AUTO-C01 --use-print
```

Harness actions:

1. Creates `runs/<run-id>/` with `ledger.json`, `brief.md`, empty `claude-run.log` stub
2. Records `install_fp`, `sb_git_sha`, timestamp
3. Launches `scripts/agent-claude/invoke.sh` with row brief

### Parent monitor (second terminal)

```bash
bash scripts/agent-claude/monitor.sh \
  --log .planning/agent-claude-autonomous/runs/<run-id>/claude-run.log
```

## Phase 3 — Score outcomes

After delegation exits:

```bash
bash scripts/agent-claude-autonomous-test.sh score --run <run-id>
```

Reuses `scripts/lib/enterprise-e2e-outcome-assessment.sh` for blocking gates.

## Phase 4 — Capture

1. Fill `runs/<run-id>/result.md` from [EVIDENCE-TEMPLATE.md](EVIDENCE-TEMPLATE.md)
2. agentmemory: brief, log path, verdict, install_fp
3. `graphify update .` in SB repo and test app if modified

## Invocation paths (reference)

| Path | Entry |
|------|-------|
| Cursor skill picker | `/silver:agent-claude` → `skills/silver-agent-claude/SKILL.md` |
| Claude Code picker | `/silver:agent-claude` → `agents/claude/silver:agent-claude/SKILL.md` |
| Codex | `silver-bullet invoke-skill silver-agent-claude` |
| Harness (this track) | `scripts/agent-claude-autonomous-test.sh start` |

**No plugin command stub** — skill is `user-invocable: true` but not in `plugins/silver-bullet/commands/` (~36 marketplace stubs only).

## Contrast with legacy enterprise E2E

| Dimension | agent-claude (this track) | Round 9 matrix |
|-----------|---------------------------|----------------|
| Scope | 3-row fresh matrix | 22-row catalog |
| Harness | `agent-claude/invoke.sh` | `enterprise-e2e/matrix.sh` |
| Env | Matrix vars **cleared** | `SB_E2E_*` ledger/locks |
| Operator | Minimal supervision | Historically babysat TUI |
| Certification | Evidence pointer only | `ROUND-9-LEDGER.md` |

## Blockers → operator action

| Blocker | Action |
|---------|--------|
| Auth | `claude auth login` |
| Quota 429 | Wait; harness retries automatically |
| Harness ERROR | Fix SB scripts; file issue |
| Stuck 0-token | Enter-wake; check auth banner |
| Product fail | New brief with gap list |

## Exact operator command (live run)

```bash
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export CLAUDE_WORK_DIR=/Users/shafqat/projects/enterprise-grade-test-app
bash scripts/agent-claude-autonomous-test.sh preflight && \
bash scripts/agent-claude-autonomous-test.sh start --row AUTO-C01
```
