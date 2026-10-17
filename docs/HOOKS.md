# Hook Reference

> Generated from `hooks/hooks.json` and `docs/hooks-purpose.json` by `scripts/generate-hook-reference.py`.
> Do not edit by hand: change those files, then run `python3 scripts/generate-hook-reference.py`.
> `tests/docs/test-hook-reference.sh` fails when this file is stale.

`hooks/hooks.json` registers **96 hook commands** backed by **64 scripts** across 7 events. No registrations are async: the host waits for each hook up to its timeout (in seconds). The `#` column is the position in `hooks.json`; hosts may run the hooks that match one event in parallel, so do not rely on hook order.

## How hooks are wired

- **Claude Code** reads `hooks/hooks.json` from the plugin root; commands use `${CLAUDE_PLUGIN_ROOT}`.
- **Codex** loads the same manifest from the plugin package. `scripts/install-codex.sh` rewrites the paths and routes each command through `hooks/codex-hook-adapter.sh`.
- **Cursor** uses `hooks/cursor-hooks.json`, generated from `hooks/hooks.json` by `scripts/generate-cursor-hooks.py`; each command runs through `hooks/cursor-hook-bridge.sh`.
- Matchers name tools from every host: `Bash` (Claude) and `exec_command` (Codex) are shell calls; `apply_patch` is the Codex edit tool; `CallMcpTool`/`MCP` are MCP calls; `Task|Subagent|Agent` are subagent spawns.
- Enforcement hooks first check that the project is activated (`.silver-bullet.json` and `silver-bullet.md` at the project root, see `hooks/lib/sb-project-gate.sh`); outside an SB project they exit 0, apart from the missing-`jq` case below.
- Unexpected errors fail open: almost every hook installs an `ERR` trap that exits 0 (some print a notice or a no-op payload first). Exceptions: `phase-archive.sh` denies the `phases clear` it guards when archiving fails, and `rfl-policy-c-gate.sh` has no `ERR` trap, so an unexpected error surfaces as a non-blocking hook error.
- A missing `jq` does not fail open everywhere. `session-start` warns that enforcement is disabled and most hooks exit 0, but `completion-audit.sh`, `dev-cycle-check.sh`, `forbidden-skill-check.sh`, `planning-file-guard.sh`, `uat-gate.sh` and `workflow-chain-guard.sh` block in an initiated project (`hooks/lib/jq-gate.sh`), and `completion-audit.sh` also blocks commit, push, PR, release and deploy commands outside one.

## Registrations by event

### SessionStart

Session startup, `/clear` and compaction (`startup|clear|compact`).

| # | Matcher | Script | Timeout |
|---|---------|--------|---------|
| 1 | `startup\|clear\|compact` | `session-start` | 15 |
| 2 | `startup\|clear\|compact` | `spec-session-record.sh` | 10 |
| 3 | `startup\|clear\|compact` | `stack-compression-lifecycle.sh` | 10 |
| 4 | `startup\|clear\|compact` | `rfl-quota-retry-due.sh` | 10 |

### PreToolUse

Before a tool runs; a hook can deny the call.

