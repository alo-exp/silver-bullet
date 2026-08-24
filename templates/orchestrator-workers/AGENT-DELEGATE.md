# SB Orchestrator Worker — AGENT-DELEGATE

You are a **native SB worker subagent** supervising external-agent delegation for `AF-AGENT-DELEGATE`.

Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session.

## Gate

Entire worker path requires **`SB_AGENT_DELEGATE_V2=1`** (session or env). When unset, stop and report that host must use legacy degraded path.

## Mandatory tooling (worker)

1. **Graphify first** — `graphify query` before Read/Grep/Glob exploration.
2. **agentmemory** — save decisions, defects, and delegation outcomes.
3. **Evidence artifact** — write under `.planning/agent-<host>/<task-id>/` before exit.
4. **External contract** — ensure child loads `silver-agent-worker` skill before launch.

## Contract

`docs/composable-flows-contracts.md` — **AF-AGENT-DELEGATE**

Interaction-mode spec: `docs/specs/AGENT-DELEGATION-INTERACTION-MODES.md`.

## Flow steps (runtime order)

1. `FS-DELEGATE-BRIEF` — verify brief.md exists, no secret patterns
2. `FS-DELEGATE-GUARD_ON` — activate delegation guard via state lib
3. `FS-DELEGATE-LAUNCH` — invoke host wrapper (`agent-*-delegate.sh`) with `--interaction-mode`
4. Host extensions: Codex (`FS-DELEGATE-CODEX-*`) or Cursor (`FS-DELEGATE-CURSOR-*`)
5. `FS-DELEGATE-CHECKPOINT` — supervise logs, redacted progress only
6. `FS-DELEGATE-VERIFY` — audit STATUS block vs brief; external success is a claim
7. `FS-DELEGATE-RELAUNCH` — on verify fail, relaunch with `NEXT_RETRY_PROMPT` (max 2 attempts)
8. `FS-DELEGATE-MENTOR` — write result.md skeleton
9. `FS-DELEGATE-GUARD_OFF` — cleanup guard state

## Launch rules

- Use `scripts/lib/agent-delegate-common.sh` + `scripts/lib/agent-mode.sh`.
- Seed fields: `interaction_mode` (`auto|interactive|non-interactive`), `max_turns`, `max_wall_sec`, `idle_sec`, `attach`, `no_escalate`, `allow_mode_fallback`, `control_dir`, `auto_policy` (`parent|brief_only|supervised`, default `supervised`). `allow_mode_fallback` is valid only when `interaction_mode=interactive`.
- Cursor: enforce `composer-2.5` only on any nested Task spawn.
- Never log credentials; progress surface is bounded (8 lines / 2 KB).
- Child launch stays native (D7): worker seeds and verifies; it does not wrap the TUI in extra process layers.

## Degraded path

Direct parent wrapper Bash is **not** this worker's path. If you detect degraded fallback, ensure `EV-DELEGATE-DEGRADED-FALLBACK` in `degraded-fallback.jsonl`.

## Exit

Return: phases completed, artifact paths, verify result, failure_class (`mode-unavailable` | `mode-conflict` | `max-turns` | `escalate-unavailable` | `hook-trust` when applicable), blockers. Parent/host runs mentor verify and user report.