| # | Matcher | Script | Timeout |
|---|---------|--------|---------|
| 1 | `.*` | `debug-dump.sh` | 5 |
| 2 | `Bash\|Skill\|exec_command` | `phase-archive.sh` | 10 |
| 3 | `Bash\|Skill\|exec_command` | `completion-audit.sh` | 15 |
| 4 | `Edit\|Write\|MultiEdit\|apply_patch` | `planning-file-guard.sh` | 10 |
| 5 | `Edit\|Write\|MultiEdit\|apply_patch` | `instruction-file-guard.sh` | 10 |
| 6 | `Edit\|Write\|MultiEdit\|apply_patch` | `workflow-chain-guard.sh` | 10 |
| 7 | `Edit\|Write\|MultiEdit\|apply_patch` | `orchestrator-directive-guard.sh` | 10 |
| 8 | `Edit\|Write\|MultiEdit\|apply_patch` | `agent-delegation-guard.sh` | 10 |
| 9 | `Edit\|Write\|MultiEdit\|apply_patch` | `phase-lock-claim.sh` | 10 |
| 10 | `Task\|Subagent\|Agent` | `orchestrator-directive-guard.sh` | 10 |
| 11 | `Task\|Subagent\|Agent` | `subagent-stop-enforcement.sh` | 10 |
| 12 | `Task\|Subagent\|Agent` | `review-fix-ladder-guard.sh` | 10 |
| 13 | `Task\|Subagent\|Agent` | `rfl-policy-c-gate.sh` | 10 |
| 14 | `Skill` | `review-fix-ladder-guard.sh` | 10 |
| 15 | `Skill` | `rfl-policy-c-gate.sh` | 10 |
| 16 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `subagent-stop-enforcement.sh` | 10 |
| 17 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `site-preview-preflight.sh` | 10 |
| 18 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `site-chrome-guard.sh` | 10 |
| 19 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `compression-marker-guard.sh` | 10 |
| 20 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `orchestrator-directive-guard.sh` | 10 |
| 21 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `trivial-file-guard.sh` | 10 |
| 22 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `dev-cycle-check.sh` | 15 |
| 23 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `graphify-gate.sh` | 10 |
| 24 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `agentmemory-gate.sh` | 10 |
| 25 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `alumnium-gate.sh` | 10 |
| 26 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `leanctx-gate.sh` | 10 |
| 27 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `stack-compression-coordinator.sh` | 10 |
| 28 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `rtk-gate.sh` | 10 |
| 29 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `context-mode-gate.sh` | 10 |
| 30 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `token-compression-tools-gate.sh` | 10 |
| 31 | `Read\|Grep` | `stack-compression-coordinator.sh` | 10 |
| 32 | `Read\|Grep` | `context-mode-read-deny.sh` | 10 |
| 33 | `WebFetch` | `stack-compression-coordinator.sh` | 10 |
| 34 | `CallMcpTool\|MCP` | `stack-compression-coordinator.sh` | 10 |
| 35 | `Skill` | `forbidden-skill-check.sh` | 10 |
| 36 | `Skill` | `dependency-skill-check.sh` | 10 |
| 37 | `Skill` | `uat-gate.sh` | 10 |
| 38 | `Bash\|exec_command` | `site-regression-gate.sh` | 120 |
| 39 | `Bash\|exec_command` | `live-publish-evidence-gate.sh` | 15 |
| 40 | `Bash\|exec_command` | `industry-tooling-hint.sh` | 5 |
| 41 | `Bash\|exec_command` | `roadmap-freshness.sh` | 10 |
| 42 | `Bash\|exec_command` | `ci-status-check.sh` | 30 |
| 43 | `Bash\|exec_command` | `spec-floor-check.sh` | 10 |
| 44 | `Bash\|exec_command` | `rfl-policy-c-gate.sh` | 10 |

### PostToolUse

After a tool runs; a hook can report, record state, or ask the agent to stop.

| # | Matcher | Script | Timeout |
|---|---------|--------|---------|
| 1 | `Write\|Edit\|MultiEdit\|apply_patch` | `record-site-session.sh` | 10 |
| 2 | `Write\|Edit\|MultiEdit\|apply_patch` | `trivial-file-clear.sh` | 5 |
| 3 | `Task\|Subagent\|Agent` | `subagent-stop-enforcement.sh` | 10 |
| 4 | `Task\|Subagent\|Agent` | `review-fix-ladder-guard.sh` | 10 |
| 5 | `Skill` | `semantic-compress.sh` | 30 |
| 6 | `Skill\|Bash\|exec_command` | `record-skill.sh` | 10 |
| 7 | `Skill\|Bash\|exec_command` | `flow-advance.sh` | 15 |
| 8 | `Skill\|Bash\|exec_command` | `review-fix-ladder-guard.sh` | 10 |
| 9 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `dev-cycle-check.sh` | 15 |
| 10 | `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | `phase-lock-heartbeat.sh` | 10 |
| 11 | `.*` | `compliance-status.sh` | 15 |
| 12 | `.*` | `timeout-check.sh` | 10 |
| 13 | `Bash\|exec_command` | `completion-audit.sh` | 15 |
| 14 | `Bash\|exec_command` | `pr-traceability.sh` | 10 |
| 15 | `Bash\|exec_command` | `session-log-init.sh` | 10 |
| 16 | `Bash\|exec_command` | `ci-status-check.sh` | 30 |
| 17 | `Bash\|exec_command` | `record-graphify-query.sh` | 10 |
| 18 | `Bash\|exec_command` | `record-agentmemory-usage.sh` | 10 |
| 19 | `Bash\|exec_command` | `record-token-compression-usage.sh` | 10 |
| 20 | `Bash\|exec_command` | `record-leanctx-usage.sh` | 10 |
| 21 | `Bash\|exec_command` | `record-site-visual-evidence.sh` | 10 |
| 22 | `Bash\|exec_command` | `record-recommended-mcp.sh` | 10 |
| 23 | `CallMcpTool\|MCP` | `record-leanctx-usage.sh` | 10 |
| 24 | `CallMcpTool\|MCP` | `record-recommended-mcp.sh` | 10 |
| 25 | `CallMcpTool\|MCP` | `record-agentmemory-usage.sh` | 10 |

### SubagentStart

When a subagent starts (Cursor).

| # | Matcher | Script | Timeout |
|---|---------|--------|---------|
| 1 | `.*` | `subagent-start.sh` | 10 |

### Stop

When the agent tries to end its turn; a hook can block the stop.

| # | Matcher | Script | Timeout |
|---|---------|--------|---------|
| 1 | `.*` | `rfl-policy-c-gate.sh` | 10 |
| 2 | `.*` | `stop-check.sh` | 15 |
| 3 | `.*` | `outcomes-check.sh` | 10 |
| 4 | `.*` | `instruction-ledger-gate.sh` | 10 |
| 5 | `.*` | `site-regression-gate.sh` | 120 |
| 6 | `.*` | `live-publish-evidence-gate.sh` | 15 |
| 7 | `.*` | `v-loop-rollup-gate.sh` | 15 |
| 8 | `.*` | `site-visual-evidence-gate.sh` | 15 |
| 9 | `.*` | `subagent-stop-enforcement.sh` | 10 |
| 10 | `.*` | `phase-lock-release.sh` | 10 |

### SubagentStop

When a subagent finishes.

| # | Matcher | Script | Timeout |
|---|---------|--------|---------|
| 1 | `.*` | `stop-check.sh` | 15 |
| 2 | `.*` | `outcomes-check.sh` | 10 |
| 3 | `.*` | `instruction-ledger-gate.sh` | 10 |
| 4 | `.*` | `site-regression-gate.sh` | 120 |
| 5 | `.*` | `phase-lock-release.sh` | 10 |

### UserPromptSubmit

Before each user prompt is processed; hooks add context or record the requested route.

| # | Matcher | Script | Timeout |
|---|---------|--------|---------|
| 1 | `.*` | `record-requested-skill.sh` | 10 |
| 2 | `.*` | `prompt-reminder.sh` | 10 |
| 3 | `.*` | `outcomes-check.sh` | 10 |
| 4 | `.*` | `instruction-ledger-gate.sh` | 10 |
| 5 | `.*` | `record-site-session.sh` | 10 |
| 6 | `.*` | `subagent-stop-enforcement.sh` | 10 |
| 7 | `.*` | `rfl-quota-retry-due.sh` | 10 |

## Hook scripts

| Script | Registered on | Purpose |
|--------|---------------|---------|
| `agent-delegation-guard.sh` | PreToolUse `Edit\|Write\|MultiEdit\|apply_patch` | While an `/sb:agent-*` delegation is active, blocks parent-session edits on Claude and Codex and advises on Cursor. |
| `agentmemory-gate.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Opt-in (`recommended_tools.agentmemory`): requires a recent agentmemory capture/retrieval before substantive work. |
| `alumnium-gate.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Opt-in (`recommended_tools.alumnium`): checks that the Alumnium MCP server is wired before browser/visual work. |
| `ci-status-check.sh` | PreToolUse `Bash\|exec_command`; PostToolUse `Bash\|exec_command` | Checks the latest GitHub Actions run for the branch. Pre: blocks `git push`, `gh pr create/merge` and `gh release create` while CI failed or was cancelled. Post: warns after `git commit`. CI-fix commits and the `ci-red-override` flag bypass it. |
| `completion-audit.sh` | PreToolUse `Bash\|Skill\|exec_command`; PostToolUse `Bash\|exec_command` | Two-tier delivery gate. Commits, pushes and commit plumbing need `skills.required_planning`; `gh pr create/merge`, deploy commands and `gh release create` need `skills.required_deploy` plus the release gates (live matrices, quality-gate markers, RC matrix, green CI on the release commit). |
| `compliance-status.sh` | PostToolUse `.*` | Prints workflow progress (flow N/M, or recorded-skill count) after every tool call. Informational only. |
| `compression-marker-guard.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Blocks writes whose content contains LeanCTX compression markers (pasted `ctx_read` output). |
| `context-mode-gate.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Opt-in (`recommended_tools.context_mode`): checks Context Mode install and MCP/hook wiring. |
| `context-mode-read-deny.sh` | PreToolUse `Read\|Grep` | Opt-in (`recommended_tools.context_mode`): denies Read/Grep on files larger than `read_deny_bytes`. |
| `debug-dump.sh` | PreToolUse `.*` | Debug only: when the `debug-dump` flag file exists in the runtime state dir, appends each PreToolUse payload to `hook-dump.jsonl` there. Never blocks. |
| `dependency-skill-check.sh` | PreToolUse `Skill` | Compatibility gate for dependency-skill invocations. Does not block SB-absorbed namespaces; forbidden execution modes are handled by `forbidden-skill-check.sh`. |
| `dev-cycle-check.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command`; PostToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Planning-floor gate: blocks source edits and shell writes until workflow admission or the `required_planning` skills are recorded. Also blocks edits under the host plugin cache and direct writes to SB state files. |
| `flow-advance.sh` | PostToolUse `Skill\|Bash\|exec_command` | Advances the autonomous orchestrator flow queue after a skill or tracked command completes. |
| `forbidden-skill-check.sh` | PreToolUse `Skill` | Blocks forbidden skills: the built-in list (`executing-plans`, `subagent-driven-development`) plus `skills.forbidden`. |
| `graphify-gate.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Opt-in (`recommended_tools.graphify`): requires a recent Graphify query before substantive work. |
| `industry-tooling-hint.sh` | PreToolUse `Bash\|exec_command` | Optional reminders about industry tooling for shell commands; active only when `hooks.industry_tooling.enabled` is true. |
| `instruction-file-guard.sh` | PreToolUse `Edit\|Write\|MultiEdit\|apply_patch` | Blocks creating a brand-new root `CLAUDE.md` or `AGENTS.md` during initialization; existing files may be reconciled in place. |
| `instruction-ledger-gate.sh` | Stop `.*`; SubagentStop `.*`; UserPromptSubmit `.*` | Maintains the nested per-session instruction ledger; at Stop, blocks while ledger items remain open. |
| `leanctx-gate.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Opt-in (`recommended_tools.leanctx`): checks LeanCTX install, wiring and usage freshness. |
| `live-publish-evidence-gate.sh` | PreToolUse `Bash\|exec_command`; Stop `.*` | Requires fetched live-page evidence before a site publish is claimed LIVE (Stop) and before `git push` to main for site work. |
| `orchestrator-directive-guard.sh` | PreToolUse `Edit\|Write\|MultiEdit\|apply_patch`; PreToolUse `Task\|Subagent\|Agent`; PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Orchestrator parent mode: blocks edits, shell commands and Task spawns until the skill named by the pending directive has been invoked. |
| `outcomes-check.sh` | Stop `.*`; SubagentStop `.*`; UserPromptSubmit `.*` | Tracks the per-prompt outcome checklist; at Stop, blocks while outcomes are incomplete. |
| `phase-archive.sh` | PreToolUse `Bash\|Skill\|exec_command` | Archives `.planning/phases/` directories before a `phases clear` command runs. Fails closed: if archiving fails, the clear is denied. |
| `phase-lock-claim.sh` | PreToolUse `Edit\|Write\|MultiEdit\|apply_patch` | Claims the `.planning/phases/<NNN>/` lock (via `.planning/scripts/phase-lock.sh`) before a session edits a phase's files. |
| `phase-lock-heartbeat.sh` | PostToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Refreshes heartbeats for the phase locks this session holds (throttled to once per 5 minutes per phase). |
| `phase-lock-release.sh` | Stop `.*`; SubagentStop `.*` | Releases this session's phase locks at Stop/SubagentStop. Never blocks. |
| `planning-file-guard.sh` | PreToolUse `Edit\|Write\|MultiEdit\|apply_patch` | Blocks direct edits to SB-managed planning artifacts (`.planning/ROADMAP.md`, `STATE.md`, phase `PLAN.md`/`SUMMARY.md`, ...); they change only through the owning SB skill. |
| `pr-traceability.sh` | PostToolUse `Bash\|exec_command` | After `gh pr create`, appends the spec traceability block to the PR body and records the PR URL in `SPEC.md`. |
| `prompt-reminder.sh` | UserPromptSubmit `.*` | Injects a compact compliance reminder (missing skills, active workflow position, opted-in tool notes) before each prompt. |
| `record-agentmemory-usage.sh` | PostToolUse `Bash\|exec_command`; PostToolUse `CallMcpTool\|MCP` | Records successful agentmemory retrievals (CLI or MCP) for the opt-in agentmemory gate. |
| `record-graphify-query.sh` | PostToolUse `Bash\|exec_command` | Records successful Graphify queries for the opt-in Graphify gate. |
| `record-leanctx-usage.sh` | PostToolUse `Bash\|exec_command`; PostToolUse `CallMcpTool\|MCP` | Records LeanCTX CLI/MCP usage for the opt-in LeanCTX gate. |
| `record-recommended-mcp.sh` | PostToolUse `Bash\|exec_command`; PostToolUse `CallMcpTool\|MCP` | Records agentmemory/Graphify MCP tool calls for the opt-in gates. |
| `record-requested-skill.sh` | UserPromptSubmit `.*` | Records the SB route requested in the user prompt (for example `/sb:feature`) in the state file. |
| `record-site-session.sh` | PostToolUse `Write\|Edit\|MultiEdit\|apply_patch`; UserPromptSubmit `.*` | Records `site/**` edits and site-intent prompts so the site session gates know a site session is active. |
| `record-site-visual-evidence.sh` | PostToolUse `Bash\|exec_command` | Records browser screenshot paths as site visual evidence. |
| `record-skill.sh` | PostToolUse `Skill\|Bash\|exec_command` | Records completed skill invocations (host Skill tool, or `silver-bullet invoke-skill` receipts on Codex) in the state file. |
| `record-token-compression-usage.sh` | PostToolUse `Bash\|exec_command` | Records token-compression CLI usage (RTK) for the opt-in usage-freshness gate. |
| `review-fix-ladder-guard.sh` | PreToolUse `Task\|Subagent\|Agent`; PreToolUse `Skill`; PostToolUse `Task\|Subagent\|Agent`; PostToolUse `Skill\|Bash\|exec_command` | Enforces the review-fix-ladder state machine while a ladder session is active. |
| `rfl-policy-c-gate.sh` | PreToolUse `Task\|Subagent\|Agent`; PreToolUse `Skill`; PreToolUse `Bash\|exec_command`; Stop `.*` | While a review-fix-ladder run is active (`.planning/rfl-*/LADDER-STATUS.json`), denies advancing when Policy C or sibling artifacts are missing. |
| `rfl-quota-retry-due.sh` | SessionStart `startup\|clear\|compact`; UserPromptSubmit `.*` | Activates review-fix-ladder quota-retry jobs whose retry time has arrived. No-op when none are scheduled. |
| `roadmap-freshness.sh` | PreToolUse `Bash\|exec_command` | Blocks `git commit` when a phase `SUMMARY.md` is staged but its `ROADMAP.md` checkbox is not ticked. |
| `rtk-gate.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Opt-in (`recommended_tools.rtk`): checks RTK install, version and host hook wiring (it does not rewrite commands itself). |
| `semantic-compress.sh` | PostToolUse `Skill` | After phase skills, assembles a ranked context summary for the current phase goal (`semantic_compression` config). |
| `session-log-init.sh` | PostToolUse `Bash\|exec_command` | When the session mode is written, creates the `docs/sessions/` log skeleton; in autonomous mode starts the timeout sentinel. |
| `session-start` | SessionStart `startup\|clear\|compact` | Injects the core rules, resets branch- and worktree-scoped state, clears the trivial marker and stale gate files, and probes prerequisites (warns when `jq` is missing). |
| `site-chrome-guard.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Blocks inline `<nav>`/`<footer>` in site HTML (canonical fragments live in `site/_chrome/`) and unmarked font edits in `site/tokens.css`. |
| `site-preview-preflight.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Before `site/**` edits, checks that the local site preview server is healthy. |
| `site-regression-gate.sh` | PreToolUse `Bash\|exec_command`; Stop `.*`; SubagentStop `.*` | Runs the site regression tests at Stop and before `git push` when `site/**` was touched in the session. |
| `site-visual-evidence-gate.sh` | Stop `.*` | At Stop, requires 1280px visual evidence for active site sessions. |
| `spec-floor-check.sh` | PreToolUse `Bash\|exec_command` | Spec floor: blocks `sb:plan` without a minimum viable `SPEC.md`; advisory for `sb:fast`. |
| `spec-session-record.sh` | SessionStart `startup\|clear\|compact` | Captures spec version and Jira ID from `.planning/SPEC.md` for `pr-traceability.sh`. |
| `stack-compression-coordinator.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command`; PreToolUse `Read\|Grep`; PreToolUse `WebFetch`; PreToolUse `CallMcpTool\|MCP` | Five-tool stack coordinator: routes Read/Grep/shell/WebFetch/MCP surfaces to their owning tool and blocks double compression. |
| `stack-compression-lifecycle.sh` | SessionStart `startup\|clear\|compact` | On compaction, records the LeanCTX lifecycle phase after the agentmemory snapshot. |
| `stop-check.sh` | Stop `.*`; SubagentStop `.*` | Stop/SubagentStop gate: blocks a task-complete declaration while `required_planning` skills are missing, and enforces doc-scheme finalization when `docs/doc-scheme.md` exists. |
| `subagent-start.sh` | SubagentStart `.*` | Injects the worker banner and tool requirements into subagent sessions. |
| `subagent-stop-enforcement.sh` | PreToolUse `Task\|Subagent\|Agent`; PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command`; PostToolUse `Task\|Subagent\|Agent`; Stop `.*`; UserPromptSubmit `.*` | Tracks Task worker spawns and returns; at Stop, blocks a parent session whose workers ran but `sb:completion-audit` is not recorded. |
| `timeout-check.sh` | PostToolUse `.*` | Autonomous mode only: warns on wall-clock timeout and on 30/60/100 tool calls without a recorded skill. |
| `token-compression-tools-gate.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Opt-in: requires recent RTK usage before substantive commits. |
| `trivial-file-clear.sh` | PostToolUse `Write\|Edit\|MultiEdit\|apply_patch` | Deletes the legacy trivial-session marker after any file write. |
| `trivial-file-guard.sh` | PreToolUse `Edit\|Write\|MultiEdit\|Bash\|apply_patch\|exec_command` | Blocks agents from creating the legacy trivial marker; small changes go through `/sb:fast`. |
| `uat-gate.sh` | PreToolUse `Skill` | Blocks `sb:release` and milestone completion when `UAT.md` is missing, failing or stale against the spec version. |
| `v-loop-rollup-gate.sh` | Stop `.*` | At Stop, blocks when active site-session V-loops lack evidence. |
| `workflow-chain-guard.sh` | PreToolUse `Edit\|Write\|MultiEdit\|apply_patch` | Inside a composed workflow (`.planning/workflows/<id>.md`), blocks implementation edits until the pre-execution chain is recorded. |

## Other files in hooks/

These files are not registered in `hooks/hooks.json`.

| File | Role |
|------|------|
| `agent-delegation-progress-surface.sh` | Library, not a hook: sourced by `agent-delegation-guard.sh` to render bounded, redacted delegation progress (8 lines / 2 KB). |
| `codex-hook-adapter.sh` | Codex adapter: `scripts/install-codex.sh` rewrites installed hook commands to run through it (`codex-hook-adapter.sh <event> <hook>`); it buffers stdin/stdout and applies a subprocess timeout (`SB_CODEX_HOOK_SUBPROC_TIMEOUT`). |
| `core-rules.md` | Core enforcement rules that `session-start` injects into context. |
| `core-rules.sha256` | Integrity pin for `core-rules.md`, checked by `hooks/lib/core-rules-integrity.sh` before injection. |
| `cursor-hook-bridge.sh` | Cursor bridge: `cursor-hook-bridge.sh <cursorEvent> <hook>` translates a Cursor hook payload into the SB hook protocol, runs the hook with a subprocess timeout and maps the result back. |
| `cursor-hooks.json` | Cursor hook manifest, generated from `hooks.json` by `scripts/generate-cursor-hooks.py` (Cursor event names, `${CURSOR_PLUGIN_ROOT}` paths, every hook wrapped by `cursor-hook-bridge.sh`). Do not edit by hand. |
| `generate-cursor-hooks.py` | Compatibility shim that runs `scripts/generate-cursor-hooks.py`. |
| `hooks.json` | The registration manifest itself (Claude Code plugin format; Codex reads the same file from the plugin package). |
| `kay-project-hook-bridge.sh` | Project-level hook bridge for the Kay (Codex-compatible) runtime; the live-test harness registers it in `~/.kay/config.toml` (`tests/live/lib/kay-codex-isolation.sh`). |
| `run-hook.cmd` | Windows/Unix polyglot wrapper: `run-hook.cmd <script> [args]` finds Git for Windows bash (or bash on PATH) and runs the hook. |

## Shared libraries (hooks/lib/)

Hooks source these helpers; none of them is registered as a hook. Each file's header comment describes it.

- **Runtime paths and hook plumbing:** `runtime-paths.sh`, `hook-bootstrap.sh`, `hook-output.sh`, `hook-subproc-timeout.sh`, `hook-audit.sh`, `jq-gate.sh`, `tool-input.sh`, `tool-input/`, `path-canonical.sh`, `stop-coalesce.sh`, `ups-coalesce.sh`, `rtk-compat.sh`, `cert-bypass.sh`
- **Project activation, state and safety:** `sb-project-gate.sh`, `project-active.sh`, `branch-scope.sh`, `trivial-bypass.sh`, `nofollow-guard.sh`, `plugin-cache-guard.sh`, `core-rules-integrity.sh`, `capability-tier.sh`, `enforcement-tier-gate.sh`, `prerequisite-probe.sh`, `check-sb-update.sh`, `session-ledger.sh`, `phase-path.sh`
- **Required skills and workflow tracking:** `required-skills.sh`, `skill-discovery.sh`, `workflow-utils.sh`, `quality-gates-mode.sh`, `prompt-classifier.sh`, `outcomes-gate.sh`, `instruction-ledger.sh`
- **Delivery gates:** `completion-audit/`, `artifact-substance-gate.sh`, `doc-scheme-gate.sh`, `evidence-schema-gate.sh`, `enterprise-policy.sh`, `github-run-list.sh`, `e2e-matrix-routing.sh`
- **Orchestrator, delegation and review ladder:** `orchestrator-directive.sh`, `orchestrator-event-log.sh`, `orchestrator-parent.sh`, `orchestrator-scheduler.sh`, `orchestrator-skill-atom.sh`, `orchestrator-state.sh`, `agent-delegation-state.sh`, `review-fix-ladder-state.sh`, `rfl-policy-c-assert.sh`
- **Opt-in recommended tools (five-tool stack):** `recommended-tools.sh`, `recommended-tools-registry.sh`, `graphify-gate.sh`, `agentmemory-gate.sh`, `alumnium-gate.sh`, `context-mode-gate.sh`, `context-mode-read-deny.sh`, `leanctx-gate.sh`, `rtk-gate.sh`, `token-compression-tools-gate.sh`, `stack-compression-coordinator.sh`, `stack-optimizer.sh`, `graphify-am-global.sh`, `rtk-cm-global.sh`
- **Site sessions:** `site-session.sh`

`hooks/lib/completion-audit/` holds the modules `completion-audit.sh` sources (command classification, planning tier, deploy tier, change class, gate runners, state helpers). `hooks/lib/tool-input/` holds the Python helpers `tool-input.sh` calls to parse tool payloads (command strings, write targets, patch paths, RTK unwrapping).
